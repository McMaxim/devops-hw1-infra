# nginx в отдельной (новой) docker-сети с подключённым томом,
# опубликован на нестандартном порту VM: curl -i http://<VM>:8080 -> 200 OK.

provider "docker" {
  # Docker на VM через SSH пользователем deployer (его создаёт Ansible), не root
  host = "ssh://deployer@${var.vm_host}:22"
  ssh_opts = [
    "-i", pathexpand(var.ssh_private_key),
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "BatchMode=yes",
  ]
}

resource "docker_network" "web" {
  name   = var.network_name
  driver = "bridge"

  ipam_config {
    subnet  = var.network_subnet
    gateway = cidrhost(var.network_subnet, 1)
  }
}

resource "docker_volume" "html" {
  name = var.volume_name
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "nginx" {
  name    = var.container_name
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  # Подключаем только к своей сети, без дефолтного bridge
  network_mode = docker_network.web.name

  ports {
    internal = 80
    external = var.external_port
  }

  volumes {
    volume_name    = docker_volume.html.name
    container_path = "/usr/share/nginx/html"
  }

  # Кладём страницу прямо в том (путь внутри смонтированного volume)
  upload {
    file = "/usr/share/nginx/html/index.html"
    content = templatefile("${path.module}/files/index.html.tftpl", {
      container_name = var.container_name
      network_name   = var.network_name
      volume_name    = var.volume_name
      external_port  = var.external_port
    })
  }

  healthcheck {
    test     = ["CMD", "wget", "-qO-", "http://127.0.0.1/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }
}
