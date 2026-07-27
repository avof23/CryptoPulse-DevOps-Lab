variable "image_type" {
  type = string
  default = "t3.micro"
}

variable "ssh_key_name" {
  type = string
  default = "mykey"
}

variable "allow_ports" {
  type = list
  default = ["22"]
}

variable "init_script" {
  type = string
  default = "setup.sh"
}