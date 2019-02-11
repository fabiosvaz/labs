# Overview
This is a hands-on guide on how to scale up and down an app in a k8s cluster.

# Requirements
- K8s cluster configured. [Setup k8s multicluster](https://github.com/fabiosvaz/playground/tree/master/k8s/setup_kubeadm_multi_clusters) 
- App deployed. We can reuse the one from [Deploy first app](https://github.com/fabiosvaz/playground/tree/master/k8s/deploy_first_app) 

# Hands-on

## Scaling up

All the commands here will be executed in the manager node.

When traffic to an app increases and we need to scale the application to keep up with user demand, we can increase the number of replicas deployed in k8s cluster.

We can check the current deployment by running 'kubectl get deployments'.

```
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           2d18h
```

So, let's scale our app to 3 replicas by running 'kubectl scale' command.

```
kubectl scale deployments/kubernetes-bootcamp --replicas=3
```

And we should see.

```
deployment.extensions/kubernetes-bootcamp scaled
```

Now, if we run again the 'kubectl get deployments' we should see.

```
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   3         3         3            3           2d18h
```

The scaling featurewill ensure new Pods are created and scheduled to Nodes with available resources. Scaling will increase the number of Pods to the new desired state. By running 'kubectl get pods -o wide', we can see the new pods were distributed in the existing workers.

```
NAME                                   READY   STATUS    RESTARTS   AGE     IP            NODE      NOMINATED NODE
kubernetes-bootcamp-598f57b95c-c472s   1/1     Running   0          62s     192.168.1.4   worker1   <none>
kubernetes-bootcamp-598f57b95c-hvqc8   1/1     Running   1          2d18h   192.168.2.3   worker2   <none>
kubernetes-bootcamp-598f57b95c-rbncq   1/1     Running   0          62s     192.168.1.3   worker1   <none>

```

## Load Balancing

Running multiple instances of an application will require a way to distribute the traffic to all of them. Services have an integrated load-balancer that will distribute network traffic to all Pods of an exposed Deployment.

If we describe the existing service for our app, we can see there are 3 endpoints set. Services will monitor continuously the running Pods using endpoints, to ensure the traffic is sent only to available Pods.

```
kubectl describe services/kubernetes-bootcamp
```

And we should see.

```
Name:                     kubernetes-bootcamp
Namespace:                default
Labels:                   run=kubernetes-bootcamp
Annotations:              <none>
Selector:                 run=kubernetes-bootcamp
Type:                     NodePort
IP:                       10.102.122.148
Port:                     <unset>  8080/TCP
TargetPort:               8080/TCP
NodePort:                 <unset>  30596/TCP
Endpoints:                192.168.1.3:8080,192.168.1.4:8080,192.168.2.3:8080
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

From the command above, get the NodePort. This is the port exposed to the 'external world'. In this hands-on, it was 30596. Now, let's reach the app several times and check the output message.

```
curl http://localhost:${NODE_PORT}
```

And we should see for example.

```
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-598f57b95c-c472s | v=1

Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-598f57b95c-hvqc8 | v=1

Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-598f57b95c-rbncq | v=1
```

## Test desired deployment set

K8s will ensure the desired number of deployment will be respected based on the scale set. In the previous scaling up, we have scale the app to 3 replicas. So if one pod is deleted or goes down, k8s will ensure a new pod is created and scheduled in a node with available resources. 

To test it, open a new terminal and ssh to the manager node. run a 'watch kubectl get pods' command in this new terminal. Once you have done it and started to monitor the pods, lets delete one of the pods.

```
kubectl delete pods kubernetes-bootcamp-598f57b95c-c472s
```

So you should see something like.

```
NAME                                   READY   STATUS        RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-5ld28   1/1     Running       0          37s
kubernetes-bootcamp-598f57b95c-c472s   1/1     Running       0          33m
kubernetes-bootcamp-598f57b95c-hvqc8   1/1     Running       1          2d18h

NAME                                   READY   STATUS        RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-5ld28   1/1     Running       0          7m16s
kubernetes-bootcamp-598f57b95c-c472s   1/1     Terminating   0          39m
kubernetes-bootcamp-598f57b95c-hvqc8   1/1     Running       1          2d18h
kubernetes-bootcamp-598f57b95c-kz6x4   1/1     Running       0          1s

NAME                                   READY   STATUS    RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-5ld28   1/1     Running   0          7m56s
kubernetes-bootcamp-598f57b95c-hvqc8   1/1     Running   1          2d18h
kubernetes-bootcamp-598f57b95c-kz6x4   1/1     Running   0          41s
```

## Scaling down

To scale down the depployment, the same 'kubectl scale' command should be used.

```
kubectl scale deployments/kubernetes-bootcamp --replicas=1
```

And we should see.

```
deployment.extensions/kubernetes-bootcamp scaled
```

Now, if we run again the 'kubectl get deployments' we should see.

```
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           2d18h
```

## References

https://kubernetes.io/docs/tutorials/kubernetes-basics