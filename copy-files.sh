#!/usr/bin/env bash
set -euo pipefail

# CONFIGURATION

CONTAINER_NAME="glpi-php"
LOCAL_FOLDER="/var/www/html/glpi/files"
CONTAINER_FOLDER="/var/www/html/glpi/files"
TMP_ARCHIVE="/home/safidy/glpi-files.tar.gz"
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

# Construire les options --exclude pour tar
EXCLUDE_OPTS=""
for folder in "${EXCLUDE_FOLDERS[@]}"; do
  EXCLUDE_OPTS+=" --exclude=$folder"
done

# Vérification du dossier local

if [ ! -d "$LOCAL_FOLDER" ]; then
  echo "Erreur : le dossier local $LOCAL_FOLDER n'existe pas."
  exit 1
fi


# Créer l'archive en excluant certains dossiers

echo "Création de l'archive en excluant : ${EXCLUDE_FOLDERS[*]}"
tar -czf "$TMP_ARCHIVE" -C "$LOCAL_FOLDER" $EXCLUDE_OPTS .

# Copier l'archive dans le conteneur
echo "Copie de l'archive vers le conteneur $CONTAINER_NAME..."
docker cp "$TMP_ARCHIVE" "$CONTAINER_NAME:$REMOTE_ARCHIVE"

# Construire l'exclusion pour find

EXCLUDE_FIND=""
for folder in "${EXCLUDE_FOLDERS[@]}"; do
  EXCLUDE_FIND+=" -not -path $CONTAINER_FOLDER/$folder*"
done

# Nettoyer et extraire dans le conteneur
echo "Nettoyage de l'ancien contenu (hors dossiers exclus) et extraction..."
docker exec -i "$CONTAINER_NAME" bash -c "
  find $CONTAINER_FOLDER/* $EXCLUDE_FIND -exec rm -rf {} +;
  tar -xzf $REMOTE_ARCHIVE -C $CONTAINER_FOLDER;
  rm -f $REMOTE_ARCHIVE;
  chown -R www-data:www-data /var/www/html/glpi;
  chmod -R 755 /var/www/html/glpi
"

rm -f "$TMP_ARCHIVE"

echo "Déploiement terminé ! Les dossiers exclus n'ont pas été remplacés."
