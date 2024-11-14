# Laptop
scp c7-config.yaml krzys@c7m1.az1.t01.infra.guardanet.net:.
scp audit.yaml  krzys@c7m1.az1.t01.infra.guardanet.net:.

# 1st master
mkdir -p /var/lib/rancher/k3s/server/
cp audit.yaml /var/lib/rancher/k3s/server/
curl -sfL https://get.k3s.io | K3S_CONFIG_FILE=c7-config.yaml INSTALL_K3S_VERSION=v1.30.6+k3s1 \
INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy --disable=servicelb --disable traefik server \
--cluster-init --tls-san 192.168.32.196 --tls-san c7.guardanet.net --tls-san c7m1.az1.t01.infra.guardanet.net \
--user krzys --write-kubeconfig-mode 644 --write-kubeconfig-group 1000 --token 0ferCPpG/YjR6NxN --cluster-domain c7.local \
--kube-apiserver-arg=service-account-issuer=https://c7.guardanet.net:6443 \
--kube-apiserver-arg=audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log \
--kube-apiserver-arg=audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml" sh -

# Laptop
scp krzys@c7m1.az1.t01.infra.guardanet.net:/etc/rancher/k3s/k3s.yaml /home/kwaberski/.kube/config.c7
# edit config.c7 
# use c7m1.az1.t01.infra.guardanet.net as API as at this point we dont have kube vip yet
KUBECONFIG=~/.kube/config.c0:~/.kube/config.c1:~/.kube/config.c7 kubectl config view --flatten > ~/.kube/config.c0c1c7
# test
k --kubeconfig ~/.kube/config.c0c1c7 --context c7-admin@c7 get po -A
# 
cp ~/.kube/config.c0c1c7 ~/.kube/config.new
k config use-context c7-admin@c7 

k -n kube-system get cm coredns -o yaml

cilium install \
--version 1.16.3 \
--set hubble.peerService.clusterDomain=c7.local \
--set cluster.id=0 --set cluster.name=c7

kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
sudo su

export VIP=192.168.32.192
export INTERFACE=eth0
export KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
export ROUTER_ID=$(host c7m1.az1.t01.infra.guardanet.net | awk '{print $NF}')
export BGP_PEER=$(echo "$ROUTER_ID" | awk -F. '{printf "%d.%d.%d.%d\n", $1, $2, $3, 1}')
alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"

kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --services \
    --bgp \
    --localAS 65001 \
    --bgpRouterID $ROUTER_ID \
    --bgppeers "192.168.32.1:65001::false,192.168.32.65:65001::false,192.168.32.129:65001::false" | sudo -u kwaberski tee -a c7-kubevip-ds.yaml

exit 

# correct the produced c7-kubevip-ds.yaml to show 65001 and not 65000 (not sure why it does that)
        - name: bgp_peeras
          value: "65001"

# RAZ1
# add a k8s cluster master as a neighbor in T01 CRF on each of the AZ routers
krzys@RAZ1:~$ host c7m1.az1.t01.infra.guardanet.net
c7m1.az1.t01.infra.guardanet.net has address 192.168.32.21

RAZ1(config)# router bgp 65001 vrf T01
RAZ1(config-router)# neighbor 192.168.32.21 remote-as 65001
RAZ1(config-router)# q

krzys@RAZ2:~$ host c7m2.az2.t01.infra.guardanet.net
c7m2.az2.t01.infra.guardanet.net has address 192.168.32.82

RAZ2# conf t
RAZ2(config)# router bgp 65001 vrf T01
RAZ2(config-router)# neighbor 192.168.32.82 remote-as 65001
RAZ2(config-router)# q
RAZ2(config)# q
RAZ2# copy running-config startup-config 
Note: this version of vtysh never writes vtysh.conf
Building Configuration...
Integrated configuration saved to /etc/frr/frr.conf
[OK]

krzys@RAZ3:~$ host c7m3.az3.t01.infra.guardanet.net
c7m3.az3.t01.infra.guardanet.net has address 192.168.32.146
krzys@RAZ3:~$ sudo vtysh
[sudo] password for krzys: 

Hello, this is FRRouting (version 10.2-dev-MyOwnFRRVersion-gf610ca5bc).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

This is a git build of frr-10.2-dev-318-gf610ca5bc
Associated branch(es):
        local:master
        github/frrouting/frr.git/master

RAZ3# conf t
RAZ3(config)# router bgp 65001 vrf T01
RAZ3(config-router)# neighbor 192.168.32.146 remote-as 65001
RAZ3(config-router)# q
RAZ3(config)# q
RAZ3# copy running-config startup-config 
Note: this version of vtysh never writes vtysh.conf
Building Configuration...
Integrated configuration saved to /etc/frr/frr.conf
[OK]
RAZ3#

# Laptop
# install kubevip cloud provider
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
kubectl create configmap -n kube-system kubevip --from-literal range-global=192.168.32.193-192.168.32.254

# nor replace the cluster URL in kubeconfig
sed -i 's/c7m1.az1.t01.infra.guardanet.net/c7.guardanet.net/g' ~/.kube/config.new

# setup k8s authN mlount point for c7

#kwaberski@kwx1:~/Github/proxmox/k8s-clusters/c7$ ./vault-k8s-authN-setup.sh 
#What is your cluster's API endpoint?: https://c7.guardanet.net:6443
#What is the name of the SA on behalf of which cert manager will create tokens: issuer
#What namespace does the SA reside in?: vault

# install cert manager
cd /home/kwaberski/Github/k8s-pl-cert-manager/helm
helm repo update
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace pl-cert-manager \
  --create-namespace \
  --version v1.16.1 \
  --values values.yaml

# Install cert-manager csi-driver
helm upgrade cert-manager-csi-driver jetstack/cert-manager-csi-driver \
  --install \
  --namespace pl-cert-manager \
  --wait


# install issuer roles etc
cd /home/kwaberski/Github/rancher
NAMESPACE=cattle-system CM_NAMESPACE=pl-cert-manager envsubst < ns-certmgrresources.yaml | k apply -f -

!!! IMPORTANT
# make sure the audience you put in the issuer yaml spec has your clusters domain name, ex. 
# "https://kubernetes.default.svc.c7.local"

# install Ingress
$ cd ~/Github/k8s-pl-ingress-nginx
$ helm upgrade --install ingress-nginx ingress-nginx \
--repo https://kubernetes.github.io/ingress-nginx \
--values values.yaml \
--namespace=pl-ingress-nginx --create-namespace

# Install NFS provisionner and StorageClass
cd /home/kwaberski/Github/k8s-pl-storage
NAMESPACE=pl-nfs-storage NFS_SERVER_IP=192.168.2.9 envsubst < pl-storage.yaml | k apply -f -

# Install remaining masters
# on every master
for m in c7m2.az2.t01 c7m3.az3.t01; do 
  scp c7-config.yaml krzys@${m}:.
  scp audit.yaml  krzys@${m}:.
  ssh krzys@${m} bash -c "mkdir -p /var/lib/rancher/k3s/server/ && cp audit.yaml /var/lib/rancher/k3s/server/"
done

# You need to get the full token from the 1st master
# sudo cat /var/lib/rancher/k3s/server/token

curl -sfL https://get.k3s.io | K3S_TOKEN=$TOKEN \
K3S_CONFIG_FILE=c7-config.yaml INSTALL_K3S_VERSION=v1.30.6+k3s1 \
INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy --disable=servicelb --disable traefik \
server --server https://c7.guardanet.net:6443 --tls-san 192.168.32.196 --tls-san c7.guardanet.net --tls-san c7m2.az2.t01.infra.guardanet.net \
--user krzys --write-kubeconfig-mode 644 --write-kubeconfig-group 1000 --cluster-domain c7.local \
--kube-apiserver-arg=service-account-issuer=https://c7.guardanet.net:6443 \
--kube-apiserver-arg=audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log \
--kube-apiserver-arg=audit-policy-file=/var/lib/rancher/k3s/server/audit.yaml" sh -
