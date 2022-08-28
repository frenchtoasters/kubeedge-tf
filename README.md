# Linode Kube-Edge

This repo holds the code need to deploy a kubernetes cluster, installing
kubeedge, and add edge nodes.

## Bugs

* Currently nodes dont always join the cluster so you might have to reboot nodes
afte they are deployed to get them to join the cluster.

## Variables

* `ssh_public_key` public key.
