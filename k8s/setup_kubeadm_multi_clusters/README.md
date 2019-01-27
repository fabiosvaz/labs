# Overview
This is a hands-on guide on how to set up a K8s cluster environment using kubeadm. For required k8s networking plugin, this guide you have steps to install Flannel or Calico.

The k8s cluster will be created with 3 VMs: manager1, worker1 and worker2. Those three VMs will be configured by Vagrant with Ubuntu 18, 1 CPU and 2048GB ram. 

If you want to modify the resources allocated to each VM, you can modify the Vagrantfile. The Vagrantfile in this hands-on is intended to be as simple as possible. So no provisioning is enabled by default, and all the steps required to setup the k8s cluster is expected.

# Requirements
- Vagrant (https://www.vagrantup.com/downloads.html)
- VirtualBox (https://www.virtualbox.org/wiki/Downloads)

For information on how to use Vagrant, check the [Vagrant](https://github.com/fabiosvaz/playground/tree/master/vagrant) playground section.

# Hands-on

## Creating VMs
Checkout the playground repo and navigate to k8s/setup_kubeadm_multi_clusters to create the VMs for this hands-on using Vagrant.

```
vagrant up
```

This will take some time, as 3 VMs will be created with Ubuntu 18 as distro. Once it is done, you can verify the status of the VMs.

```
vagrant status
```
```
Current machine states:

manager1                  running (virtualbox)
worker1                   running (virtualbox)
worker2                   running (virtualbox)
```

From now on, you can ssh to each VM and follow the next instructions. vagrant ssh [vm_name].

```
vagrant ssh manager1
```

## Configuring k8s Cluster Nodes
Use 'vagrant ssh [vm_name]' to access each VM. 

Add the Docker Repository on all three VMs.

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```

Add the Kubernetes repository on all three VMs.

```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
```

Install Docker, Kubeadm, Kubelet, and Kubectl on all three VMs. The versions installed should be exactly the ones provided in the cmd bellow.
The docker version needs to be compatible with the kubelet, kubeadm and kubectl versions. Also, it is highly recommended to use the same version for kubelet, kubeadm and kubeclt.

```
sudo apt-get update
sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu kubelet=1.12.2-00 kubeadm=1.12.2-00 kubectl=1.12.2-00
```

Add vagrant user to docker group to run docker commands with no sudo required.

```
sudo usermod -aG docker vagrant
```

Prevent updates for the installed packages above.

```
sudo apt-mark hold docker-ce kubelet kubeadm kubectl
```

Disable swap on all three servers. This is required by kubelet.

```
sudo swapoff -a
```

Permanently disable swap to keep it off after any vagrant halt/reboot. kubeadm pre-flight checks look for swap space disabled, since Kubernetes cannot use swap space due to memory limits. If swap is not disabled, this can affect the restart of the Kubernetes cluster on VM reboot.

```
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

## Configuring Kubelet settings
We need to proper configure kubelet settings on each VM to set the VM IP specified in the Vagrantfile. This is required as we are using Vagrant and creating a private network for this hands-on cluster.

Vagrant creates two network interfaces for each machine. eth0 is NAT network, eth1 is a private network. By default, Kubernetes (Kubelet) will use the IP from the interface eth0 when we initialize the cluster and join any worker. We need to add the IP address from the eth1 interface on the VMs, enabling the manager’s API server to properly access the worker’s kubelet after the cluster initialization.

To proper configure it, we need to edit the kubelet settings for all nodes <b>/etc/default/kubelet</b> and add a --node-ip flag.

```
sudo vi /etc/default/kubelet
```

```
KUBELET_EXTRA_ARGS=--node-ip=VM_IP_ADDR
```

ssh to each node (This change also includes manager1), and add the configuration in <b>/etc/default/kubelet</b>

```
Manager1 will be: KUBELET_EXTRA_ARGS=--node-ip=172.17.4.100
Worker1 will be:  KUBELET_EXTRA_ARGS=--node-ip=172.17.4.101
Worker2 will be:  KUBELET_EXTRA_ARGS=--node-ip=172.17.4.102
```

Once the kubelet file is edited, we need to restart the kubelet service. Remember, you should do that to all nodes.

```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## Initializing k8s cluster
Before initializing the master node (manager1), we need to choose a pod network add-on. Depending on which networking plugin you choose, we will need to set the '--pod-network-cidr' with the provider specific value.

```
For Calico:

we must pass --pod-network-cidr=192.168.0.0/16 to kubeadm init

For Flannel:

we must pass --pod-network-cidr=10.244.0.0/16 to kubeadm init
```

On the manager1 VM, we will initialize the cluster and configure kubectl. 

kubeadm uses the network interface associated with the default gateway to advertise the manager’s IP. To use a different network interface, we need to specify the --apiserver-advertise-address=<ip-address> argument to kubeadm init. This is our case as we are using a Vagrant VM with a private network. The ip (192.168.50.100) is the manager1 IP which was set in the Vagranfile private network setup.

The --apiserver-advertise-address=192.168.50.100 is important to be set as it will be part of a join command used by workers to join the manager. If we miss to specify this flag, the join command will have the wrong manager addr, consequently the worker will not be able to join the cluster.

To initialize the cluster, execute the following command.

**For Calico**

```
sudo kubeadm init --apiserver-advertise-address=172.17.4.100 --pod-network-cidr=192.168.0.0/16
```

**For Flannel**

```
sudo kubeadm init --apiserver-advertise-address=172.17.4.100 --pod-network-cidr=10.244.0.0/16
```

Once kubeadm init is done, you should receive a msg "Your Kubernetes master has initialized successfully!" along with further instructions such as the join command to be used by workers.

```
You can now join any number of machines by running the following on each node
as root:

  kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

To start using your cluster, you need to execute the following steps to allow a regular user to run Kubectl commands.

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Once it is done, you can check the manager node using kubectl.

```
kubectl get nodes
```

And we should see.

```
NAME       STATUS     ROLES    AGE    VERSION
manager1   NotReady   master   2m9s   v1.12.2
```

Or add the '-o wide' option to get further information.

```
kubectl get nodes -o wide
```

And we should see.

```
NAME       STATUS     ROLES    AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
manager1   NotReady   master   2m6s   v1.12.2   172.17.4.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-39-generic   docker://18.6.1
```

manager1 should show 'NotReady' status as no networking plugin was installed yet. Also, notice the INTERNAL-IP matches exactly the one we specified in the /etc/default/kubelet.

Verify namespaces created in K8s cluster.

```
kubectl get ns
```
```
NAME            STATUS    AGE
default         Active    3m
kube-public     Active    3m
kube-system     Active    3m
```

## Installing networking plugin
We must install a pod network add-on so that your pods can communicate with each other.The network must be deployed before any applications. Also, CoreDNS will not start up before a network is installed.

**For Calico**
Install Calico with the following command on manager1.

```
kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
```

Once it is done, you should see the following outputs.

```
configmap/calico-config created
service/calico-typha created
deployment.apps/calico-typha created
poddisruptionbudget.policy/calico-typha created
daemonset.extensions/calico-node created
serviceaccount/calico-node created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
```

**For Flannel**

Enable net.bridge.bridge-nf-call-iptables on all three VMs. This is a requirement for Flannel plugin to work.

```
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Install the Flannel networking plugin with the following command on manager1.

```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Once it is done, you should see the following outputs.

```
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.extensions/kube-flannel-ds-amd64 created
daemonset.extensions/kube-flannel-ds-arm64 created
daemonset.extensions/kube-flannel-ds-arm created
daemonset.extensions/kube-flannel-ds-ppc64le created
daemonset.extensions/kube-flannel-ds-s390x created
```

We can now check that the network plugin was intalled and CoreDNS is now started.

```
kubectl get pods --all-namespaces -o wide
```

And for Calico, we should see for example.

```
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE     IP             NODE       NOMINATED NODE
kube-system   calico-node-m4ml2                  2/2     Running   0          40s     172.17.4.100   manager1   <none>
kube-system   coredns-576cbf47c7-g7748           1/1     Running   0          6m7s    192.168.0.3    manager1   <none>
kube-system   coredns-576cbf47c7-xqkmc           1/1     Running   0          6m7s    192.168.0.4    manager1   <none>
kube-system   etcd-manager1                      1/1     Running   0          5m32s   172.17.4.100   manager1   <none>
kube-system   kube-apiserver-manager1            1/1     Running   0          5m5s    172.17.4.100   manager1   <none>
kube-system   kube-controller-manager-manager1   1/1     Running   0          5m27s   172.17.4.100   manager1   <none>
kube-system   kube-proxy-qrvbn                   1/1     Running   0          6m7s    172.17.4.100   manager1   <none>
kube-system   kube-scheduler-manager1            1/1     Running   0          5m19s   172.17.4.100   manager1   <none>
```

As Calico was installed, CoreDNS will have an IP range based on the --pod-network-cidr=192.168.0.0/16 specified in the kubeadm init.

## Join workers
We can now join the worker1 and worker2 to the k8s hands-on cluster. The kubeadm init command that you ran on the master had printed a kubeadm join command containing a token. You should run it on both worker nodes with sudo.

sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

Once you join both workers, we can check in the manager1 the list of nodes of out lab cluster.

```
kubectl get nodes -o wide
```

And we should see.

```
NAME       STATUS   ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
manager1   Ready    master   12m   v1.12.2   172.17.4.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-39-generic   docker://18.6.1
worker1    Ready    <none>   41s   v1.12.2   172.17.4.101   <none>        Ubuntu 18.04.1 LTS   4.15.0-39-generic   docker://18.6.1
worker2    Ready    <none>   34s   v1.12.2   172.17.4.102   <none>        Ubuntu 18.04.1 LTS   4.15.0-39-generic   docker://18.6.1
```

Also, pods were added for kube-proxy and calico in the joined workers.

```
kubectl get pods --all-namespaces -o wide
```

```
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE     IP             NODE       NOMINATED NODE
kube-system   calico-node-lmfkb                  2/2     Running   0          55s     172.17.4.102   worker2    <none>
kube-system   calico-node-m4ml2                  2/2     Running   0          6m57s   172.17.4.100   manager1   <none>
kube-system   calico-node-vjqvd                  2/2     Running   0          62s     172.17.4.101   worker1    <none>
kube-system   coredns-576cbf47c7-g7748           1/1     Running   0          12m     192.168.0.3    manager1   <none>
kube-system   coredns-576cbf47c7-xqkmc           1/1     Running   0          12m     192.168.0.4    manager1   <none>
kube-system   etcd-manager1                      1/1     Running   0          11m     172.17.4.100   manager1   <none>
kube-system   kube-apiserver-manager1            1/1     Running   0          11m     172.17.4.100   manager1   <none>
kube-system   kube-controller-manager-manager1   1/1     Running   0          11m     172.17.4.100   manager1   <none>
kube-system   kube-proxy-nfzw7                   1/1     Running   0          55s     172.17.4.102   worker2    <none>
kube-system   kube-proxy-qrvbn                   1/1     Running   0          12m     172.17.4.100   manager1   <none>
kube-system   kube-proxy-w24sx                   1/1     Running   0          62s     172.17.4.101   worker1    <none>
kube-system   kube-scheduler-manager1            1/1     Running   0          11m     172.17.4.100   manager1   <none>
```

## TIP
If we want to add more workers in the future and did not save the join command generated by kubeadm during the init, here is how we can get the join command again.

```
kubeadm token create --print-join-command
```

If we made a mistake and want to start over the kubadm init, we can reset what was done and start over by running reset command.

```
sudo kubeadm reset
```

If we want to check logs of pods.

```
kubectl -n [NAMESPACE] logs [POD_NAME]
```

To get a node config file.

```
kubectl get nodes manager1 -o yaml
```
