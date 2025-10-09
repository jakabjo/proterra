data "aws_ami" "win2022" {
  most_recent = true
  owners      = ["801119661308"] # Amazon

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "platform_details"
    values = ["Windows"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect="Allow", Action="sts:AssumeRole", Principal={ Service="ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "sql_sg" {
  name        = "${var.project}-sql-sg"
  description = "Allow WSFC/SQL and health"
  vpc_id      = var.vpc_id

  # SQL Server
  ingress {
    description = "SQL Server traffic (TCP 1433)"
    from_port   = var.sql_port
    to_port     = var.sql_port
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }

  # WSFC and AD services (TCP)
  ingress {
    description = "Windows Failover Clustering communication"
    from_port   = 3343
    to_port     = 3343
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "RPC endpoint mapper"
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "SMB for AD and cluster communication"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "DNS (TCP)"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "Kerberos authentication (TCP)"
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "LDAP (TCP)"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "Dynamic RPC ports for WSFC and AD"
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }

  # AD/DNS (UDP)
  ingress {
    description = "DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "Kerberos (UDP)"
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }
  ingress {
    description = "LDAP (UDP)"
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = [var.onprem_cidr, var.vpc_cidr]
  }

  # Health probe from NLB
  ingress {
    description = "Health probe from NLB"
    from_port   = var.health_port
    to_port     = var.health_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Intra-VPC communication (cluster heartbeat, etc.)
  ingress {
    description = "Intra-VPC all traffic for cluster nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sql-sg"
  }
}


resource "aws_instance" "sql_nodes" {
  count                       = 2
  ami                         = data.aws_ami.win2022.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sql_sg.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  user_data = <<-EOF
    <powershell>
      Install-WindowsFeature Failover-Clustering -IncludeManagementTools
      Install-WindowsFeature RSAT-ADDS, Net-Framework-Features
      # Install-Module -Name SqlServer -Force

      $paramName = "${var.ad_join_password_ssm_param}"
      $pwd = (Get-SSMParameterValue -Name $paramName -WithDecryption $true).Parameters[0].Value | ConvertTo-SecureString -AsPlainText -Force
      $cred = New-Object System.Management.Automation.PSCredential("${var.ad_join_user}", $pwd)
      $ou = "${var.ad_target_ou}"
      if ([string]::IsNullOrWhiteSpace($ou)) {
        Add-Computer -DomainName "${var.ad_domain_name}" -Credential $cred -Force -Restart
      } else {
        Add-Computer -DomainName "${var.ad_domain_name}" -Credential $cred -OUPath $ou -Force -Restart
      }
    </powershell>
  EOF

  tags = { Name = "${var.project}-sql-${count.index + 1}" }
}

resource "aws_ssm_document" "ag_primary_health_doc" {
  name          = "${var.project}-ag-primary-health"
  document_type = "Command"
  content = <<-JSON
  {
    "schemaVersion": "2.2",
    "description": "AG primary health probe setup",
    "parameters": {
      "HealthPort": { "type": "String" },
      "VpcCidr":    { "type": "String" }
    },
    "mainSteps": [{
      "action": "aws:runPowerShellScript",
      "name": "SetupProbe",
      "inputs": {
        "runCommand": [
          "$port = {{ HealthPort }}",
          "$root = 'C:\\\\AGHealth'",
          "New-Item -ItemType Directory -Path $root -Force | Out-Null",
          "@'",
          "using System;",
          "using System.Net;",
          "using System.Net.Sockets;",
          "class P {",
          "  static void Main(string[] a){",
          "    int port = int.Parse(a[0]);",
          "    var l = new TcpListener(IPAddress.Any, port);",
          "    l.Start();",
          "    while (true) { var c = l.AcceptTcpClient(); c.Close(); }",
          "  }",
          "}",
          "'@ | Out-File \"$root\\\\Probe.cs\" -Encoding ASCII",
          "& \"$env:WINDIR\\\\Microsoft.NET\\\\Framework64\\\\v4.0.30319\\\\csc.exe\" /t:exe /out:$root\\\\Probe.exe $root\\\\Probe.cs",
          "@'",
          "param([int]$Port)",
          "function Is-Primary {",
          "  try {",
          "    $qry = \"SELECT CASE WHEN sys.fn_hadr_is_primary_replica(DB_NAME()) = 1 THEN 1 ELSE 0 END as is_primary\"",
          "    $res = Invoke-Sqlcmd -Query $qry -ConnectionTimeout 5 -QueryTimeout 5 2>$null",
          "    return ($res.is_primary -contains 1)",
          "  } catch { return $false }",
          "}",
          "$exe = 'C:\\\\AGHealth\\\\Probe.exe'",
          "$proc = Get-Process -Name 'Probe' -ErrorAction SilentlyContinue",
          "$primary = Is-Primary",
          "if ($primary -and -not $proc) { Start-Process -FilePath $exe -ArgumentList $Port }",
          "if (-not $primary -and $proc) { $proc | Stop-Process -Force }",
          "'@ | Out-File \"$root\\\\Controller.ps1\" -Encoding ASCII",
          "$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\\\\AGHealth\\\\Controller.ps1 -Port ' + $port",
          "$trigger1 = New-ScheduledTaskTrigger -AtStartup",
          "$trigger2 = New-ScheduledTaskTrigger -Once (Get-Date).AddMinutes(1)",
          "$trigger2.Repetition.Interval = (New-TimeSpan -Seconds 15)",
          "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest",
          "Register-ScheduledTask -TaskName 'AGPrimaryHealth' -Action $action -Trigger $trigger1,$trigger2 -Principal $principal -Force",
          "New-NetFirewallRule -DisplayName 'AG Health Probe' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -RemoteAddress {{ VpcCidr }} -Profile Any -ErrorAction SilentlyContinue"
        ]
      }
    }]
  }
  JSON
}

resource "aws_ssm_association" "ag_primary_health_probe" {
  name = aws_ssm_document.ag_primary_health_doc.name

  targets {
    key    = "InstanceIds"
    values = [for i in aws_instance.sql_nodes : i.id]
  }

  parameters = {
    HealthPort = ["${var.health_port}"]
    VpcCidr    = ["${var.vpc_cidr}"]
  }

  depends_on = [aws_instance.sql_nodes]
}
