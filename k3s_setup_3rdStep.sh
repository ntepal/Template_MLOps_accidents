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

echo ""
echo "///////////////////////////////////////////////////////////////////////////////////////////"
echo "--------------------- INSTALLATION LONGHORN UTILE POUR LES PVC ----------------------------"
echo "///////////////////////////////////////////////////////////////////////////////////////////"

echo ""
echo "*******************************************************************************************"
echo " >>>>>>>>> Prérequis: ISCSI "
echo "*******************************************************************************************"
echo "📌📌📌 A FAIRE APRES VM INITIALIZATION SINON çA BOUCLE AVEC ld not get lock /var/lib/dpkg/lock-frontend. It is held by process 21650 (unattended-upgr) "
echo " ET IL N'EST PAS CONSEILLé DE TUER LE PROCESS SOUS PEINE DE CORROMPRE LE SYSTEME"
# APT = Advanced Package Tool; système qui installe et met à jour les logiciels sur ta VM
# ex: sudo apt update, apt install open-iscsi

echo ""
echo "👉👉👉 cmd: sudo apt update > logs/apt-update.log 2>&1"
echo "📌📌📌 Log à partir de la racine dans logs/apt-update.log"
# sudo apt update
sudo apt update > logs/apt-update.log 2>&1
echo "✅ APT UPDATE DONE"
echo ""
echo "👉👉👉 cmd: sudo apt-get install -y nfs-common"
echo "📌📌📌 Installer client NFS sur la VM pour que le noyau Linux comprenne la commande mount -t nfs que Kubernetes exécute."
sudo apt-get install -y nfs-common > logs/nfs-common.log 2>&1
echo "✅ Install NFS-COMMON DONE"
echo ""
echo "👉👉👉 cmd: sudo apt install -y open-iscsi > logs/open-iscsi.log 2>&1"
# sudo apt install -y open-iscsi
sudo apt install -y open-iscsi > logs/open-iscsi.log 2>&1
echo "✅ Install OPEN-ISCSI DONE"
echo "👉👉👉 cmd: sudo systemctl enable iscsid > logs/enable-iscsi.log 2>&1"
# sudo systemctl enable iscsid
sudo systemctl enable iscsid > logs/enable-iscsi.log 2>&1
echo "✅ ISCSI ENABLED"
echo "👉👉👉 cmd: sudo systemctl start iscsid"
sudo systemctl start iscsid
echo "👉👉👉 cmd: systemctl status iscsid --no-pager > logs/status-iscsi.log 2>&1"
# systemctl status iscsid --no-pager
systemctl status iscsid --no-pager > logs/status-iscsi.log 2>&1
echo "👉👉👉 cmd: kubectl get nodes -o wide 2>&1 | tee logs/status_nodes.log ==> Pour confirmation"
echo "📌📌📌 On doit voir NAME STATUS ROLES : ip-xxx-yy... Ready control-plane,master"
# kubectl get nodes -o wide
# Affichage sur l'écran et dans le fichier
kubectl get nodes -o wide 2>&1 | tee logs/status_nodes.log
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
echo "👉👉👉 cmd: helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --wait --timeout 15m > logs/longhorn_namespace.log 2>&1"
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --wait \
  --timeout 15m \
  > logs/longhorn_namespace.log 2>&1
echo "✅ longhorn namespace created with success"
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
echo ""
echo "📌📌📌 Vérification des settings Longhorn..."
echo "👉👉👉 cmd: kubectl -n longhorn-system get settings.longhorn.io >/dev/null"
kubectl -n longhorn-system get settings.longhorn.io >/dev/null
echo ""
echo "📌📌📌 On check les DaemonSets..."
kubectl get daemonset -n longhorn-system
# On stoppe les log watcher
echo "👉👉👉 cmd: kill $LOG_WATCH_PID 2>/dev/null || true  ==> pour tuer le PID logs lancé en tache de fond"
kill $LOG_WATCH_PID 2>/dev/null || true
echo "✅ Longhorn fully ready"
echo ""
echo "👉👉👉 cmd: kubectl get pods -n longhorn-system  ==> tous les pods doivent être running"
kubectl get pods -n longhorn-system
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
echo "📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌"
echo "---------- IMPORTANT VM=24GO DONC REDUIRE AU MAX LA CONSO LONGHORN / REPLICA... -----------"
echo "📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌"
echo ""
echo "🟢 CONFIGURATION LONGHORN OPTIMISÉE (VM 24GB)"
echo "👉 Réduction replicas : 3 → 1"
kubectl -n longhorn-system patch settings.longhorn.io default-replica-count \
  --type merge \
  -p '{"value":"1"}'
echo "✅ Longhorn replica count set to 1"

echo ""
echo "👉 Limiter l’over-provisioning (TRÈS IMPORTANT)"
kubectl -n longhorn-system patch settings.longhorn.io storage-over-provisioning-percentage \
  --type merge \
  -p '{"value":"100"}'

echo ""
echo "👉 Réduire déchets snapshots (optionnel mais utile)"
kubectl -n longhorn-system patch settings.longhorn.io snapshot-max-count \
  --type merge \
  -p '{"value":"5"}'

echo ""
VOLUMES=$(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}')
if [ -n "$VOLUMES" ]; then
  echo "👉 Réduction des replicas des volumes existants"
  for v in $VOLUMES; do
    echo "➡️ Patch volume $v"
    kubectl -n longhorn-system patch volumes.longhorn.io "$v" \
      --type merge \
      -p '{"spec":{"numberOfReplicas":1}}' || true
  done
else
  echo "👉 Aucun volume Longhorn existant à modifier."
fi

echo ""
echo "👉 Réduire le nombre de replicas de l'interface Longhorn (VM légère)"
kubectl -n longhorn-system scale deployment longhorn-ui --replicas=1
echo "👉 Attente de la fin du rollout..."
kubectl -n longhorn-system rollout status deploy/longhorn-ui --timeout=300s
echo "👉 Vérification du nombre de replicas qui doit être 1"
kubectl -n longhorn-system get deployment longhorn-ui
echo ""
echo "👉 Attente stabilisation complète Longhorn..."
while true; do
  NOT_READY=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | \
    grep -E "ContainerCreating|Pending|Terminating|Init:|CrashLoopBackOff" || true)
  if [ -z "$NOT_READY" ]; then
    break
  fi
  sleep 2
done
echo "👉 Tous les pods sont dans un état stable (phase 1)"
echo "👉 Vérification Ready condition..."
kubectl wait  --for=condition=Ready pod  -n longhorn-system  --all  --timeout=600s  >/dev/null 2>&1
echo "👉 Vérification finale des pods..."
kubectl get pods -n longhorn-system
echo "✅ Longhorn complètement initialisé"

echo "📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌📌"

echo ""
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "---------- VERIFICATION FINALE"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
echo "👉👉👉 cmd: kubectl get storageclass ==> on doit voir longhorn (default)"
kubectl get storageclass
echo "👉👉👉 cmd: kubectl get pods -A  ==> on doit voir kube-system traefik... longhorn-system longhorn... cert-manager cert-manager-..."
kubectl get pods -A
echo ""
# Exposer l'interface Longhorn et Pour un premier test :
echo "📌📌📌 Pour un 1er test, exposer l'interface Longhorn en lançant manuellemenet la commande"
echo "👉👉👉 cmd: kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80"
# kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
echo "📌📌📌 VERIFIER MANUELLEMENT L'INTERFACE VIA http://localhost:8080 ou http://@IP_VM:8080"
