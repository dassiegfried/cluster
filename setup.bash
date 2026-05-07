#!/bin/bash
cd kubespray
#Provision VMs as k8s cluster according to inventory file 
ansible-playbook -i inventory/sample/inventory.ini cluster.yml  -b -v --private-key=~/.ssh/id_ed25519   

#allow this instance to access k8s cluster using kubectl by copying admin.conf credentials to default locatiion
ssh bier@192.168.1.74 "sudo cp /etc/kubernetes/admin.conf ~/admin.conf && sudo chown bier:bier admin.conf"
rsync bier@192.168.1.74:~/admin.conf ~/.kube/config

#add lables to the two nodes to allow skewing and balancing of pods based on node labels
kubectl label node node1 node=node1
kubectl label node node2 node=node2

#make ControlPlane node also a worker (remove taints)
kubectl taint nodes node1 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label node node1 node-role.kubernetes.io/worker=worker
kubectl label node node2 node-role.kubernetes.io/worker=worker

# prepare metallb prerequisites 
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

#install argocd
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml