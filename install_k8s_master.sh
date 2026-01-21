#!/bin/bash

# Ubuntu 22.04/24.04 LTS (x86_64) 기준 Kubernetes 마스터 노드 설치 스크립트
# - 컨테이너 런타임: containerd (Docker 공식 repo 사용)
# - Kubernetes: pkgs.k8s.io stable v1.30 (버전 고정 없음, v1.30 계열 최신 설치)
# - root 권한으로 실행 (sudo -i 후 사용 권장)

set -e  # 어떤 명령이든 실패하면 스크립트 전체를 종료

echo "======== [4] Ubuntu 기본 설정 ========"
echo "======== [4-2] 타임존 설정 ========"
timedatectl set-timezone Asia/Seoul

echo "======== [4-3] [WARNING FileExisting-tc]: tc not found in system path 로그 관련 업데이트 ========"
# Ubuntu에서는 yum-utils 대신 기본적인 유틸리티와 iproute2 설치
apt-get update
apt-get install -y iproute2

echo "======= [4-4] /etc/hosts 설정 =========="
# 개인 네트워크 IP 대역 (필요 시 IP 수정)
cat << EOF >> /etc/hosts
192.168.0.64 k8s-master
192.168.0.65 k8s-worker1
192.168.0.66 k8s-worker2
EOF

echo "======== [5] kubeadm 설치 전 사전작업 ========"
echo "======== [5] 방화벽 해제 ========"
# Ubuntu는 firewalld 대신 ufw 사용, 없을 수도 있으므로 에러 무시
ufw disable 2>/dev/null || true

echo "======== [5] Swap 비활성화 ========"
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo "======== [6] 컨테이너 런타임 설치 ========"
echo "======== [6-1] 컨테이너 런타임 설치 전 사전작업 ========"
echo "======== [6-1] iptable 세팅 ========"

cat << EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat << EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "======== [6-2] 컨테이너 런타임 (containerd 설치) ========"
echo "======== [6-2-1] containerd 패키지 설치 (Docker repo) ========"
echo "======== [6-2-1-1] Docker repo 설정 ========"

apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

cat << EOF >/etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF

apt-get update

echo "======== [6-2-1-1] containerd 설치 ========"
apt-get install -y containerd.io
systemctl enable --now containerd

echo "======== [6-3] 컨테이너 런타임 : cri 활성화 ========"
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

echo "======== [7] kubeadm 설치 ========"
echo "======== [7] (기존 v1.27 kubernetes repo 정리 - 있으면 삭제) ========"
rm -f /etc/apt/sources.list.d/kubernetes.list || true
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg || true

echo "======== [7] Kubernetes repo 설정 (v1.30) ========"

apt-get install -y apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat << EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

echo "======== [7] SELinux 설정 (Ubuntu는 AppArmor 사용이므로 실질 작업 없음) ========"
# Ubuntu는 기본적으로 SELinux 대신 AppArmor 사용
# setenforce 0 2>/dev/null || true

echo "======== [7] kubelet, kubeadm, kubectl 패키지 설치 ========"
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

echo "======== [8] kubeadm으로 클러스터 생성 ========"
echo "======== [8-1] 클러스터 초기화 (Pod Network 세팅) ========"

# apiserver-advertise-address 는 실제 마스터 노드의 IP 로 맞춰야 함
kubeadm init \
  --pod-network-cidr=20.96.0.0/12 \
  --apiserver-advertise-address=192.168.0.64

# 워커 노드 조인을 위한 토큰/명령 저장
kubeadm token create --print-join-command > ~/join.sh

echo "======== [8-2] kubectl 사용 설정 ========"
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

echo "======== [8-3] Pod Network 설치 (Calico 공식 매니페스트) ========"
# Calico v3.26.4 공식 매니페스트 (Kubernetes 1.26~1.30 지원)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/calico.yaml

echo "======== [9] 쿠버네티스 편의기능 설치 ========"
echo "======== [9-1] kubectl 자동완성 기능 ========"

apt-get install -y bash-completion
cat << 'EOF' >> ~/.bashrc
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
EOF

echo "======== [9-2] Dashboard 설치 ========"
kubectl apply -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/dashboard-2.7.0/dashboard.yaml

echo "======== [9-3] Metrics Server 설치 ========"
kubectl apply -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/metrics-server-0.6.3/metrics-server.yaml

echo "======== [10-1] Pod 상태 확인 ========"
kubectl get pod -A
