# study-kube

## install

on master/worker vm 

sudo -i   
git clone 
cd study-kube 
chmod +x install_k8s_master.sh  
./install_k8s_master.sh  

## after install 

- Check master token 

cat ~/join.sh 

if you can't find `kubeadm token create --print-join-command`

- join node example

`kubeadm join 192.168.56.30:6443 --token bver73.wda72kx4afiuhspo --discovery-token-ca-cert-hash sha256:7205b3fd6030e47b74aa11451221ff3c77daa0305aad0bc4a2d3196e69eb42b7`


- Check nodes
  - `kubectl get nodes`


```bash
# 노드 및 역할 확인
kubectl get nodes -o wide

# 시스템/네트워크/애드온 상태
kubectl get pods -A

# dashboard가 어느 노드에 떠 있는지
kubectl -n kubernetes-dashboard get pods -o wide

# metrics-server 동작 여부
kubectl top nodes   # 에러 없이 나오면 metrics-server OK
```
