#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Vérififcation de l'installation de K3s ---"

echo ""
echo "///////////////////////////////////////////////"
echo "Vérification des dernières lignes de ~/.bashrc "
echo "///////////////////////////////////////////////"
echo "👉👉👉 cmd: tail -n 1 ~/.bashrc"
echo "ℹ️ℹ️ℹ️ Vous devez voir export KUBECONFIG=$HOME/.kube/config"
tail -n 1 ~/.bashrc

echo ""
echo "/////////////////////////////////////////////"
echo "Vérification Version HELM utilisée"
echo "/////////////////////////////////////////////"
echo "👉👉👉 cmd: helm version"
helm version

echo ""
echo "/////////////////////////////////////////////"
echo "Vérification Installation de K3s SANS sudo..."
echo "/////////////////////////////////////////////"
echo "👉👉👉 cmd: which kubectl"
which kubectl

echo ""
echo "👉👉👉 cmd: kubectl version --client"
kubectl version --client

echo ""
echo "👉👉👉 vérification de la valeur de la variable KUBECONFIG"
echo $KUBECONFIG

echo ""
echo "👉👉👉 cmd: kubectl get nodes"
kubectl get nodes

# l'équivalent de docker images
echo ""
echo "ℹ️ On attend que tous les pods sont soit Running, soit Completed."
until [ -z "$(kubectl get pods -A --no-headers | grep -vE 'Running|Completed')" ]; do
  echo -n "."
  sleep 2
done
echo "ℹ️ On vérifie que tous les pods Rsont unning ou Completed."
echo "👉👉👉 cmd: kubectl get pods -A -o wide"
kubectl get pods -A -o wide

echo ""
echo "//////////////////////////////////////////////////////////////////////////////////////////////////////"
echo "Vérification de l'absence de Traefik car il n'est plus installé avec k3"
echo "--- Désactivation de Traefik (natif K3s) pour laisser place à Nginx Ingress qui est plus MLOPS PRO ---"
echo "///////////////////////////////////////////////////x///////////////////////////////////////////////////"
echo ""
echo "👉👉👉 cmd: kubectl get pods -A  ==> on NE doit PLUS voir traefik-xxxxxxxxxx-xxxxx"
kubectl get pods -A

echo ""
echo "/////////////////////////////////////////////////////////"
echo "✅✅✅ --- Installation terminée avec succès ! ---"
echo "✅✅✅ On peut maintenant utiliser les commmandes kubectl"
echo "/////////////////////////////////////////////////////////"
echo ""
echo "//////////////////////////////////////////////////////////////////////////////////////////////////////"
echo " Ensuite lancer la commande suivante pour initialiser CERT MANAGER ET LONGHORN (UTILISé POUR LES PVC) "
echo "🛡️🛡️🛡️🛡️🛡️🛡️ ./k3s_setup_3rdStep.sh 🛡️🛡️🛡️🛡️🛡️🛡️"
echo "//////////////////////////////////////////////////////////////////////////////////////////////////////"
