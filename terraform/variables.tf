variable "vm_host" {
  description = "Адрес VM: по нему Terraform ходит в Docker (SSH) и по нему проверяем nginx"
  type        = string
  default     = "192.168.139.194"
}

variable "ssh_private_key" {
  description = "Приватный ключ для SSH до VM"
  type        = string
  default     = "~/.ssh/devops_hw_ed25519"
}

variable "nginx_image" {
  description = "Образ nginx (версия зафиксирована ради воспроизводимости)"
  type        = string
  default     = "nginx:1.28-alpine"
}

variable "container_name" {
  description = "Имя контейнера nginx"
  type        = string
  default     = "tf-nginx"
}

variable "network_name" {
  description = "Имя новой docker-сети для nginx"
  type        = string
  default     = "tf_web_net"
}

variable "network_subnet" {
  description = "Подсеть сети (не пересекается с docker0 172.17/16 и сетями compose)"
  type        = string
  default     = "10.20.0.0/24"

  validation {
    condition     = can(cidrhost(var.network_subnet, 0))
    error_message = "network_subnet должен быть корректным CIDR, например 10.20.0.0/24."
  }
}

variable "volume_name" {
  description = "Имя docker-тома с контентом nginx"
  type        = string
  default     = "tf_nginx_html"
}

variable "external_port" {
  description = "Внешний порт на VM. По заданию — НЕ стандартный (не 80/443)."
  type        = number
  default     = 8080

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535
    error_message = "external_port должен быть нестандартным портом в диапазоне 1024-65535."
  }
}
