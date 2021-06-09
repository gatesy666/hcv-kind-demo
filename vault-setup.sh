#!/bin/bash
set -x

# Set VAULT ENV VARS
export VAULT_TOKEN=$(cat ${INSTANCE}-cluster-keys.json | jq -r ".root_token")
export VAULT_ADDR=https://172.18.1.150:8200
export VAULT_CACERT=./tf-tls/vault_ca_cert.pem


vault secrets enable -path=kv2 kv-v2

vault kv put kv2/myapp/config username='foo' password='bar'


vault secrets enable pki

vault secrets tune -max-lease-ttl=87600h pki

vault write -field=certificate pki/root/generate/internal common_name="example.com" ttl=87600h

vault write pki/roles/server allow_any_name="true"  max_ttl="720h"




