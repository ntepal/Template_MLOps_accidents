#################################################################################################################
# Localisation : Dockerfile est dans src/mlflow et le fichier d'exclusion .dockerignore est à la racine
#                .dockerignore très utile (gain de temps car évite de charger des fichiers qui ne seront de toute façon pas utilisés
# Initialisation = commande "docker compose build" à la racine:
#   - Lecture du docker-compose.yml pour identifier le contexte (context: .) et le fichier de build.
#   - Filtrage immédiat à lecture de .dockerignore pour exclure tout ce qui y est listé du répertoire réel.
#   - Création temporaire d'une arborescence virtuelle (le contexte) contenant uniquement les fichiers autorisés.
#   - Exécution du Dockerfile en utilisant uniquement cette référence virtuelle.
#     Si un fichier a été ignoré, il est "invisible" pour les commandes COPY ou ADD.
#################################################################################################################

# IMPORTANT
# TOUTE ECRITURE SUR LE DISQUE GENERE UNE COUCHE : RUN, COPY, ADD.
# (FROM n'en crée pas, il hérite de celles de l'image de base. ENV, CMD, EXPOSE, WORKDIR, USER non plus : ils ne changent que la config.)
#
# UNE COUCHE EST IMMUABLE. MODIFIER UN FICHIER D'UNE COUCHE INFERIEURE (MEME JUSTE SON PROPRIETAIRE OU SES PERMISSIONS)
# FORCE OVERLAYFS A LE RECOPIER ENTIEREMENT DANS LA NOUVELLE COUCHE = "COPY-UP".
#
# => UN "RUN chown -R" APRES COUP SUR /app RECOPIE TOUT LE .venv (~900 Mo).  L'IMAGE CONTIENT ALORS LE .venv 2 FOIS : 1,1 Go -> 1,98 Go.
#
# REGLE : CREER LES FICHIERS DIRECTEMENT AVEC LE BON PROPRIETAIRE
#   - useradd + chown SUR UN /app ENCORE VIDE (coût ~0)
#   - USER 1000 AVANT le "uv sync"
#   - COPY --chown=1000:1000 au lieu de COPY puis RUN chown
#
# MEME LOGIQUE POUR LES SUPPRESSIONS : "RUN rm -rf /cache" DANS UNE COUCHE POSTERIEURE NE LIBERE RIEN (il ajoute juste un marqueur "whiteout").
# IL FAUT SUPPRIMER DANS LE MEME "RUN" QUE LA CREATION.


# Utilisation d'une image légère
# Commande docker run --rm python:3.12-slim sh -c "python --version && cat /etc/os-release | grep VERSION_CODENAME"
# Pour avoir la version complète utilisé ici (language-empreinte-OS)
# FROM python:3.12-slim
# NB : python:slim ne définit pas de USER => on est root implicitement ici.
#      Si on change de FROM pour une image non-privilégiée, ajouter USER root.
# Pour vérifier on récupère l'image docker pull python:3.12.13-slim-trixie
# puis on verifie avecdocker run --rm python:3.12.13-slim-trixie id (la on voit uid / guid / groups) ==> on a bien root / root / root
# et enfin on supprime avec docker rmi python:3.12.13-slim-trixie
FROM python:3.12.13-slim-trixie

# ─── zone root : socle système ────────────────────
# Installation de uv. On fige la version (validée sur Ubuntu) pour garantir l'immuabilité du build.
# Le binaire /uv de l'image officielle est copié dans /bin/uv du conteneur. 
COPY --from=ghcr.io/astral-sh/uv:0.11.3 /uv /bin/uv

# --- Création de l'utilisateur AVANT toute écriture -------------------------
# L'image python:slim n'a pas d'utilisateur UID 1000 : on le crée.
RUN useradd --uid 1000 --create-home --shell /bin/bash appuser

# Création du répertoire de travail
WORKDIR /app

# /app EST ENCORE VIDE : ce chown ne copie qu'un répertoire, coût ~0.
RUN mkdir -p /app/data && chown -R 1000:1000 /app


# --- À partir d'ici, tout est écrit directement en 1000:1000 ---------------
USER 1000

# Copier les fichiers de dépendances dans le répertoire courant (= de travail)
#COPY pyproject.toml uv.lock /app/
COPY --chown=1000:1000 pyproject.toml uv.lock /app/

# Installer les dépendances 
# --frozen : utiliser le .lock en READ ONLY
# --no-cache : ne pas sauvegarder dans le cache car inutile (et image plus lourde)
# --no-install-project : NE PAS exiger la présence immédiate du dossier src/ (faite dans le COPY . .)
#                        Ainsi, on s'assure de ne pas recommencer la réinstallation complète des 
#                        librairies (couteux en temps) à chaque modification d'une ligne dans scr
RUN uv sync --frozen --no-cache --no-install-project

# Copier TOUS, SAUF ce qui est indiqué dans le .dockerignore (filtre) vers /app/..
#COPY src/mlflow /app/src/mlflow
COPY --chown=1000:1000 src /app/src/mlflow

# ON DOIT REVENIR EN ROOT POUR RÉPARER LES DROITS
#USER root
# 1. Nettoyage définitif des artefacts DVC
#RUN rm -rf /app/.dvc /app/dvc.yaml /app/dvc.lock
# 2. Création du répertoire des artefacts s'il n'existe pas (bonne pratiques)
#RUN mkdir -p /app/artifacts
# 3. Fixation des droits (on s'assure que le user 1000 est propriétaire)
# NB / WARNING: comme le COPY pyproject.toml uv.lock /app/ suivi du RUN uv sync --frozen --no-cache --no-install-project
# avait été fait auparavant, alors la commande ci-dessous rajoute une couche (duplique l'image) pour affacter les droits et c'est l'erreur
#RUN chown -R 1000:1000 /app
# 4. On reivent à l'utilisateur sécurisé
#USER 1000

# Ajouter le chemin de l'environnement virtuel créé par uv au PATH
ENV PATH="/app/.venv/bin:$PATH"

# Exposition du port
EXPOSE 5000

# Si DATABASE_URL n'est pas fournie au lancement dans le .en, alors lien par défaut
ENV DATABASE_URL=postgresql://airflow:airflow@postgres:5432/airflow
# Commande pour lancer le mlflow, avec les options de base de données et d'artefacts
# "--backend-store-uri", "sqlite:////app/mlflow_db/mlflow.db": MLflow prend toutes les infos
# (accuracy, hyperparamètres, ID du run, durée) et les insère comme des lignes dans
# des tables SQL à l'intérieur du fichier mlflow.db
# NB: syntaxe JSON avec appel au Shell ("sh") indispensable pour interpréter les variables
# NB: allowed-hosts et --cors-allowed-origins indispensables pour MLFLOW 3.x suite 
# au passage en version Python 3.12 (MLFLOW 2.x en Python 3.8)
# Ces champs sont signalés via docker logs -f mlflow_server qui tourne sur une fenêtre
# quand on fait make docker-train sur une autre fenêtre
# --default-artifact-root /app/artifacts pour indiquer que /app/artifacts est la racine
# et donc tout ce qui est créé sera à partir de la racine (donc dans /app/artifacts)
CMD ["sh", "-c", "mlflow server \
     --host 0.0.0.0 \
     --port 5000 \
     --backend-store-uri ${DATABASE_URL} \
     --default-artifact-root /app/artifacts \
     --allowed-hosts '*' \
     --cors-allowed-origins '*'"]
