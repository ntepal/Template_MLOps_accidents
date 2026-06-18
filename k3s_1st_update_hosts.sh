#!/bin/bash

# --- SECTION 1 : Auto-installation ----
# Copie intégrale de du fichier lui-meme k3s_1st_updade_host.sh dans /usr/local/bin/update-host.sh
DEST="/usr/local/bin/update-hosts.sh"
# On vérifie si on est déjà au bon endroit pour éviter de tourner en boucle
# $0 est le fichier lui-meme
if [ "$(realpath "$0")" != "$(realpath "$DEST")" ]; then
    echo "Installation du script vers $DEST..."
    sudo cp "$(realpath "$0")" "$DEST"
    sudo chmod +x "$DEST"
    echo "Installation terminée."
fi

# --- SECTION 2 : Logique métier (Ce que le script doit faire) ---
CURRENT_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
# Supprime l'ancienne entrée si elle existe et ajoute la nouvelle
sudo sed -i "/$HOSTNAME/d" /etc/hosts
echo "$CURRENT_IP $HOSTNAME" | sudo tee -a /etc/hosts
