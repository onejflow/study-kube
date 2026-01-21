# study-kube

## script explain - master node

. 기본 OS 설정
   - 타임존: `Asia/Seoul`
   - `/etc/hosts` 에 master/worker1/worker2 IP/호스트명 추가
   - `ufw disable` (있어도/없어도 에러 없이 처리)
   - `swapoff -a` + `/etc/fstab` 의 swap 항목 주석 처리

2. 커널 모듈 / sysctl 설정
   - `overlay`, `br_netfilter` 모듈 로드
   - `/etc/sysctl.d/k8s.conf` 에 bridge, ip_forward 값 설정 후 `sysctl --system` 적용

3. 컨테이너 런타임: containerd
   - Docker 공식 repo 추가 (`/etc/apt/sources.list.d/docker.list`)
   - `containerd.io` 설치
   - `/etc/containerd/config.toml` 생성 후 `SystemdCgroup = true` 로 수정

4. Kubernetes v1.30 설치
   - 이전 v1.27 용 `kubernetes.list` / 키링 파일 제거
   - pkgs.k8s.io `core:/stable:/v1.30/deb` repo 추가
   - `kubelet`, `kubeadm`, `kubectl` 설치 및 `apt-mark hold`

5. kubeadm 초기화 + Calico CNI
   - `kubeadm init --pod-network-cidr=20.96.0.0/12 --apiserver-advertise-address=192.168.0.64`
   - `/root/.kube/config` 설정
   - Calico 네트워크 플러그인 설치 (공식 manifest)
     ```bash
     kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico.yaml
     ```

6. 편의 기능 및 애드온
   - `bash-completion` 설치 + `kubectl` 자동완성, alias `k=kubectl` 설정
   - Kubernetes Dashboard 2.7.0 설치
   - Metrics Server 0.6.3 설치

## script explain - worker node

두 스크립트는 다음을 수행합니다.

1. 기본 설정
   - 타임존 `Asia/Seoul`
   - `/etc/hosts` 에 master/worker1/worker2 IP/호스트명 추가
   - `ufw disable`, `swapoff -a` + `/etc/fstab` swap 주석 처리

2. 네트워크/커널 설정
   - `overlay`, `br_netfilter` 모듈 로드
   - `/etc/sysctl.d/k8s.conf` 설정 후 `sysctl --system` 적용

3. 컨테이너 런타임: containerd
   - Docker repo 설정, `containerd.io` 설치
   - `/etc/containerd/config.toml` 에 `SystemdCgroup = true` 설정 후 재시작

4. Kubernetes v1.30 repo + kubelet/kubeadm 설치
   - 기존 Kubernetes repo/키링 제거
   - pkgs.k8s.io `core:/stable:/v1.30/deb` repo 추가
   - `kubelet`, `kubeadm` 설치 및 `apt-mark hold`

> 이 스크립트는 **`kubeadm join` 을 실행하지 않습니다.**
> 워커를 실제 클러스터에 붙이는 작업은 다음 단계에서 수동으로 수행합니다.

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
