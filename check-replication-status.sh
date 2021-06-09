echo -e "\n\nHCV1 REPLICATION STATUS\n\n"
curl -k https://172.18.1.150:8200/v1/sys/replication/status|jq
echo -e "\n\nHCV2 REPLICATION STATUS\n\n"
curl -k https://172.18.2.150:8200/v1/sys/replication/status|jq