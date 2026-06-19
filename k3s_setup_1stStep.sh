#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Démarrage de l'installation de K3s ---"

# 1. Installation de K3s
echo ""
echo "///////////////////////////////////"
echo "Installation de K3s..."
echo "///////////////////////////////////"
# curl -sfL https://get.k3s.io | sh -
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.29.6+k3s1 sh -

# --- AJOUTER CE BLOC D'ATTENTE ---
#echo "Attente de la génération du fichier de configuration K3s..."
#while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
#  echo -n "."
#  sleep 2
#done

# --- Vérification
echo ""
echo "/////////////////////////////////////////////"
echo "Vérification Installation de K3s AVEC sudo..."
echo "/////////////////////////////////////////////"
#sudo k3s kubectl get nodes
echo "Attente que le nœud soit Ready..."
#until sudo k3s kubectl get nodes >/dev/null 2>&1; do
until sudo k3s kubectl get nodes | grep -q Ready; do
  echo -n "."
  sleep 2
done


# 2. Installation de kubectl
echo ""
echo "**************************************************************"
echo "Installation de kubectl UTILE SLT POUR MULTI CLUSTER CLIENT..."
echo "DONC PAS FAIT POUR LE MOMENT.................................."
echo "**************************************************************"
#sudo snap install kubectl --classic

# 3. Installation de Helm
echo ""
echo "##################################"
echo "Installation de Helm..."
echo "##################################"
#curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4. Configuration des permissions pour kubectl
# Pour utiliser kubectl sans sudo
echo ""
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "Configuration des permissions..."
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
mkdir -p ~/.kube
# D'ABORD, on change les droits du fichier source (celui de K3s)
# On copie. Le sudo s'applique à cat uniquement et config créé est user
# Donc fonctionne même quand le fichier est protégé
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
# sudo chown $(id -u):$(id -g) ~/.kube/config
# sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Utile dans le Makefile pour utiliser directement les commandes kubectl
# Si ce n'est pas fait, il faut utiliser la commande k3s kubectl...
export KUBECONFIG="$HOME/.kube/config"
echo ">>>>> vérification de la valeur de la variable >>>>>>"
echo $KUBECONFIG

# 5. Ajout de l'export KUBECONFIG pour être certain que kubectl pointe toujours au bon endroit
echo ""
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo " Ajout de l'export KUBECONFIG dans ~./bashrc"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if ! grep -q "KUBECONFIG" ~/.bashrc; then
  echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
fi
#source ~/.bashrc

# source ~/.bashrc indispensable si on veut utiliser les commandes kubectl directement depuis le terminal
# Si ce n'est pas fait, il faut utiliser la commande k3s kubectl...
echo ""
echo "/////////////////////////////////////////////////////"
echo " IMPERATIF: Lancer manuellement la commande suivante "
echo " 💥💥💥💥💥💥💥💥 source ~/.bashrc 💥💥💥💥💥💥💥💥💥"
echo "/////////////////////////////////////////////////////"

echo ""
echo "/////////////////////////////////////////////////////"
echo " Ensuite relancer la commande suivante pour vérifier "
echo "🛡️🛡️🛡️🛡️🛡️🛡️🛡️ ./k3s_setup_2ndStep.sh 🛡️🛡️🛡️🛡️🛡️🛡️🛡️"
echo "/////////////////////////////////////////////////////"
