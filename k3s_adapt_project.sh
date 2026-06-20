#!/bin/bash

# Arrêter le script si une commande échoue
set -e

echo "--- Adapater le projet sur k3s ---"

echo ""
echo "///////////////////////////////////////////////"
echo "Vérification de la présence de Traefik "
echo "///////////////////////////////////////////////"
echo ""
echo "👉👉👉 cmd: kubectl get pods -A  ==> on doit voir traefik-xxxxxxxxxx-xxxxx"
kubectl get pods -A

echo "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"
echo "---------- IMPERATIF: A FAIRE UNIQUEMENT SI LA VM A ETE REINITIALISEE"
echo " --------- Toutes les commandes de réinit en commentaire car ça ne marche pas parfaitement"
echo "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"

#echo "📌 Delete namespace Longhorn"
#kubectl delete ns longhorn-system --ignore-not-found --wait=false

#echo "📌 Delete namespace cert-manager"
#kubectl delete ns cert-manager --ignore-not-found --wait=false

#echo "📌 Delete Longhorn CRDs"
#kubectl get crd | grep longhorn | awk '{print $1}' | xargs -r kubectl delete crd

#echo "📌 Delete cert-manager CRDs"
#kubectl get crd | grep cert-manager | awk '{print $1}' | xargs -r kubectl delete crd

#echo "📌 Delete StorageClass"
#kubectl delete storageclass longhorn --ignore-not-found

#echo "📌📌📌 Helm uninstall"
#helm uninstall longhorn -n longhorn-system || true
#helm uninstall cert-manager -n cert-manager || true

#echo "📌📌📌 Delete namespaces"
#kubectl delete ns longhorn-system --ignore-not-found --wait
#kubectl delete ns cert-manager --ignore-not-found --wait

#echo "📌📌📌 Delete CRDs (cleanup full reset)"
#kubectl get crd | grep longhorn | awk '{print $1}' | xargs -r kubectl delete crd
#kubectl get crd | grep cert-manager | awk '{print $1}' | xargs -r kubectl delete crd

#echo "📌📌📌 Delete StorageClass"
#kubectl delete storageclass longhorn --ignore-not-found

#echo "📌📌📌 FINAL CHECK"
#kubectl get pods -A | grep -E "longhorn|cert-manager" || true
#kubectl get crd | grep -E "longhorn|cert-manager" || true
echo "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"

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
echo "👉👉👉 cmd: helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true"
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true
# Vérification
echo "👉👉👉 cmd: kubectl get pods -n cert-manager  ==> on doit voir cert-manager, cert-manager-cainjector et cert-manager-webhook dans l'état running"
kubectl get pods -n cert-manager
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

echo ""
echo "///////////////////////////////////////////////////////////////////////////////////////////"
echo "---------- INSTALLATION Longhorn"
echo "///////////////////////////////////////////////////////////////////////////////////////////"

echo ""
echo "*******************************************************************************************"
echo " >>>>>>>>> Prérequis: ISCSI "
echo "*******************************************************************************************"
echo "👉👉👉 cmd: sudo apt update"
sudo apt update
echo "👉👉👉 cmd: sudo apt install -y open-iscsi"
sudo apt install -y open-iscsi
echo "👉👉👉 cmd: sudo systemctl enable iscsid"
sudo systemctl enable iscsid
echo "👉👉👉 cmd: sudo systemctl start iscsid"
sudo systemctl start iscsid
echo "👉👉👉 cmd: systemctl status iscsid --no-pager"
systemctl status iscsid --no-pager
echo "👉👉👉 cmd: kubectl get nodes -o wide ==> Pour confirmation"
echo "📌📌📌 On doit voir NAME STATUS ROLES : ip-xxx-yy... Ready control-plane,master"
kubectl get nodes -o wide
echo "******************************************************************************************"

echo ""
echo "##########################################################################################"
echo " >>>>>>>>>> INSTALLATION LONGHORN"
echo "##########################################################################################"
# Version stable actuelle via Helm
echo "👉👉👉 cmd: helm repo add longhorn https://charts.longhorn.io"
helm repo add longhorn https://charts.longhorn.io
echo "👉👉👉 cmd: helm repo update"
helm repo update
# Créer le namespace
echo "👉👉👉 cmd: kubectl get namespace longhorn-system >/dev/null 2>&1 || kubectl create namespace longhorn-system"
kubectl get namespace longhorn-system >/dev/null 2>&1 || kubectl create namespace longhorn-system
# Installer
echo "👉👉👉 cmd: helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace"
helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
# Attendre quelques minutes :
echo ""
echo "📌📌📌 On attend que le Longhorn deployments soit effectif. Cela peut prendre qques minutes..."
# Logs live (on peut ainsi suivre l'évolution sur un autre terminal)
mkdir -p logs
echo "📌📌📌 Les traces du longhorn-system vérifiable en live sur un autre terminal à la racine dans logs/longhorn.log"
echo "👉👉👉 cmd: kubectl get pods -n longhorn-system -w > logs/longhorn.log 2>&1 &    ==> lancé en tache de fond et donc penser à le tuer après"
kubectl get pods -n longhorn-system -w > logs/longhorn.log 2>&1 &
LOG_WATCH_PID=$!
echo "📌📌📌 Le PID des logs en background est: PID=$LOG_WATCH_PID"
echo ""
echo "📌📌📌 On attend que les déploiements Longhorn soient effectués..."
echo "👉👉👉 cmd: kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer --timeout=600s"
kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer --timeout=600s
echo "✅ longhorn-driver-deployer fully ready"
echo "👉👉👉 cmd: kubectl -n longhorn-system rollout status deploy/longhorn-ui --timeout=600s"
kubectl -n longhorn-system rollout status deploy/longhorn-ui --timeout=600s
echo "✅ longhorn-ui fully ready"
echo ""
echo "📌📌📌 On attend que les pods Longhorn soient ready..."
echo "👉👉👉 cmd: kubectl wait --for=condition=ready pod -n longhorn-system --all --timeout=900s"
kubectl wait --for=condition=ready pod -n longhorn-system --all --timeout=900s
echo "📌📌📌 On check les DaemonSets..."
kubectl get daemonset -n longhorn-system
# On stoppe les log watcher
echo "👉👉👉 cmd: kill $LOG_WATCH_PID 2>/dev/null || true  ==> pour tuer le PID logs lancé en tache de fond"
kill $LOG_WATCH_PID 2>/dev/null || true
echo "✅ Longhorn fully ready"
echo ""
echo "👉👉👉 cmd: kubectl get pods -n longhorn-system  ==> tous les pods doivent être running"
kubectl get pods -n longhorn-system
# Exposer l'interface Longhorn et Pour un premier test :
echo "📌📌📌 Exposer l'interface Longhorn"
echo "👉👉👉 cmd: kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80"
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
echo "📌📌📌 VERIFIER MANUELLEMENT L'INTERFACE VIA http://localhost:8080"
echo ""
echo "📌📌📌 Définir Longhorn comme StorageClass par défaut"
echo "👉👉👉 cmd: kubectl get storageclass  ==> on devrait voir local-path et longhorn"
kubectl get storageclass
echo "📌📌📌 Faire de Longhorn le StorageClass par défaut"
echo "👉👉👉 cmd: kubectl patch storageclass longhorn -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
kubectl patch storageclass longhorn -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo "📌📌📌 Retirer le status par défaut de local-path"
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
echo "👉👉👉 cmd: kubectl get storageclass  ==> on devrait voir longhorn (default)"
kubectl get storageclass
echo "##########################################################################################"
echo "///////////////////////////////////////////////////////////////////////////////////////////"

echo ""
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "---------- VERIFICATION FINALE"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "👉👉👉 cmd: kubectl get storageclass ==> on doit voir longhorn (default)"
kubectl get storageclass
echo "👉👉👉 cmd: kubectl get pods -A  ==> on doit voir kube-system traefik... longhorn-system longhorn... cert-manager cert-manager-..."
kubectl get pods -A
