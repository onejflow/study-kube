#!/bin/bash

# Ubuntu 22.04/24.04 LTS (x86_64) 기준 Kubernetes 워커 노드 설치 스크립트 (worker2)
# - 컨테이너 런타임: containerd (Docker 공식 repo 사용)
# - Kubernetes: pkgs.k8s.io stable v1.30 (버전 고정 없음, v1.30 계열 최신 설치)
# - master 노드: 192.168.0.64 (k8s-master)
# - 이 스크립트는 "kubeadm join" 은 실행하지 않고, 환경만 맞춰 둡니다.

set -e

echo '======== [4] Ubuntu 기본 설정 (worker2) ========' 
echo '======== [4-2] 타임존 설정 ========' 
timedatectl set-timezone Asia/Seoul

echo '======== [4-3] [WARNING FileExisting-tc]: tc not found in system path 로그 관련 업데이트 ========' 
apt-get update
apt-get install -y iproute2

echo '======= [4-4] /etc/hosts 설정 ==========' 
cat << EOF >> /etc/hosts
192.168.0.64 k8s-master
192.168.0.65 k8s-worker1
192.168.0.66 k8s-worker2
EOF

echo '======== [5] kubeadm 설치 전 사전작업 ========' 
echo '======== [5] 방화벽 해제 ========' 
ufw disable 2>/dev/null || true

echo '======== [5] Swap 비활성화 ========' 
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo '======== [6] 컨테이너 런타임 설치 ========' 
echo '======== [6-1] 컨테이너 런타임 설치 전 사전작업 ========' 
echo '======== [6-1] iptable 세팅 ========' 

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

echo '======== [6-2] 컨테이너 런타임 (containerd 설치) ========' 
echo '======== [6-2-1] containerd 패키지 설치 (Docker repo) ========' 
echo '======== [6-2-1-1] Docker repo 설정 ========' 

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

echo '======== [6-2-1-1] containerd 설치 ========' 
apt-get install -y containerd.io
systemctl enable --now containerd

echo '======== [6-3] 컨테이너 런타임 : cri 활성화 ========' 
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

echo '======== [7] kubeadm/kubelet 설치 (v1.30 repo 사용) ========' 
echo '======== [7] 기존 kubernetes repo 정리 (있다면) ========' 
rm -f /etc/apt/sources.list.d/kubernetes.list || true
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg || true

echo '======== [7] Kubernetes repo 설정 (v1.30) ========' 
apt-get install -y apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat << EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

apt-get update
apt-get install -y kubelet kubeadm
apt-mark hold kubelet kubeadm
systemctl enable --now kubelet

echo '======== [8] 워커 노드 준비 완료 ========' 
echo '이제 마스터 노드에서 kubeadm token create --print-join-command 로 나온 명령을'
echo '이 워커 노드(worker2)에서 root 로 실행하면 클러스터에 조인됩니다.'

