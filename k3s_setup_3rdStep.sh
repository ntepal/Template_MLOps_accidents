#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Adapater le projet sur k3s ---"

#echo ""
#echo "//////////////////////////////////////////////////////////////////////////////////////////////////////"
#echo "Vérification de l'absence de Traefik car il n'est plus installé avec k3"
#echo "--- Désactivation de Traefik (natif K3s) pour laisser place à Nginx Ingress qui est plus MLOPS PRO ---"
#echo "///////////////////////////////////////////////////x///////////////////////////////////////////////////"
#echo ""
#echo "👉👉👉 cmd: kubectl get pods -A  ==> on NE doit PLUS voir traefik-xxxxxxxxxx-xxxxx"
#kubectl get pods -A

echo "📌📌📌 Création du répertoire logs"
mkdir -p logs

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "---------- INSTALLATION cert-manager  --- TOUJOURS LE FAIRE EN PREMIER"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
# Version stable actuelle via Helm
echo "👉👉👉 cmd: helm repo add jetstack https://charts.jetstack.io"
helm repo add jetstack https://charts.jetstack.io
echo "👉👉👉 cmd: helm repo update"
helm repo update
# Créer le namespace et l'installer
#echo "👉👉👉 cmd: helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true"
#helm upgrade --install cert-manager jetstack/cert-manager \
#  -n cert-manager --create-namespace \
#  --set crds.enabled=true

#echo "👉👉👉 cmd: helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true --wait --timeout 10m > logs/cert-manager.log 2>&1"
echo "📌📌📌 Log à partir de la racine dans logs/cert-manager.log"
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait \
  --timeout 10m \
  > logs/cert-manager.log 2>&1
echo "✅ cert-manager installé avec succès"

# Vérification
echo "👉👉👉 cmd: kubectl get pods -n cert-manager  ==> on doit voir cert-manager, cert-manager-cainjector et cert-manager-webhook dans l'état running"
kubectl get pods -n cert-manager
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

# Logs live (on peut ainsi suivre l'évolution sur un autre terminal)
mkdir -p logs

echo ""
echo "///////////////////////////////////////////////////////////////////////////////////////////////"
echo "--- INSTALLATION INGRESS-NGINX (Contrôleur standard MLOps préféré à Traefik par l'indutrie) ---"
echo "///////////////////////////////////////////////////////////////////////////////////////////////"

# Désactivation de Traefik pour éviter les conflits fait au début du ficher
#echo "📌 Désactivation du Traefik natif de K3s..."
#kubectl scale deployment traefik -n kube-system --replicas=0 --ignore-not-found

# Installation Nginx avec exposition directe sur l'IP de la VM
echo "📌 Installation d'Ingress-Nginx (Mode LoadBalancer)..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Le LoadBalencer pour me permettre de faire http://<IP_PUBLIQUE_DE_VOTRE_VM>/xxx
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait \
  --timeout 10m

echo "✅ Ingress-Nginx est opérationnel et est exposé sur l'IP de la VM."
# Vérification pour ingress-nginx
echo ""
echo "👉👉👉 Vérification de l'installation ingress-nginx..."
echo "👉👉👉 cmd: kubectl get pods -n ingress-nginx"
kubectl get pods -n ingress-nginx
echo "✅ ingress-nginx pods listés ci-dessus"
echo "📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌"

echo ""
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "---------- VERIFICATION FINALE"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "👉👉👉 cmd: kubectl get storageclass ==> on doit voir local path par défaut"
kubectl get storageclass
echo "👉👉👉 cmd: kubectl get pods -A  ==> on doit voir cert-manager... et ingress-nginx..."
kubectl get pods -A
