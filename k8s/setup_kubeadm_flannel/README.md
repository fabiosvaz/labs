# Overview
This lab will guide you on how to set up a K8s cluster environment using Flannel as the networking pluggin. The Vagrantfile used will
configure 3 VMS: manager1, worker1 and worker2. The three VMs will be configured by Vagrant with Ubuntu 18, 1 CPU and 2048GB ram. 
If you want to modify the resources allocated to the VMS, you can modify the Vagrantfile.

Flannel is a very simple overlay network that satisfies the Kubernetes requirements. Many people have reported success with Flannel and Kubernetes.

https://github.com/coreos/flannel#flannel


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

Enable net.bridge.bridge-nf-call-iptables on all three VMs. This is a requirement for some CNI plugins to work. In this case, Flannel.

```
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Disable swap on all three servers

```
sudo swapoff -a
```

On the manager1 VM, initialize the cluster and configure kubectl. For flannel to work correctly, you must pass --pod-network-cidr=10.244.0.0/16 to kubeadm init.
The --apiserver-advertise-address=192.168.50.100 is important to be set as it will be part of a join command used by workers to join the manager.
The ip (192.168.50.100) is the manager1 IP which was set in the Vagranfile private network setup.

```
sudo kubeadm init --apiserver-advertise-address=192.168.50.100 --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Check the installation of kubectl.

```
kubectl get nodes

NAME       STATUS     ROLES    AGE    VERSION
manager1   NotReady   master   5m9s   v1.12.2

manager1 should have NotReady as no networking was installed yet.
```

Install the flannel networking plugin in the cluster by running this command on the Kube Master server.

```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
```

The kubeadm init command that you ran on the master should output a kubeadm join command containing a token and hash. You will need to copy that command from the master and run it on both worker nodes with sudo.

sudo kubeadm join $controller_private_ip:6443 --token $token --discovery-token-ca-cert-hash $hash

Now you are ready to verify that the cluster is up and running. On the Kube Master server, check the list of nodes.

```
kubectl get nodes
```
```
It should look something like this:

NAME       STATUS   ROLES    AGE   VERSION
manager1   Ready    master   13h   v1.12.2
worker1    Ready    <none>   13h   v1.12.2
worker2    Ready    <none>   13h   v1.12.2
```

Make sure that all three of your nodes are listed and that all have a STATUS of Ready.

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
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
kube-system   coredns-576cbf47c7-8hq7l           1/1     Running   0          17h
kube-system   coredns-576cbf47c7-r7fgf           1/1     Running   0          17h
kube-system   etcd-manager1                      1/1     Running   0          17h
kube-system   kube-apiserver-manager1            1/1     Running   0          17h
kube-system   kube-controller-manager-manager1   1/1     Running   0          17h
kube-system   kube-flannel-ds-amd64-bbcqx        1/1     Running   0          17h
kube-system   kube-flannel-ds-amd64-c6kgj        1/1     Running   0          17h
kube-system   kube-flannel-ds-amd64-r4z6q        1/1     Running   0          17h
kube-system   kube-proxy-dmmdz                   1/1     Running   0          17h
kube-system   kube-proxy-k8lt6                   1/1     Running   0          17h
kube-system   kube-proxy-pkz4n                   1/1     Running   0          17h
kube-system   kube-scheduler-manager1            1/1     Running   0          17h
```

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
