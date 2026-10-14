output "nginx_url" {
  description = "Проверка: curl -i <url>"
  value       = "http://${var.vm_host}:${var.external_port}"
}

output "container_name" {
  value = docker_container.nginx.name
}

output "network_name" {
  value = docker_network.web.name
}

output "volume_name" {
  value = docker_volume.html.name
}
