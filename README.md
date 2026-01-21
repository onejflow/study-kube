# study-kube

Ubuntu 24.04 환경에서 **Kubernetes v1.30 + containerd + Calico** 클러스터 구축하기 위한 실습용 저장소

- Proxmox 등 가상화 환경 위에 Ubuntu 24.04 VM 3대를 올려서, 1 master + 2 worker 구성으로 공부 시작

## 1. Proxmox VM 구성 예시

| 역할        | 호스트명       | IP 주소 예시       |
|-------------|----------------|----------------|
| Master      | `k8s-master`   | `192.168.0.90` |
| Worker 1    | `k8s-worker1`  | `192.168.0.91` |
| Worker 2    | `k8s-worker2`  | `192.168.0.92` |


## 2. 설치 (`k8s-master`)

### 2-1. 저장소 클론

```bash
sudo -i
git clone <이 저장소 URL>
cd study-kube
```

### 2-2.  설치 스크립트 실행

```bash
chmod +x install_k8s_master_modified.sh
./install_k8s_master_modified.sh
```