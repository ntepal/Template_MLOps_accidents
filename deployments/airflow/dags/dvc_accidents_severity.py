import os

from airflow.providers.docker.operators.docker import DockerOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from kubernetes.client import models as k8s

from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.decorators import task
#from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from docker.types import Mount
from datetime import datetime
from pathlib import Path
# Airflow tab Admin choix Variable pour donner la valeur
from airflow.models import Variable
from airflow.operators.bash import BashOperator

# Récupèrer l'UID et le GID de l'utilisateur qui fait tourner Airflow (ubuntu)
# Par défaut 1000 si jamais on est dans un environnement restreint
# Le but est de l'utiliser dans les DockerOperators qui par défaut utilise root,
# ce qui est une défaillance de sécurité
#UID = os.getuid()
#GID = os.getgid()

# Configuration du chemin
# Remonte par rapport au fichier actuel pour trouver la racine
#PROJECT_PATH = "/home/ubuntu/Template_MLOps_accidents"
# DANGER DU CHEMIN RELATIF qui n'est pas lu à partir du fichier dans Ubuntu
# mais à partir du container Sceduler, ce qui ne permet pas de trouver les
# fichiers dvc nécessaire pour les dags
# PROJECT_PATH = Path(__file__).resolve().parent.parent.parent.parent.as_posix()

NAMESPACE = "accidents-severity"

# Chemins internes au Container Docker
CONTAINER_HOME = "/app"
# CONTAINER_WORK_DIR = f"{CONTAINER_HOME}/working_dir"
CONTAINER_WORK_DIR = f"{CONTAINER_HOME}"
CONTAINER_VENV_PATH = f"{CONTAINER_HOME}/.venv"

# Chemin "interne" à Airflow (utilisé pour les commandes Bash)
# AIRFLOW_HOME est déjà défini dans le conteneur Airflow
AIRFLOW_PATH = os.getenv("AIRFLOW_HOME", "/opt/airflow")

# Récupération de la variable injectée par le docker-compose (airflow environnement)
# On met une valeur par défaut au cas où
PROJECT_NAME = os.getenv("PROJECT_NAME", "accidents_severity")
# On récupère l'url pour le docker (donc http://service_name:port)
MLFLOW_URI = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow_server:5000")
# On récupère le nom de l'expérience
MLFLOW_EXP = os.getenv("MLFLOW_EXPERIMENT_NAME", "accidents_severity")

# On reconstruit le nom du réseau airflow comme dans docker-compose.yml
#NETWORK_NAME = f"{PROJECT_NAME}_airflow-net"

# image construite dans le Makefile, qui se situe à la racine
#IMAGE_NAME = f"{PROJECT_NAME}-runner:1.0"
# Adapté pour kubernetes
IMAGE_NAME = f"docker.io/library/{PROJECT_NAME}-runner:1.0"

# Récupération de la variable (fait à chaque fois que Airflow scanne les Dag
# train_year = Variable.get("TRAIN_YEAR", default_var="2019")
# print(f"--- DAG PARSING: TRAIN_YEAR is set to {train_year} ---")

# NB: MLFLOW_EXPERIMENT_NAME
mlflow_env = {
    # Airflow, Tab Admin, Choix Variable, key à rechercher: TRAIN_YEAR
    # "TRAIN_YEAR": "{{ var.value.TRAIN_YEAR }}",
    # Ne sert à plus rien vu qu'on monte le bind sur params.yaml
    # et vu qu'on l'initialise dans le BashOperator.
    # En réalité, je ne sais pas si même avant c'était util car
    # on passait déjà via params.yaml
    # "TRAIN_YEAR": "{{ var.value.get('TRAIN_YEAR', '2019') }}",
    "MLFLOW_TRACKING_URI": MLFLOW_URI,
    "MLFLOW_EXPERIMENT_NAME": MLFLOW_EXP,
}

# Variables pour forcer l'usage du venv interne du docker
# On évite les téléchargements lors des runs d'airflow
# On garantit bien l'utilisation du docker en mode isolé
container_venv_env = {
    "VIRTUAL_ENV": CONTAINER_VENV_PATH,
    "PATH": f"{CONTAINER_VENV_PATH}/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    # Utilisé par l'interpréteur python lors de l'import
    # pour aussi chercher à partir de ce chemin
    "PYTHONPATH": CONTAINER_WORK_DIR,
    # Crucial pour que uv ne cherche pas de .venv dans working_dir
    # Evite le ghosting où parfois uv est utilisé dans l'image
    "UV_IGNORE_DOT_VENV": "1",
}

# Montage du volume pour que le container accède au code et aux données
# bind (<=> pont bidirectionnel): source et target deviennent de miroirs,
# tout update sur la source ou target se retrouve sur la target ou source
# NB: le target est /app/working_dir et non pas /app. SINON le répertoire /app
# du docker (IMAGE_NAME) serait SUBSTITUé/MASQUé par celui du target et les outils/scr
# ne seraient pas cherchés dans l'IMAGE mais dans Ubuntu, ce qui serait une erreur
# et rendrait l'utilisation de l'image INUTILE
# NB: Pont trop global: en fait, tout est fait sur ubuntu. L'image devient inutile!!!
# project_mount = Mount(source=PROJECT_PATH, target=CONTAINER_WORK_DIR, type="bind")

# Dockerfile crée son propre .venv (espace vide) grâce à 'source' à None.
# Ainsi, il ne modifie plus celui d'ubuntu evitant de générer des conflits sur ubuntu.
# Ainsi isolation complète du Docker
# ERROR: on n'utilise plus le .venv de l'image et donc téléchargement systématique
# sur internet à chaque run de Airflow et on perd donc toute l'utilité du Docker
#venv_docker = Mount(source=None, target="/app/working_dir/.venv", type="volume")

# Définition des ponts par catégories
# NB: on ne monte que les ponts utiles, on peut garder CONTAINER_WORK_DIR = /app.
# Ainsi tout ce qui n'est pas défini ci-dessous (et notemment /app/.ven) sera
# bien pris dans l'image et non pas sur le terminal local (ici ubuntu)
#def create_mount(path):
#    """Génère un bind mount entre l'hôte et le conteneur."""
#    path_target = path
#    return Mount(
#        source=f"{PROJECT_PATH}/{path}",
#        target=f"{CONTAINER_WORK_DIR}/{path}",
#        type="bind"
#    )

# Configuration chirurgicale compacte
# persistance_mounts = [create_mount(p) for p in ["data", "mlflow_artifacts",
# "reports"]]
# persistance_mounts = [create_mount(p) for p in ["data", "reports", "simu_data_web"]]
# Ajout de models utilisé par dvc pour stocker le modèle
# Pour sauvegarder sur Dagshub il faut /data/mlruns_latest et donc déjà monté via data
#persistance_mounts = (
#    [create_mount(p) for p in ["data", "reports", "simu_data_web", "models"]]
#)
#dvc_state_mounts = [create_mount(p) for p in [".dvc", "dvc.lock", "params.yaml"]]
#dvc_state_mounts = [create_mount(p) for p in [".dvc", "dvc.lock", "params.yaml"]]

# Seulement utile pour le débug. En mode produciton on peut le supprimer
# Warning: modif à librairies constantes sinon conflit
# dev_mounts = [create_mount(p) for p in ["src", "dvc.yaml", "models"]]
#dev_mounts = [create_mount(p) for p in ["src", "dvc.yaml"]]


# ---------------------------------------------------------------------
# Volumes : remplacent les bind mounts du DockerOperator.
# Un pod ne voit pas le disque de la VM => tout passe par des PVC.
# ---------------------------------------------------------------------
RUNNER_VOLUMES = [
    k8s.V1Volume(
        name="data",
        persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
            claim_name="fastapi-pvc")),
    k8s.V1Volume(
        name="artifacts",
        persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
            claim_name="mlflow-artifacts-pvc")),
    k8s.V1Volume(
        name="dvc-state",
        persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
            claim_name="dvc-state-pvc")),
    k8s.V1Volume(
        name="pipeline",
        persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
            claim_name="pipeline-data-pvc")),
]

RUNNER_VOLUME_MOUNTS = [
    k8s.V1VolumeMount(name="data",      mount_path="/app/data"),
    k8s.V1VolumeMount(name="artifacts", mount_path="/app/artifacts"),
    # État DVC partagé entre les tâches : import écrit dvc.lock, process le relit
    k8s.V1VolumeMount(name="dvc-state", mount_path="/app/.dvc",        sub_path="dvc"),
    k8s.V1VolumeMount(name="dvc-state", mount_path="/app/dvc.lock",    sub_path="dvc.lock"),
    k8s.V1VolumeMount(name="dvc-state", mount_path="/app/params.yaml", sub_path="params.yaml"),
    k8s.V1VolumeMount(name="pipeline", mount_path="/app/simu_data_web", sub_path="simu_data_web"),
    k8s.V1VolumeMount(name="pipeline", mount_path="/app/models",        sub_path="models"),
    k8s.V1VolumeMount(name="pipeline", mount_path="/app/reports",       sub_path="reports"),
]

# On remplace "mlflow_artifacts" par le volume définit dans le docker-compose.yml
# Ainsi dès que le volume est updaté par airflow, mlflow et api et train ont aussi
# cet update. Type "volume" pour indiquer à Docker que c'est lui qui gère ce volume
# en interne vu qu'il est déclaré dans le docker-compose.yml
#mlflow_volume_mount = Mount(
#    source=f"{PROJECT_NAME}_mlflow-artifacts-volume",
#    target=f"{CONTAINER_WORK_DIR}/artifacts",
#    # C'est un volume Docker
#    type="volume"
#)

# On prête ces infos pour fournir le nom utilisateur
# pour les id fournis dans dans os.getuid et os.getgid
#user_id_mount = Mount(
#    source='/etc/passwd', target='/etc/passwd', type='bind', read_only=True
#)

# NB: En vérifiant, on voit que le groupe est toujours à root mais il est important
# de le garder car en interne il sait que le groupe est bien le user
# NB: Même si Docker force souvent le GID à 'root' sur l'hôte, ce montage est CRUCIAL :
# Identité: permet au conteneur de résoudre l'ID 1000 en nom de groupe (ex: 'ubuntu')
# Stabilité: évite que les librairies (OS, MLflow) ne plantent en cherchant
# un groupe "fantôme".
# Sécurité: maintient le processus dans un environnement non-root cohérent.
#group_id_mount = Mount(
#    source='/etc/group', target='/etc/group', type='bind', read_only=True
#)

std_env = {
    **mlflow_env,
    **container_venv_env,
}

dvc_env = {
    **std_env,
    'PROJECT_NAME': PROJECT_NAME,
    'DVC_REMOTE': os.environ.get('DVC_REMOTE'),
    'DAGSHUB_USER': os.environ.get('DAGSHUB_USER'),
    'DAGSHUB_REPO_NAME': os.environ.get('DAGSHUB_REPO_NAME'),
    #'AWS_ACCESS_KEY_ID': os.environ.get('AWS_ACCESS_KEY_ID'),
    #'AWS_SECRET_ACCESS_KEY': os.environ.get('AWS_SECRET_ACCESS_KEY'),
    # DagsHub expose une API compatible S3 : boto3 (utilisé par DVC) attend
    # les noms AWS_*, alors que le secret Kubernetes les stocke sous
    # DAGSHUB_S3_*. Ce mapping était fait dans docker-compose.yml
    # (AWS_ACCESS_KEY_ID: ${DAGSHUB_S3_ACCESS_KEY_ID}) — il faut le refaire ici.
    'AWS_ACCESS_KEY_ID': os.environ.get('DAGSHUB_S3_ACCESS_KEY_ID'),
    'AWS_SECRET_ACCESS_KEY': os.environ.get('DAGSHUB_S3_SECRET_ACCESS_KEY'),
    'AWS_ENDPOINT_URL': os.environ.get('AWS_ENDPOINT_URL'),
    'MLFLOW_TRACKING_USERNAME': os.environ.get('MLFLOW_TRACKING_USERNAME'),
    'MLFLOW_TRACKING_PASSWORD': os.environ.get('MLFLOW_TRACKING_PASSWORD'),
    #'GIT_USER': os.environ.get('GIT_USER'),
    #'GIT_REPO_NAME': os.environ.get('GIT_REPO_NAME'),
    #'GIT_TOKEN': os.environ.get('GIT_TOKEN'),
    #'AIRFLOW_USER': os.environ.get('AIRFLOW_USER'),
    #'AIRFLOW_EMAIL': os.environ.get('AIRFLOW_EMAIL'),
    #'VM_USER_ID': os.environ.get('VM_USER_ID'),
    #'VM_GROUP_ID': os.environ.get('VM_GROUP_ID'),
}

def runner_task(task_id, command, env=None):
    """
    Remplace common_DockerOperator_args() : au lieu de demander un conteneur
    au daemon Docker, on demande un POD à l'API Kubernetes.
    Le pod est créé, exécute la commande, puis est supprimé.
    """
    # env_vars n'accepte que des str : on filtre les None (os.environ.get)
    # NB: logiquement pas de None mais juste au cas où!!!!
    merged = {**std_env, **(env or {})}
    env_vars = {k: str(v) for k, v in merged.items() if v is not None}

    return KubernetesPodOperator(
        task_id=task_id,
        # Nom de pod : DNS-1123 => minuscules, tirets, pas d'underscore
        name=f"runner-{task_id}".replace("_", "-").lower(),
        namespace=NAMESPACE,
        image=IMAGE_NAME,
        # Image locale dans containerd, jamais tirée du web
        image_pull_policy="Never",
        cmds=["sh", "-c"],
        arguments=[command],
        env_vars=env_vars,
        volumes=RUNNER_VOLUMES,
        volume_mounts=RUNNER_VOLUME_MOUNTS,
        # Remplace 'user': f"{UID}:{GID}" du DockerOperator
        security_context=k8s.V1PodSecurityContext(run_as_user=1000, fs_group=1000),
        # Airflow tourne DANS le cluster : pas de kubeconfig externe
        in_cluster=True,
        # Equivalent de auto_remove='force'
        is_delete_operator_pod=True,
        # Remonte les logs du pod dans l'UI Airflow
        get_logs=True,
        startup_timeout_seconds=300,
    )

# =====================================================================
# ANCIENNE VERSION DOCKER COMPOSE (DockerOperator) — CONSERVÉE POUR MÉMOIRE
# Incompatible Kubernetes : parle au daemon Docker via /var/run/docker.sock,
# utilise des bind mounts depuis la VM et un réseau Docker nommé.
# Remplacée par runner_task() ci-dessous (KubernetesPodOperator).
# =====================================================================
#def common_DockerOperator_args(env):
#    """Génère les arguments communs en permettant de surcharger l'image."""
#    return {
#        'image': IMAGE_NAME,
#        'network_mode': NETWORK_NAME,
#        'environment': env,
#        # On garantit que les DockerOperator utiliseront le usr user et non pas root qui
#        # est le user par défaut et ainsi éviter tout conflit et défaillance de sécurité
#        'user': f"{UID}:{GID}",
#        # mounts ne supporte que le format liste: on concatène les listes
#        'mounts': (
#            persistance_mounts +
#            dvc_state_mounts +
#            dev_mounts +
#            [mlflow_volume_mount, user_id_mount, group_id_mount]
#        ),
#        # Equivalent à faire cd /app/working_dir
#        'working_dir': CONTAINER_WORK_DIR,
#        # Une fois terminée, la tâche s'auto-détruit
#        # Version récente de DockerOperator force <=> True
#        'auto_remove': 'force',
#        # Permet à Airflow (dans Docker) de parler au Docker de la machine
#        # Ubuntu pour lancer les containers de tâches.
#        'docker_url': "unix://var/run/docker.sock",
#        # Ne pas demander à Ubuntu de monter quoi que ce soit d'automatique
#        # dans /tmp. Ce n'est pas la peine car Airflow fournit déjà tout ce
#        # qu'il faut via project_mount
#        'mount_tmp_dir': False,
#        # On force l'utilisation de l'image locale (déjà généré en interne)
#        # Pour être sûr qu'il n'essaiera pas de chercher l'image sur le web
#        "force_pull": False,
#    }

with DAG(
    dag_id="dvc_accidents_severity",
    # Arguments appliqués automatiquement à chaque DockerOperator
    # Donc inutile de le remettre pour chaque DockerOperator
    # Simplifie le DockerOperator
    # default_args=common_DockerOperator_args,
    start_date=datetime(2019, 1, 1),
    # end_date=datetime(2019, 12, 31), # retiré pour accepter données plus récentes
    # Entrainement périodique mensuelle ou annuelle
    # schedule_interval='@monthly', # schedule_interval='@yearly',
    # catchup=True, # exécute ce qui est dans data/raw
    # Pour la simulation, on lance un run toutes les 2mn
    schedule_interval="*/2 * * * *",
    # Pour ne par lancer milliers de run pour rattraper l'année
    catchup=False,
    # Pas plus d'un run à la fois pour éviter les risques de conflits/saturation
    # Ainsi le dag n'est jamais lancé plusieurs fois en parallèle
    max_active_runs=1,
    tags=["1-SIMULATION", "2-DVC", "3-Freq=2min"],
) as dag:

    dag.doc_md = """
    ### 🚀 Mode Simulation - data/raw updaté manuellement
    **Fréquence :** Toutes les 2 minutes.
    **Objectif :** Tester la détection de nouvelles données par DVC et l'envoi vers MLflow.
    """

    # 1. Préparation/Init de la table de suivi en BDD
    # PostgresOperator remplacé par SQLExecuteQueryOperator
    init_db = SQLExecuteQueryOperator(
        task_id="runs_history_table",
        #postgres_conn_id="postgres_default",
        conn_id="postgres_default",
        sql="CREATE TABLE IF NOT EXISTS runs (id SERIAL, date TIMESTAMP, status TEXT);"
    )

    # Etape de préparation pour partager la variable avec tous les dockers
    # On prend le TRAIN_YEAR défini dans Airflow/Admin, on le place dans
    # le fichier params.yaml en l'écrasant systématiquement
    # le bind avec params.yaml est monté pour les Dockers.
    # Ainsi, pour chaque Docker qui fait dvc ..., le dvc.yaml est lu et
    # DVC sait qu'il doit chercher le params.yaml pour obtenir la valeur
    # de TRAIN_YEAR
#    prepare_params = BashOperator(
#        task_id='prepare_params_file',
#        bash_command=(
#            # Ici quand on clique sur le bouton = flèche pour Trigger DAG
#            #f'echo "TRAIN_YEAR: {{{{ dag_run.conf.get("year", 2019) }}}}"'
#            # Ici, on passe par la variable dans Admin/Variable
#            # Le premier echo est pour l'affichage dans les logs
#            f'echo "--- PREPARE PARAMS: Setting TRAIN_YEAR to '
#            f'{{{{ var.value.get("TRAIN_YEAR", "2019") }}}} ---" && '
#            f'echo "TRAIN_YEAR: {{{{ var.value.get("TRAIN_YEAR", "2019") }}}}" '
#            f'> {AIRFLOW_PATH}/params.yaml'
#        )
#    )

    prepare_params = runner_task(
        "prepare_params_file",
        'echo "--- PREPARE PARAMS: TRAIN_YEAR={{ var.value.get(\'TRAIN_YEAR\', \'2019\') }} ---" && '
        'echo "TRAIN_YEAR: {{ var.value.get(\'TRAIN_YEAR\', \'2019\') }}" > /app/params.yaml && '
        'cat /app/params.yaml',
    )
    # 2. Pipeline Machine Learning (Containers)
    with TaskGroup("ml_pipeline") as ml_pipeline:
        # Groupe DATA PREPARATION (Import + Process)
        with TaskGroup("data_preparation") as data_prep:
            import_data  = runner_task("dvc_import",  "dvc repro import")
            #import_data = DockerOperator(
            #    task_id="dvc_import",
            #    **common_DockerOperator_args(std_env),
            #    command="dvc repro import",
            #)

            process_data = runner_task("dvc_process", "dvc repro process")
            #process_data = DockerOperator(
            #    task_id="dvc_process",
            #    **common_DockerOperator_args(std_env),
            #    command="dvc repro process",
            #)

            import_data >> process_data

        # Groupe MODEL TRAINING (Train + Evaluate)
        with TaskGroup("model_train_and_eval") as model_workflow:
            train_model = runner_task("dvc_train", "dvc repro train")
            #train_model = DockerOperator(
            #    task_id="dvc_train",
            #    **common_DockerOperator_args(std_env),
            #    command="dvc repro train",
            #)

            # Dans ton TaskGroup ml_pipeline
            evaluate_model = runner_task("dvc_evaluate", "dvc repro evaluate")
            #evaluate_model = DockerOperator(
            #    task_id="dvc_evaluate",
            #    **common_DockerOperator_args(std_env),
            #    command="dvc repro evaluate",
            #)

            train_model >> evaluate_model

        with TaskGroup("dvc_tracking_and_push") as dvc_tracking:
            dvc_hash_task = runner_task("dvc_hash", "dvc repro dvc_hash")
            #dvc_hash_task = DockerOperator(
            #    task_id="dvc_hash",
            #    # On importe tous les paramètres communs
            #    **common_DockerOperator_args(std_env),
            #    command="dvc repro dvc_hash",
            #)
            # dvc add inutile car fait par défaut avec dvc repro
            # grâce au dvc.yaml
            dvc_push_task = runner_task("dvc_push", "dvc push", dvc_env)
            #dvc_push_task = DockerOperator(
            #    task_id="dvc_push",
            #    # On importe tous les paramètres communs
            #    **common_DockerOperator_args(dvc_env),
            #    command="dvc push",
            #)
            dagshub_upd_version = runner_task(
                "dagshub_upd_version",
                "python3 /app/src/mlflow/dagshub_upd_version.py",
                dvc_env
            )
            #dagshub_upd_version = DockerOperator(
            #    task_id="dagshub_upd_version",
            #    # On importe tous les paramètres communs
            #    **common_DockerOperator_args(dvc_env),
            #   command='python3 /app/src/mlflow/dagshub_upd_version.py',
            #)

            dvc_hash_task >> dvc_push_task >> dagshub_upd_version

        # Chaînage
        data_prep >> model_workflow >> dvc_tracking

    # 3. Enregistrement du succès dans Postgres
    # PostgresOperator remplacé par SQLExecuteQueryOperator
    record_success = SQLExecuteQueryOperator(
        task_id="runs_history_record",
        # postgres_conn_id="postgres_default",
        conn_id="postgres_default",
        sql="INSERT INTO runs (date, status) VALUES (NOW(), 'SUCCESS');"
    )

    init_db >> prepare_params >> ml_pipeline >> record_success
