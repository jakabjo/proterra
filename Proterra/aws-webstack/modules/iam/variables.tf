variable "name"  { type = string }
variable "tags"  { type = map(string) }
variable "secret_arns"    { type = list(string) default = [] }
variable "parameter_arns" { type = list(string) default = [] }
variable "reuse_role_name"        { type = string default = "" }
variable "reuse_instance_profile" { type = string default = "" }
