# Overview
This lab will guide you on how to set up a K8s cluster environment using Calico as the networking pluggin. The Vagrantfile used will
configure 3 VMS: manager1, worker1 and worker2. The three VMs will be configured by Vagrant with Ubuntu 18, 1 CPU and 2048GB ram. 
If you want to modify the resources allocated to the VMS, you can modify the Vagrantfile.

Calico provides secure network connectivity for containers and virtual machine workloads.

Calico creates and manages a flat layer 3 network, assigning each workload a fully routable IP address. Workloads can communicate without IP encapsulation or network address translation for bare metal performance, easier troubleshooting, and better interoperability. In environments that require an overlay, Calico uses IP-in-IP tunneling or can work with other overlay networking such as flannel.

Calico also provides dynamic enforcement of network security rules. Using Calico’s simple policy language, you can achieve fine-grained control over communications between containers, virtual machine workloads, and bare metal host endpoints.

https://github.com/projectcalico/calico


# Requirements
- Vagrant (https://www.vagrantup.com/downloads.html)
- VirtualBox (https://www.virtualbox.org/wiki/Downloads)

# Lab

Checkout this lab and provide any modification to the Vagrantfile if needed. Once ready, create the VMs using Vagrant.

```
vagrant up
```

This will take some time, as 3 VMs will be created and Ubuntu 18 will be installed in it. Once it is done, you can verify the status of
the VMs.

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

Prevent updates for the installed libs above.

```
sudo apt-mark hold docker-ce kubelet kubeadm kubectl
```

Disable swap on all three servers. This is required by kubelet

```
sudo swapoff -a
```

On the manager1 VM, initialize the cluster and configure kubectl. For Calico to work correctly, you must pass --pod-network-cidr=192.168.0.0/16 to kubeadm init.

kubeadm uses the network interface associated with the default gateway to advertise the manager’s IP. To use a different network interface, we need to specify the --apiserver-advertise-address=<ip-address> argument to kubeadm init. This is our case as we are using a VM with a private network. The ip (192.168.50.100) is the manager1 IP which was set in the Vagranfile private network setup.

The --apiserver-advertise-address=192.168.50.100 is important to be set as it will be part of a join command used by workers to join the manager. If we miss to specify this flag, the join command will have the wrong manager addr, consequently the worker will not be able to join the cluster.

```
sudo kubeadm init --apiserver-advertise-address=192.168.50.100 --pod-network-cidr=192.168.0.0/16
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

NAME       STATUS     ROLES    AGE    VERSION
manager1   NotReady   master   5m9s   v1.12.2

manager1 should have NotReady as no networking was installed yet.
```

Install an etcd instance with the following command on the Kube Master server.

```
kubectl apply -f https://docs.projectcalico.org/v3.4/getting-started/kubernetes/installation/hosted/etcd.yaml
```
Once it is done, you should see the following outputs.

```
daemonset.extensions/calico-etcd created
service/calico-etcd created
```

Install the Calico networking plugin with the following command on the Kube Master server.

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

After the Calico networking plugin, you can check the manager1 node is 'Ready'.

```
kubectl get nodes

NAME       STATUS   ROLES    AGE     VERSION
manager1   Ready    master   7m32s   v1.12.2
```

From now on, you can join the worker1 and worker2 to the lab cluster. The kubeadm init command that you ran on the master had printed a kubeadm join command containing a token and hash. You should run it on both worker nodes with sudo.

sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

Now you are ready to verify that the cluster is up and running. On the Kube Master server, check the list of nodes.

```
kubectl get nodes
```
```
It should look something like this:

NAME       STATUS   ROLES    AGE     VERSION
manager1   Ready    master   27m     v1.12.2
worker1    Ready    <none>   6m58s   v1.12.2
worker2    Ready    <none>   56s     v1.12.2
```

Make sure that all three of your nodes are listed and that all have a STATUS of Ready. It can take a few seconds to get the status to 'Ready'.

You can run additional commands to verify the bootstrap of k8s.

```
kubectl get pods
```

And you should see: No resources found. 

You can check the pods for all namespace / system level. Those are the system level pods.

```
kubectl get pods --all-namespaces
```
```
NAMESPACE     NAME                                     READY   STATUS   RESTARTS  AGE
NAMESPACE     NAME                                       READY   STATUS             RESTARTS   AGE
kube-system   calico-etcd-qqsgq                          1/1     Running            0          66m
kube-system   calico-kube-controllers-7766648f5c-nqgx7   1/1     Running            1          66m
kube-system   calico-node-64dn6                          0/1     CrashLoopBackOff   14         51m
kube-system   calico-node-jk9b6                          0/1     CrashLoopBackOff   13         45m
kube-system   calico-node-zvqw5                          1/1     Running            2          66m
kube-system   coredns-576cbf47c7-5f72z                   1/1     Running            0          71m
kube-system   coredns-576cbf47c7-86k6p                   1/1     Running            0          71m
kube-system   etcd-manager1                              1/1     Running            0          71m
kube-system   kube-apiserver-manager1                    1/1     Running            0          71m
kube-system   kube-controller-manager-manager1           1/1     Running            0          71m
kube-system   kube-proxy-8sfm9                           1/1     Running            0          71m
kube-system   kube-proxy-g9jwg                           1/1     Running            0          45m
kube-system   kube-proxy-t4bl6                           1/1     Running            0          51m
kube-system   kube-scheduler-manager1                    1/1     Running            0          71m
```

You should notice something wrong here!! There is CrashLoopBackOff. The calico-node-* are not working as expected. Vagrant creates two network interfaces for each machine. eth0 is NAT network, eth1 is a private network. The main Kubernetes interface is on eth1. We need to add an explicit IP address that uses the eth1 interface on the nodes, enabling the master’s API server to properly access the worker’s kubelet. To confirm the issue, you can run the following command to get the node configuration.

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

Ssh to each worker node, and add the flag in <b>/etc/default/kubelet</b>

```
Manager1
	KUBELET_EXTRA_ARGS=--node-ip=192.168.50.100
Worker1
	KUBELET_EXTRA_ARGS=--node-ip=192.168.50.101
Worker2
  	KUBELET_EXTRA_ARGS=--node-ip=192.168.50.102
```

Once the kubelet file is edited, we need to restart the kubelet service. Remember, you should do that to all workers.

```
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

You can now check again the worker1 node configuration.

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

You can check again the pods for all namespace.

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

*Extra*

By default Kubernetes deployed by kubeadm starts with 3 namespaces:

* **default**: The default namespace for objects with no other namespace. When listing resources with the kubectl get command, we’ve never specified the namespace explicitly, so kubectl always defaulted to the default namespace, showing us just the objects inside that namespace.
* **kube-system**: The namespace for objects created by the Kubernetes system
* **kube-public**: Used at cluster Bootstrap and contains cluster-info ConfigMap


**TIP**

If you want to add more workers in the future and did not save the join command generated by kubeadm during the init, here is how you can get the join command again 

```
kubeadm token create --print-join-command
```

If you made a mistake and want to start over the kubadm init, you can reset what was done and start over by running:

```
kubeadm reset
```
