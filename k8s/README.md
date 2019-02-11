# Overview

This folder contains hands-on guides related to k8s. The purpose of it is to exercise the k8s setup as well as its administration and usage.

# Scope

## Bootstrapping Clusters

* kubeadm: helps you bootstrap a minimum viable Kubernetes cluster that conforms to best practices

## Cluster Network

* Flannel
* Calico

Kubernetes approaches networking somewhat differently than Docker does by default. There are 4 distinct networking problems to solve:

* Highly-coupled container-to-container communications: this is solved by pods and localhost communications.
* Pod-to-Pod communications: this is the primary focus of this document.
* Pod-to-Service communications: this is covered by services.
* External-to-Service communications: this is covered by services.

Kubernetes assumes that pods can communicate with other pods, regardless of which host they land on. Every pod gets its own IP 
address so you do not need to explicitly create links between pods and you almost never need to deal with mapping container ports 
to host ports. This creates a clean, backwards-compatible model where pods can be treated much like VMs or physical hosts from the perspectives of port allocation, naming, service discovery, load balancing, application configuration, and migration.

There are requirements imposed on how you set up your cluster networking to achieve this.

Source: https://kubernetes.io/docs/concepts/cluster-administration/networking/


