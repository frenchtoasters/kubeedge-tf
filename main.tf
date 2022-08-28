variable "ssh_pub_key" {}
locals {
  kubeconfig = yamldecode(base64decode(linode_lke_cluster.cloudcore-master.kubeconfig))
  stackscript_data = templatefile("${path.module}/kubedge-stackscript.sh",
    {
      keadm_version = "v1.11.1",
    }
  )
  stackscript_data_node = templatefile("${path.module}/kubedge-node-stackscript.sh",
    {
      keadm_version = "v1.11.1",
    }
  )
  edgenode_count = 3
}

resource "linode_lke_cluster" "cloudcore-master" {
  label       = "cloudcore-master"
  k8s_version = "1.23"
  region      = "us-southeast"
  tags        = ["cloudcore", "kubeedge"]

  pool {
    type  = "g6-standard-2"
    count = 1
  }
}

provider "kubernetes" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
}

resource "random_password" "random_pass" {
  length  = 35
  special = true
  upper   = true
}

resource "linode_stackscript" "kubedge-bootstrap" {
  label       = "kubedge-bootstrap"
  description = "kubedge-bootstrap deployed via terraform"
  script      = local.stackscript_data
  images      = ["linode/ubuntu20.04", "linode/ubuntu21.10"]
  rev_note    = "initial terraform version"
}

resource "linode_instance" "kubedge-bootstrap" {
  label  = "kubedge-bootstrap"
  region = "us-southeast"
  type   = "g6-standard-4"

  disk {
    label           = "ubuntu21.10"
    size            = 30000
    filesystem      = "ext4"
    image           = "linode/ubuntu21.10"
    authorized_keys = [var.ssh_pub_key]
    root_pass       = random_password.random_pass.result
    stackscript_id  = linode_stackscript.kubedge-bootstrap.id
    stackscript_data = {
      kubeconfig_password = base64decode(linode_lke_cluster.cloudcore-master.kubeconfig)
    }
  }

  config {
    label  = "04config"
    kernel = "linode/latest-64bit"
    devices {
      sda {
        disk_label = "ubuntu21.10"
      }
    }
    root_device = "/dev/sda"
  }
  boot_config_label = "04config"

  private_ip = true
}

resource "linode_stackscript" "kubedge-node" {
  label       = "kubedge-node"
  description = "kubedge-node deployed via terraform"
  script      = local.stackscript_data_node
  images      = ["linode/ubuntu20.04", "linode/ubuntu21.10"]
  rev_note    = "initial terraform version"
}

resource "linode_instance" "kubedge-node" {
  count  = local.edgenode_count
  label  = "kubedge-node-${count.index}"
  region = "us-southeast"
  type   = "g6-standard-2"

  disk {
    label           = "ubuntu21.10"
    size            = 30000
    filesystem      = "ext4"
    image           = "linode/ubuntu21.10"
    authorized_keys = [var.ssh_pub_key]
    root_pass       = random_password.random_pass.result
    stackscript_id  = linode_stackscript.kubedge-node.id
    stackscript_data = {
      kubeconfig_password = base64decode(linode_lke_cluster.cloudcore-master.kubeconfig)
      hostname            = "kubedge-node-${count.index}"
    }
  }

  config {
    label  = "04config"
    kernel = "linode/latest-64bit"
    devices {
      sda {
        disk_label = "ubuntu21.10"
      }
    }
    root_device = "/dev/sda"
  }
  boot_config_label = "04config"

  private_ip = true

  depends_on = [
    linode_instance.kubedge-bootstrap
  ]
}

output "kubeedge-node-ip" {
  value = linode_instance.kubedge-node.*.ipv4
}

output "bootstrap-ip" {
  value = linode_instance.kubedge-bootstrap.ipv4
}

