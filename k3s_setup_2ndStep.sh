#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Vérififcation de l'installation de K3s ---"

echo ""
echo "///////////////////////////////////////////////"
echo "Vérification des dernières lignes de ~/.bashrc "
echo "///////////////////////////////////////////////"

echo ""
echo "👉👉👉 cmd: tail -n 1 ~/.bashrc"
echo "ℹ️ℹ️ℹ️ Vous devez voir export KUBECONFIG=$HOME/.kube/config"
tail -n 1 ~/.bashrc

echo ""
echo "/////////////////////////////////////////////"
echo "Vérification Installation de K3s SANS sudo..."
echo "/////////////////////////////////////////////"

echo ""
echo "👉👉👉 cmd: which kubectl"
which kubectl

echo ""
echo "👉👉👉 cmd: kubectl version --client"
kubectl version --client

echo ""
echo "👉👉👉 vérification de la valeur de la variable KUBECONFIG"
echo $KUBECONFIG

echo ""
echo "👉👉👉 cmd: kubectl version --client"
kubectl get nodes

# presque équivalent à docker ps - voir les services running
echo ""
echo "👉👉👉 cmd: kubectl version --client"
kubectl get pods -A

# l'équivalent de docker images
echo ""
echo "👉👉👉 cmd: kubectl version --client"
kubectl get pods -A -o wide
# équivalent docker compose up -d
# kubectl apply -f deployment.yam
# Si on ne veut qu'un service
# kubectl create deployment nginx --image=nginx
# équivalent docker images
# sudo k3s ctr images list
echo ""
echo "//////////////////////////////////////////////////"
echo "--- Installation terminée avec succès ! ---"
echo "On peut maintenant utiliser les commmandes kubectl"
echo "//////////////////////////////////////////////////"
echo ""
