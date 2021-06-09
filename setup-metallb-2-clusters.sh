#!/bin/bash

set -euo pipefail

set -x

if [ $# = 0 ]; then
    echo "Multi HCVault Demo"
    echo
    echo "Usage:"
    echo "  $0 [command]"
    echo
    echo "Available Commands:"
    echo "  install    Installs a Vault cluster to one or more Kubernetes clusters"
    echo "  uninstall  Uninstalls a Vault cluster from one or more Kubernetes clusters"
    exit 0
fi

function waitfor {
    WAIT_MAX=0
    until $@ &> /dev/null || [ $WAIT_MAX -eq 45 ]; do
        sleep 1
        (( WAIT_MAX = WAIT_MAX + 1 ))
    done
}

function metallb_setup {
    export METALLB_ADDRESS_RANGE=$1

    kubectl apply -f ./cluster-config/metallb-namespace.yaml
    kubectl apply -f ./cluster-config/metallb.yaml
    kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
    cat ./cluster-config/metallb-config.yaml | envtpl | kubectl apply -f -
}

function cidr_range {
    local cidr=$1
    cidr ${cidr} | tr -d ' '
}

function node_setup_small {
    local instance=$1
    local lb_subnet=$2

    kind create cluster --name ${instance} --config ./cluster-config/hcv-cluster-small.yaml --retain -v 1
    metallb_setup $(cidr_range ${lb_subnet})   
}

function node_setup {
    local instance=$1
    local lb_subnet=$2

    kind create cluster --name ${instance} --config ./cluster-config/hcv-cluster.yaml --retain -v 1
    metallb_setup $(cidr_range ${lb_subnet})
}

function infra_setup {

    node_setup_small hcv1 172.18.1.255/25
    node_setup_small hcv2 172.18.2.255/25

}

function install_instance {
    local INSTANCE=$1
    local HCV_CLUSTERIP=$2

    echo -e "\n${INSTANCE} install\n"
    
    kubectl create secret generic tls-secret --from-file=tls.crt=./tf-tls/vault_cert.pem --from-file=tls.key=./tf-tls/vault_private_key.pem --from-file=ca.crt=./tf-tls/vault_ca_cert.pem
    
    helm upgrade --install ${INSTANCE} ./vault -f ${INSTANCE}-helm-vault-overrides.yaml

    sleep 60
}

function init_instance {
    local INSTANCE=$1
    set +e
    echo -e "\n${INSTANCE} running init\n"
    echo -e "\n${INSTANCE} running vault status\n"
    kubectl exec ${INSTANCE}-vault-0 -- vault status

    sleep 2
    echo -e "\n${INSTANCE} running vault operator init -key-shares=1 -key-threshold=1 -format=json > ${INSTANCE}-cluster-keys.json\n"
    kubectl exec ${INSTANCE}-vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > ${INSTANCE}-cluster-keys.json
    sleep 2
    echo -e "\n${INSTANCE} running vault status\n"
    kubectl exec ${INSTANCE}-vault-0 -- vault status
    echo -e "\n${INSTANCE} init complete\n"
    set -e
}

function unseal_instance {
    local INSTANCE=$1

    echo -e "\n${INSTANCE} unseal\n"
    
    local VAULT_UNSEAL_KEY=$(cat ${INSTANCE}-cluster-keys.json | jq -r '.unseal_keys_b64[]')
    local CLUSTER_ROOT_TOKEN=$(cat ${INSTANCE}-cluster-keys.json | jq -r ".root_token")

    kubectl exec --stdin=true --tty=true ${INSTANCE}-vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

    sleep 10

    kubectl exec ${INSTANCE}-vault-1 --  /bin/sh -c "vault operator raft join -leader-ca-cert=\"\$(cat /vault/userconfig/tls-secret/ca.crt)\" --address \"https://${INSTANCE}-vault-1.${INSTANCE}-vault-internal:8200\" \"https://${INSTANCE}-vault-0.${INSTANCE}-vault-internal:8200\""
    kubectl exec ${INSTANCE}-vault-2 --  /bin/sh -c "vault operator raft join -leader-ca-cert=\"\$(cat /vault/userconfig/tls-secret/ca.crt)\" --address \"https://${INSTANCE}-vault-2.${INSTANCE}-vault-internal:8200\" \"https://${INSTANCE}-vault-0.${INSTANCE}-vault-internal:8200\""

    sleep 10

    kubectl exec ${INSTANCE}-vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
    kubectl exec ${INSTANCE}-vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY

    sleep 10

    kubectl exec --stdin=true --tty=true ${INSTANCE}-vault-0 -- vault login $CLUSTER_ROOT_TOKEN
    kubectl exec --stdin=true --tty=true ${INSTANCE}-vault-0 -- vault operator raft list-peers
}

function bootstrap_access {
    local INSTANCE=$1
    local HCV_CLUSTERIP=$2
    echo -e "\n${INSTANCE} access bootstrap with lb address: ${HCV_CLUSTERIP}\n"

    export VAULT_TOKEN=$(cat ${INSTANCE}-cluster-keys.json | jq -r ".root_token")
    export VAULT_ADDR=https://${HCV_CLUSTERIP}:8200
    export VAULT_CACERT=./tf-tls/vault_ca_cert.pem

    vault auth enable userpass
    vault write auth/userpass/users/foo password=bar policies=admin
    cat ./cluster-config/acl-admin.hcl | vault policy write admin -
}

COMMAND=$1

if [ $COMMAND = "install" ]; then

    infra_setup

    kubectl config use-context kind-hcv1
    install_instance hcv1 172.18.1.150
    init_instance hcv1
    unseal_instance hcv1
    bootstrap_access hcv1 172.18.1.150

    kubectl config use-context kind-hcv2
    install_instance hcv2 172.18.2.150
    init_instance hcv2
    unseal_instance hcv2
    bootstrap_access hcv2 172.18.2.150

    echo -e "\nVault cluster setup completed."

elif [ $COMMAND = "status" ]; then

    echo "status..."

elif [ $COMMAND = "uninstall" ]; then

    kind delete cluster --name hcv1
    kind delete cluster --name hcv2
    kind delete cluster --name hcv3
    kind delete cluster --name hcv4
    kind get clusters
else

    echo "unknown command: $COMMAND"

fi