terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }

  # Состояние храним локально (terraform.tfstate, в .gitignore).
  # В команде его выносят в remote backend (S3/GitLab) с блокировкой.
  backend "local" {
    path = "terraform.tfstate"
  }
}
