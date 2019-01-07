# Overview
This lab will guide you on how to set up a K8s cluster environment using kubeadm. For the required networking plugin, this guide you have steps to install Flannel or Calico.

The cluster will be created with 3 VMS: manager1, worker1 and worker2. The three VMs will be configured by Vagrant with Ubuntu 18, 1 CPU and 2048GB ram. 
If you want to modify the resources allocated to the VMS, you can modify the Vagrantfile.

# Requirements
- Vagrant (https://www.vagrantup.com/downloads.html)
- VirtualBox (https://www.virtualbox.org/wiki/Downloads)

For information on how to use Vagrant, visit the Vagrant lab. TBD

# Lab

## Create Cluster Nodes
Checkout this lab and provide any desired modification to the Vagrantfile. Once ready, create the VMs using Vagrant.

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

From now on, you can ssh to each VM and follow the next instructions. vagrant ssh [vm_name]

```
vagrant ssh manager1
```

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

Add vagrant user to docker group to run docker commands with no sudo required

```
usermod -aG docker vagrant
```

Prevent updates for the installed packages above.

```
sudo apt-mark hold docker-ce kubelet kubeadm kubectl
```

Disable swap on all three servers. This is required by kubelet

```
sudo swapoff -a
```

Permanently disable swap to keep it off after any vagrant halt/reboot. kubeadm pre-flight checks look for swap space disabled, since Kubernetes cannot use swap space due to memory limits. If swap is not disabled, this can affect the restart of the Kubernetes cluster on VM reboot.

```
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

## Fix Kubelet config
Before proceeding with the cluster initialization, we need to fix a kubelet configuration on each node that contains a wrong IP. This is required as we are using Vagrant and creating a private network for the lab cluster.

Vagrant creates two network interfaces for each machine. eth0 is NAT network, eth1 is a private network. The main Kubernetes interface is on eth1. We need to add an explicit IP address that uses the eth1 interface on the nodes, enabling the manager’s API server to properly access the worker’s kubelet. To confirm the issue, you can run the following command in manager1 node.

```
kubectl get nodes worker1 -o yaml
```

You will notice a wrong IP, which is the eth0 one.

```
status:
  addresses:
  - address: 10.0.2.15
    type: InternalIP
```

The same ip will be visible for manager1 and worker2. To fix the issue, we need to edit the kubelet configuration for all nodes <b>/etc/default/kubelet</b> and add a --node-ip flag.

```
KUBELET_EXTRA_ARGS=--node-ip=NODE_IP_ADDR
```

ssh to each node (This change also includes manager1), and add the flag in <b>/etc/default/kubelet</b>

```
Manager1 will be: KUBELET_EXTRA_ARGS=--node-ip=192.168.50.100
Worker1 will be:  KUBELET_EXTRA_ARGS=--node-ip=192.168.50.101
Worker2 will be:  KUBELET_EXTRA_ARGS=--node-ip=192.168.50.102
```

Once the kubelet file is edited, we need to restart the kubelet service. Remember, you should do that to all nodes.

```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

You can now check again the worker1 node configuration, or worker2, or manager1.

```
kubectl get nodes worker1 -o yaml
```

You will notice the correct IP.

```
status:
  addresses:
  - address: 198.168.50.101
    type: InternalIP
```

## Initialize k8s cluster
Now, before initializing the master node (manager1), we need to choose a pod network add-on. Depending on which networking plugin you choose, we will need to set the '--pod-network-cidr' with the provider specific value.

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
sudo kubeadm init --apiserver-advertise-address=192.168.50.100 --pod-network-cidr=192.168.0.0/16
```

**For Flannel**

```
sudo kubeadm init --apiserver-advertise-address=192.168.50.100 --pod-network-cidr=10.244.0.0/16
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
manager1   NotReady   master   5m9s   v1.12.2
```

Or add the '-o wide' option to get further information

```
kubectl get nodes -o wide
```

And we should see.

```
NAME       STATUS   ROLES    AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
manager1   NotReady    master   5m9s   v1.12.2   192.168.50.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-39-generic   docker://18.6.1
```

manager1 should show 'NotReady' status as no networking plugin was installed yet.

We can now join the worker1 and worker2 to the lab cluster. The kubeadm init command that you ran on the master had printed a kubeadm join command containing a token and hash. You should run it on both worker nodes with sudo.

sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

Once you join both workers, we can check in the manager1 the list of nodes of out lab cluster.

```
kubectl get nodes
```
```
It should look something like this:

NAME       STATUS      ROLES    AGE     VERSION
manager1   NotReady    master   10m     v1.12.2
worker1    NotReady    <none>   2m58s   v1.12.2
worker2    NotReady    <none>   56s     v1.12.2
```

## Install networking plugin

**For Calico**
Install an etcd instance with the following command on manager1.

```
kubectl apply -f https://docs.projectcalico.org/v3.4/getting-started/kubernetes/installation/hosted/etcd.yaml
```

Once it is done, you should see the following outputs.

```
daemonset.extensions/calico-etcd created
service/calico-etcd created
```

Install the Calico networking plugin with the following command on manager1.

```
kubectl apply -f https://docs.projectcalico.org/v3.4/getting-started/kubernetes/installation/hosted/calico.yaml
```

Once it is done, you should see the following outputs.

```
configmap/calico-config created
secret/calico-etcd-secrets created
daemonset.extensions/calico-node created
serviceaccount/calico-node created
deployment.extensions/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
```

**For Flannel**

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

## Checking initialization

After the networking plugin is installed, we can check in the manager1 node that all nodes are 'Ready'.

```
kubectl get nodes
```
```
NAME       STATUS   ROLES    AGE   VERSION
manager1   Ready    master   50m   v1.12.2
worker1    Ready    <none>   47m   v1.12.2
worker2    Ready    <none>   47m   v1.12.2
```

Make sure that all three of your nodes are listed and that all have a STATUS of Ready. It can take a few seconds to get the status to 'Ready'.

You can run additional commands to verify the bootstrap of k8s.

```
kubectl get pods
```

And you should see: No resources found. This is because we did not deployed any application yet. Everything we have done is under system level namespace.

You can check the pods for all namespace / system level.

```
kubectl get pods --all-namespaces
```

<b>For Calico</b>
```
kubectl get pods --all-namespaces
```
```
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-etcd-qqsgq                          1/1     Running   0          118m
kube-system   calico-kube-controllers-7766648f5c-nqgx7   1/1     Running   1          119m
kube-system   calico-node-64dn6                          1/1     Running   38         104m
kube-system   calico-node-jk9b6                          1/1     Running   30         98m
kube-system   calico-node-zvqw5                          1/1     Running   2          119m
kube-system   coredns-576cbf47c7-5f72z                   1/1     Running   0          124m
kube-system   coredns-576cbf47c7-86k6p                   1/1     Running   0          124m
kube-system   etcd-manager1                              1/1     Running   0          123m
kube-system   kube-apiserver-manager1                    1/1     Running   0          124m
kube-system   kube-controller-manager-manager1           1/1     Running   0          124m
kube-system   kube-proxy-8sfm9                           1/1     Running   0          124m
kube-system   kube-proxy-g9jwg                           1/1     Running   0          98m
kube-system   kube-proxy-t4bl6                           1/1     Running   0          104m
kube-system   kube-scheduler-manager1                    1/1     Running   0          124m
```

Verify namespaces created in K8s systems

```
kubectl get ns
```
```
NAME            STATUS    AGE
default         Active    1m
kube-public     Active    1m
kube-system     Active    1m
```

Namespaces are intendent to isolate groups/teams and give them access to a set of resources. They avoid name collisions between resources. Namespaces provides with a soft Multitenancy, meaning they not provide full isolation.

By default Kubernetes deployed by kubeadm starts with 3 namespaces:

* **default**: The default namespace for objects with no other namespace. When listing resources with the kubectl get command, we’ve never specified the namespace explicitly, so kubectl always defaulted to the default namespace, showing us just the objects inside that namespace.
* **kube-system**: The namespace for objects created by the Kubernetes system
* **kube-public**: Used at cluster Bootstrap and contains cluster-info ConfigMap


## TIP

If you want to add more workers in the future and did not save the join command generated by kubeadm during the init, here is how you can get the join command again 

```
kubeadm token create --print-join-command
```

If you made a mistake and want to start over the kubadm init, you can reset what was done and start over by running:

```
kubeadm reset
```

If you want just switch the networking plugin for example, you can use kubectl to delete/revert the deployment done by the 'kubectl apply'

```
kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

If you want to check logs of pods from system namespace.

```
kubectl --namespace kube-system logs [POD_NAME]
```
