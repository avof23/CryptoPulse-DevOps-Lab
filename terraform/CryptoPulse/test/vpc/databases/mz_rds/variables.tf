variable "image_type" {
  type = map
  default = {
    test = "db.t3.micro"
    prod = "db.t3.medium"
    dev = "db.t3.micro"
  }
}

variable "database_port" {
  type = string
  default = "5432"
}

variable "db_init_size" {
  type = number
  default = 20
}

variable "db_disk_type" {
  type = map
  default = {
    test = "gp3"
    prod = "gp3"
    dev = "gp2"
  }
}

variable "db_user" {
  type = string
}

variable "db_name" {
  type = string
}
