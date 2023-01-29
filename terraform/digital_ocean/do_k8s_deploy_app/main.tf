terraform {

  required_version = ">= 1.2.0"

  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.17.0"
    }    
    local = {
      source = "hashicorp/local"
    }
  }

  backend "remote" {
    organization = "circleci-demo"
    workspaces {
      name = "circleci-workshop-deployment"
    }
  }
}

provider "kubernetes" {
 config_path = "~/.kube/config"
}