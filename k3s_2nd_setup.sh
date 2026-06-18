#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Démarrage de l'installation de K3s ---"

# 1. Installation de K3s
echo ""
echo "///////////////////////////////////"
echo "Installation de K3s..."
echo "///////////////////////////////////"
curl -sfL https://get.k3s.io | sh -

# --- AJOUTER CE BLOC D'ATTENTE ---
echo "Attente de la génération du fichier de configuration K3s..."
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  echo -n "."
  sleep 2
done

# 2. Installation de kubectl
echo ""
echo "**********************************"
echo "Installation de kubectl..."
echo "**********************************"
sudo snap install kubectl --classic

# 3. Installation de Helm
echo ""
echo "##################################"
echo "Installation de Helm..."
echo "##################################"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4. Configuration des permissions pour kubectl
# Pour utiliser kubectl sans sudo
echo ""
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "Configuration des permissions..."
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
mkdir -p ~/.kube
# D'ABORD, on change les droits du fichier source (celui de K3s)
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# 5. Ajout de l'export KUBECONFIG pour être certain que kubectl pointe toujours au bon endroit
echo ""
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo " Ajout de l'export KUBECONFIG dans ~./bashrc"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if ! grep -q "KUBECONFIG" ~/.bashrc; then
  echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
fi
source ~/.bashrc

echo ""
echo "//////////////////////////////////////////////////"
echo "--- Installation terminée avec succès ! ---"
echo "On peut maintenant tester avec : kubectl get nodes"
echo "//////////////////////////////////////////////////"
echo ""
