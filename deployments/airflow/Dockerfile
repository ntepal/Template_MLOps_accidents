#################################################################################################################
# Localisation : Dockerfile est dans deployments/airflow
#                et le fichier d'exclusion .dockerignore est à la racine.
# Initialisation = commande "docker compose build" à la racine:
#   - Lecture du docker-compose.yml pour identifier le contexte (context: .) et le fichier de build.
#   - Filtrage immédiat à lecture de .dockerignore pour exclure tout ce qui y est listé du répertoire réel.
#   - Création temporaire d'une arborescence virtuelle (le contexte) contenant uniquement les fichiers autorisés.
#   - Exécution du Dockerfile en utilisant uniquement cette référence virtuelle.
#     Si un fichier a été ignoré, il est "invisible" pour les commandes COPY ou ADD.
#################################################################################################################

# Image Airflow officielle la plus récente et stable et compatible avec l'environnement python 3.12
#FROM apache/airflow:2.8.1
FROM apache/airflow:2.10.5-python3.12

# Installation de uv
COPY --from=ghcr.io/astral-sh/uv:0.11.3 /uv /bin/uv

# On passe en root pour préparer les dossiers si nécessaire
USER root

# Ajout de /app au chemin de recherche Python pour les imports de 'src'
# On prend le ${PYTHONPATH} déjà défini dans l'image auquel on rajoute /app
# D'après le commentaire dit « car les dags peuvent faire appels aux codes sources »
# — mais ton DAG n'importe rien de src/. Après réécriture en KubernetesPodOperator, ce sera encore plus vrai.
# Supprime-le, ainsi que le PYTHONPATH qui l'accompagne.
# Tu élimines du même coup le risque de désynchronisation entre le DAG (git-sync) et src/ (image).
#ENV PYTHONPATH="${PYTHONPATH}:/app"

# Définir AIRFLOW_HOME AVANT de créer le dossier et de changer les droits
#ENV AIRFLOW_HOME=/app
ENV AIRFLOW_HOME=/opt/airflow

# NB: airflow est le nom user et aussi le nom groupe définis par défaut dans l'image
# NB: Dans le docker-compose, on définit le user/groupe a utiliser et qui écrasera
# ce user/groupe défini par dans cette image
# airflow a besoin des droits user:groupe pour écrire dans /app
# chown airflow:0 : droits user:groupe donnés à /app; le groupe 0 est root
#RUN mkdir -p /app && chown airflow:0 /app && chmod -R 775 /app
# Comme pour aiflow, le répertoire de l'image est par défaut /opt/airflow, on s'aligne dessus
RUN mkdir -p /opt/airflow/logs \
    && chown -R airflow:0 /opt/airflow \
    && chmod -R 775 /opt/airflow

# On définit le répertoire de travail, code applicatif et .venv, lecture seule au runtime
WORKDIR /app

# Fait sous user root pour le uv pip install
# Copie des fichiers de dépendances avec les droits user et groupe airflowvers
COPY --chown=airflow:0 pyproject.toml uv.lock /app/
# Copie de src car les dags peuvent faire appels aux codes sources
# D'après le commentaire dit « car les dags peuvent faire appels aux codes sources » 
# — mais le DAG n'importe rien de src/. Après réécriture en KubernetesPodOperator, ce sera encore plus vrai.
# Le Supprimer ainsi que le PYTHONPATH qui l'accompagne.
# ça élimine du même coup le risque de désynchronisation entre le DAG (git-sync) et src/ (image).
#COPY --chown=airflow:airflow src /app/src/
# Pour rester cohérent avec le COPY précédent au cas où je l'utilise finalement
#COPY --chown=airflow:0 src /app/src/

# Environnement Airflow existe déjà dans l'image officielle
# On AJOUTE les dépendances du projet via pip install
# Pour garantir la reproductibilité, on se base sur uv.lock (et non pas requirements.txt)
# qui contient les versions exactes
# --system : installe dans le Python de l'image (en USER root)
# --no-cache: la copie dans l'archive est supprimée car inutile et alourdit l'image
# --frozen: on prend le contenu de uv.lock sans rien modifier
# Le uv.lock est transformé en uv_lock_format_pour_pip.txt qui est au même format que requirements.txt
# Trois RUN = trois couches, et le rm ne libère rien : il pose un whiteout qui masque le fichier,
# mais celui-ci reste stocké dans la couche 1. Exactement le mécanisme qu'on a vu sur le chown.
#RUN uv export --frozen --output-file uv_lock_format_pour_pip.txt
#RUN uv pip install --no-cache --system -r uv_lock_format_pour_pip.txt
#RUN rm uv_lock_format_pour_pip.txt
RUN uv export --frozen --output-file /tmp/requirements.txt \
    && uv pip install --no-cache --system -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt
# On repasse en utilisateur airflow (pour écrire dans les sous-répertoires de airflow)
# Définit l'utilisateur par défaut du conteneur au runtime.
# Sans lui, le pod Airflow tournerait en root : un processus compromis (via un DAG malveillant,
# une dépendance vérolée) aurait les pleins pouvoirs dans le conteneur.
# Kubernetes peut le surcharger. Si un securityContext.runAsUser est défini dans le deployment, il gagne sur le USER du Dockerfile.
USER airflow

# Copie des DAGs vers le chemin standard d'Airflow
# Fait en mode user airflow car spécifique à Airflow
# Devient inutile car c'est défini dans le git-sync de chaque deployment.
# L'avantatge de l'avoir dans le git-sync est que chaque modif du dag est pris en compte
# sans avoir besoin de regénérer l'image si j'avais garé le copy
#COPY --chown=airflow:airflow deployments/airflow/dags /opt/airflow/dags

# Pas de CMD ! On laisse l'image Airflow utiliser son propre entrypoint pour lancer 
# le webserver ou le scheduler selon le service Docker Compose.
