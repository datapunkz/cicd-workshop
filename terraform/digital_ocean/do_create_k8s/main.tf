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
      name = "circleci-workshop"
    }
  }
}

# Set up the DO K8s cluster
provider "digitalocean" {
  token = var.do_token
}

# We like to live in the edge.
data "digitalocean_kubernetes_versions" "latest" {}

resource "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name   = var.cluster_name
  region = var.do_data_center
  # HINT: If this breaks, you can use `var.do_k8s_slug_ver`, but uncomment it
  #       on `variables.tf` file in this directory.
  version = data.digitalocean_kubernetes_versions.latest.latest_version

  node_pool {
    name       = var.cluster_name
    size       = "s-1vcpu-2gb"
    node_count = 2
    auto_scale = true
    min_nodes  = 2
    max_nodes  = 3
    tags       = [var.cluster_name]
  }
}

# resource "local_file" "k8s_config" {
#   content  = digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].raw_config
#   filename = pathexpand("~/.kube/${var.cluster_name}-config.yaml")
# }
