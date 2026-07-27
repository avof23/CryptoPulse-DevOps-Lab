
variable "env" {
  type = string
  default = "myenv"
}

variable "project_name" {
  type = string
  default = "My Project"
}

variable "common_tags" {
  type = map(string)
  default = {
    Owner = "AntonV"
    Managed_by = "DIT devops"
    Environment = "My environment"
  }
}