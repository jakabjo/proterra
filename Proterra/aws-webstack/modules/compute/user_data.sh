#!/bin/bash
set -xe
yum update -y
yum install -y nginx
cat >/usr/share/nginx/html/index.html <<'HTML'
<!doctype html><html><head><title>OK</title></head>
<body style="font-family: sans-serif">
<h1>It works 🎉</h1>
<p>Host: $(hostname)</p>
</body></html>
HTML
systemctl enable nginx
systemctl start nginx
