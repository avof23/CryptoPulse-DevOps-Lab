variable "env" {
  type = string
  default = "test"
}

variable "vpc_sg_id" {
  type = string
  default = ""
}

variable "resource_name" {
  type = string
  default = ""
}

variable "inbond_rule" {
  type = object({
    port       = list(string)
    protocol   = string
    cidr_block = string
    source_sg = string
  })
  default = {
    port       = ["22"]
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    source_sg = null
  }
}

variable "outbond_rule" {
  type = object({
    port       = list(string)
    protocol   = string
    cidr_block = string
  })
  default = {
    port       = ["0"]
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }
}
