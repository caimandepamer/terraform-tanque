apt-get purge -y docker-ce-rootless-extras docker-scan-plugin
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -sudo add-apt-repository “deb [arch=amd64]
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable”

apt-get update
apt-get install -y docker-ce


# cat /etc/docker/daemon.json
{
 "exec-opts": ["native.cgroupdriver=systemd"],
 "log-driver": "json-file",
 "log-opts": {
 "max-size": "100m"
 },
 "storage-driver": "overlay2"
}

systemctl daemon reload

restart docker o reboot de la VM 

systemctl enable docker
systemctl start docker

# kubernetes:
 apt-get update && apt-get install -y apt-transport-httpscurl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main

apt-get update && apt-get install -y apt-transport-https


curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF


 apt-get update
apt-get install -y kubelet kubeadm kubectl

swapoff -a

kubeadm init

#test
kubectl get pods
kubectl get pods --all-namespaces

