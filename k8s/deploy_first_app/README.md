# Overview
This is a hands-on guide on how to deploy an app in a k8s cluster. We will be creating and managing a Deployment by using kubectl commands.

# Requirements
- K8s cluster configured. [Setup k8s multicluster](https://github.com/fabiosvaz/playground/tree/master/k8s/setup_kubeadm_multi_clusters) 

# Hands-on

## Deployment

Firstly, we need to get inside the manager1 node by running.

```
vagrant ssh manager1
```

For this first app deployment, we will be using the official kubernetes bootcamp app. To run the bootcamp app in out running k8s cluster, we can use 'kubectl run' command

```
kubectl run kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 --port=8080
```

The run command will create a deployment named 'kubernetes-bootcamp' in the default namespace and run the container based on the image 'gcr.io/google-samples/kubernetes-bootcamp:v1' in the port 8080.

And we should see as output.

```
deployment.apps/kubernetes-bootcamp created 
```

We can also verify the deployments using 'kubectl get deployments'.

```
kubectl get deployments
```

And we should see.

```
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           6m
```

## Play around

Once deployed, we can now run more kubectl commands and check more information about our first app deployment.

Check pods

```
kubectl get pods
```

And we should see.

```
NAME                                   READY   STATUS    RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-rp955   1/1     Running   0          28s
```

We can also see where the new pod was created.

```
kubectl get pods -o wide
```

And we should see something like.

```
NAME                                   READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE
kubernetes-bootcamp-598f57b95c-rp955   1/1     Running   0          5m1s   192.168.1.2   worker1   <none>
```

We can try to reach the application deployed now by using curl.

```
curl http://localhost:8080
```

And we should get.

```
curl: (7) Failed to connect to localhost port 8080: Connection refused
```

That is because pods that are running inside Kubernetes are running on a private, isolated network. By default they are visible from other pods and services within the same kubernetes cluster, but not outside that network. 

So there are a couple of options we can use to expose the application to the outside world, but for now we can use 'proxy' command just for simplicity. Before doing that, we need to open a second terminal to run the 'proxy' command

```
vagrant ssh manager1
```

```
kubectl proxy --disable-filter=true --address=0.0.0.0
```

So now, the proxy command has forwarded communication and we have now connection from our host to the k8s cluster. In the first terminal, we can check connectivity to the proxy by running.

```
curl http://localhost:8001/version
```

And we should see.

```
{
  "major": "1",
  "minor": "12",
  "gitVersion": "v1.12.5",
  "gitCommit": "51dd616cdd25d6ee22c83a858773b607328a18ec",
  "gitTreeState": "clean",
  "buildDate": "2019-01-16T18:14:49Z",
  "goVersion": "go1.10.7",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

Now, we can do a request to our deployed app by using proxy. First we need to get the pod name bu running.

```
kubectl get pods
```

And we should get the name created for out pod.

```
NAME                                   READY   STATUS    RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-rp955   1/1     Running   0          23m
```

If you want to play a little with the 'go-template' param, we can run.

```
export POD_NAME=$(kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
echo Name of the Pod: $POD_NAME
```

So now, all that we need is run curl against proxy.

```
curl http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME/proxy/
```

And we should see.

```
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-598f57b95c-rp955 | v=1
```

## Create a Service

By default, we have a service called kubernetes that is created when kubeadm starts the cluster. We can check it by running kubectl.

```
kubectl get services
```

And we should see.

```
NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes            ClusterIP   10.96.0.1       <none>        443/TCP          30m
```

To create a new service to our application and expose it to external traffic we will use the expose command with NodePort as parameter.

```
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080
```

And we should see.

```
service/kubernetes-bootcamp exposed
```

If we run again kubectl to check k8s services

```
kubectl get services
```

we should see.

```
NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes            ClusterIP   10.96.0.1       <none>        443/TCP          33m
kubernetes-bootcamp   NodePort    10.110.60.234   <none>        8080:31067/TCP   33m
```

To get further information about the service created, we can run 'kubectl describe'.

```
kubectl describe services/kubernetes-bootcamp
```

and we should see something like.

```
Name:                     kubernetes-bootcamp
Namespace:                default
Labels:                   run=kubernetes-bootcamp
Annotations:              <none>
Selector:                 run=kubernetes-bootcamp
Type:                     NodePort
IP:                       10.110.60.234
Port:                     <unset>  8080/TCP
TargetPort:               8080/TCP
NodePort:                 <unset>  31067/TCP
Endpoints:                172.18.0.2:8080
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

With the service created and having the type set as NodePort, we can execute a curl command to our application without requiring kubectl proxy. The port to be used should be the one assigned to NodePort information. This is the port exposed for the 'external world'. The port 8080 is exposed internally in the k8s cluster.

```
curl http://localhost:31067
```

And we should see.

```
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-598f57b95c-rp955 | v=1
```

## Clean up

Once we are done we out hands on, we can clean up out k8s cluster by running the following steps.

To stop proxy in the second terminal, just hit a CTRL+C. Once you do that, we should not have any more communication between our host and the k8s cluster.

```
curl http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME/proxy/
curl: (7) Failed to connect to localhost port 8001: Connection refused
```

Remove the deployment and pod by running.

```
kubectl delete deployment $POD_NAME
```

And we should see.

```
deployment.extensions "kubernetes-bootcamp" deleted
```

If we run now.

```
 kubectl get deployments
```

We should see.

```
No resources found.
```

Also, by removing the deployment, the pod gets terminated and removed as well.

```
kubectl get pods
```

```
NAME                                   READY   STATUS        RESTARTS   AGE
kubernetes-bootcamp-598f57b95c-rp955   1/1     Terminating   0          29m
```

```
No resources found.
```

## References

https://kubernetes.io/docs/tutorials/kubernetes-basics