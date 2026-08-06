variable "image_type" {
  type = map
  default = {
    test = "t3.micro"
    prod = "t3.medium"
    dev = "t3.micro"
  }
}

variable "allow_ports" {
  type = map
  default = {
    test = ["80", "443"]
    prod = ["443"]
    dev = ["22", "80", "443"]
  }
}

variable "loadbalancing_port" {
  type = string
  default = "443"
}

variable "loadbalancing_app_port" {
  type = string
  default = "80"
}

variable "loadbalancing_proto" {
  type = string
  default = "HTTP"
}

variable "init_script" {
  type = string
  default = "setup.sh"
}