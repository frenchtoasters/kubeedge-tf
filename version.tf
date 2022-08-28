terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "1.28.1"
    }
  }
}

provider "linode" {
}

