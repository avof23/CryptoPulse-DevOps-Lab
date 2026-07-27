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
    test = ["8000"]
    prod = ["8000"]
    dev = ["8000", "5000"]
  }
}

variable "loadbalancing_port" {
  type = string
  default = "80"
}

variable "loadbalancing_proto" {
  type = string
  default = "HTTP"
}

variable "endpoint_port" {
  type = string
  default = "8000"
}

variable "init_script" {
  type = string
  default = "setup.sh"
}