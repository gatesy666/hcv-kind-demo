# HCVault K8s Demo on Kind

This repository contains a set of config and scripts to spin up multiple Hashicorp Vault clusters on Kind.
Once provisioned the instances can be used to demo Performance and DR replication as well as upgrade workflows.
Still very much a work in progress.

Inspired by:
https://banzaicloud.com/blog/multi-cluster-testing/  
https://www.thehumblelab.com/kind-and-metallb-on-mac/  
https://github.com/AlmirKadric-Published/docker-tuntap-osx  



## Prerequisites

  * **helm** - brew install helm
  * **Kind** - https://kind.sigs.k8s.io/docs/user/quick-start/
  * **docker-tuntap-osx** - https://github.com/AlmirKadric-Published/docker-tuntap-osx
  * https://github.com/subfuzion/envtpl
  * https://github.com/hankjacobs/cidr
  * **jq** - brew install jq

## Usage

The official [Hashicorp helm chart](https://github.com/hashicorp/vault-helm) chart has been customised for this project and was derived from v0.12.0 making use of [pull 433](https://github.com/hashicorp/vault-helm/pull/433) 


To install 2 kind clusters and install a 3 nodes HCVault cluster on each:

```console
$ ./setup-metallb-2-clusters.sh install
```