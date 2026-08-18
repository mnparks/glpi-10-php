#!/usr/bin/env bash
set -euo pipefail

get_current_user() {
  if [ -n "${SUDO_USER:-}" ]; then
    # Si le script est lancé avec sudo, utiliser l’utilisateur d’origine
    echo "$SUDO_USER"
  else
    # Sinon, l’utilisateur actuel
    whoami 2>/dev/null || echo "$USER"
  fi
}

get_current_user

CURRENT_USER=$(get_current_user)
CONTAINER_NAME="glpi-php"
CONTAINER_FOLDER="/var/www/html/glpi/files"
TMP_ARCHIVE="/home/glpi/glpi-10-php/glpi-files.tar.gz"
REMOTE_ARCHIVE="/var/www/html/glpi-files.tar.gz"

# Sous-dossiers à exclure
EXCLUDE_FOLDERS=(
  "_cache"
  "_cron"
  "_graphs"
  "_lock"
  "_log"
  "_rss"
  "_sessions"
  "_tmp"
)


ask_local_folder() {
  local input=""
  while true; do
    echo
    echo "Veuillez saisir le chemin du dossier GLPI 9 actuel (ex: /var/www/html/glpi) :"
    read -r input

    # Vérifie si l’utilisateur veut annuler
    if [ -z "$input" ]; then
      echo "Aucun chemin saisi. Veuillez réessayer ou taper Ctrl+C pour quitter."
      continue
    fi

    # Vérifie si le dossier existe
    if [ -d "$input" ]; then
      LOCAL_FOLDER="$input"
      echo "Dossier GLPI local défini sur : $LOCAL_FOLDER"
      break
    else
      echo "Erreur : le dossier '$input' n'existe pas."
      echo "Veuillez réessayer..."
    fi
  done
}

verify_local_folder() {
  if [ ! -d "$LOCAL_FOLDER" ]; then
    echo "Erreur : le dossier local $LOCAL_FOLDER n'existe pas."
    exit 1
  fi
}


# 1. Demande du dossier à l’utilisateur
ask_local_folder

# 2. Vérification du dossier local
verify_local_folder

# 3. Construire les options d’exclusion
EXCLUDE_OPTS=""
for folder in "${EXCLUDE_FOLDERS[@]}"; do
  EXCLUDE_OPTS+=" --exclude=$folder"
done

# 4. Créer l’archive
echo
echo "Création de l'archive en excluant : ${EXCLUDE_FOLDERS[*]}"
tar -czf "$TMP_ARCHIVE" -C "$LOCAL_FOLDER/files" $EXCLUDE_OPTS .

# 5. Copier dans le conteneur
echo
echo "Copie de l'archive vers le conteneur $CONTAINER_NAME..."
docker cp "$TMP_ARCHIVE" "$CONTAINER_NAME:$REMOTE_ARCHIVE"

# 6. Construire exclusion pour find
EXCLUDE_FIND=""
for folder in "${EXCLUDE_FOLDERS[@]}"; do
  EXCLUDE_FIND+=" -not -path $CONTAINER_FOLDER/$folder*"
done

# 7. Nettoyage + Extraction dans le conteneur
echo
echo "Mise a jour des permissions..."

# 8. Nettoyage local
rm -f "$TMP_ARCHIVE"

echo
echo "Déploiement terminé ! Les dossiers exclus n'ont pas été remplacés."