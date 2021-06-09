kubectl config use-context kind-hcv1
helm uninstall hcv1
sleep 30
kubectl get pods -o wide
kubectl delete secret tls-secret
kubectl delete service hcvault-cluster-lb
sleep 15
kubectl delete pvc --all --force
sleep 5
kubectl get pods -o wide


kubectl config use-context kind-hcv2
helm uninstall hcv2
sleep 30
kubectl get pods -o wide
kubectl delete secret tls-secret
kubectl delete service hcvault-cluster-lb
sleep 15
kubectl delete pvc --all --force
sleep 5
kubectl get pods -o wide