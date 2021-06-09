kind-hcvault2
# kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > hcv2-cluster-keys.json
VAULT_UNSEAL_KEY_hcv2=$(cat hcv2-cluster-keys.json | jq -r ".unseal_keys_b64[]")
CLUSTER_ROOT_TOKEN_hcv2=$(cat hcv2-cluster-keys.json | jq -r ".root_token")
VAULT_ADDR=https://$(kubectl get service vault-ui -o json|jq -r ".status.loadBalancer.ingress[0].ip"):8200
VAULT_CACERT=./tf-tls/vault_ca_cert.pem
# kubectl exec --stdin=true --tty=true vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY_hcv2

sleep 5


# kubectl exec vault-1 --  /bin/sh -c 'vault operator raft join -leader-ca-cert="$(cat /vault/userconfig/tls-secret/ca.crt)" --address "https://vault-1.vault-internal:8200" "https://vault-0.vault-internal:8200"'
# kubectl exec vault-2 --  /bin/sh -c 'vault operator raft join -leader-ca-cert="$(cat /vault/userconfig/tls-secret/ca.crt)" --address "https://vault-2.vault-internal:8200" "https://vault-0.vault-internal:8200"'

# kubectl exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY_hcv2
# kubectl exec vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY_hcv2

# kubectl exec --stdin=true --tty=true vault-0 -- vault login $CLUSTER_ROOT_TOKEN_hcv2
# kubectl exec --stdin=true --tty=true vault-0 -- vault operator raft list-peers
# kubectl exec --stdin=true --tty=true vault-0 -- vault auth enable userpass
# kubectl exec --stdin=true --tty=true vault-0 -- vault write auth/userpass/users/gatesy password=gatesy policies=admin
# kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh -c '(cat ./cluster-config/acl-admin.hcl | vault policy write admin -)'

vault login $CLUSTER_ROOT_TOKEN_hcv2
vault operator raft list-peers
vault auth enable userpass
vault write auth/userpass/users/gatesy password=gatesy policies=admin
cat ./cluster-config/acl-admin.hcl | vault policy write admin -


echo '\n\nSet the following env vars:\n\n'
set|grep hcv2|grep -v BASH_SOURCE
set|grep VAULT_ADDR
