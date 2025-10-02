#!/bin/bash
set -e  # stoppe le script en cas d'erreur

# Variables
URL="https://github.com/glpi-project/glpi/releases/download/10.0.19/glpi-10.0.19.tgz"
ARCHIVE="glpi-10.0.19.tgz"
FOLDER="glpi"
TARGET="app"
CONTAINER_NAME="glpi-container"
IMAGE_NAME="glpi:beta"
PORT=8080

echo "==> Vérification du dossier cible $TARGET"
if [ -d "$TARGET" ]; then
  echo "⚠️  Le dossier $TARGET existe déjà. On saute le téléchargement/décompression."
else
  echo "==> Téléchargement de $URL"
  wget -q "$URL" -O "$ARCHIVE"

  echo "==> Décompression de l’archive"
  tar -xzf "$ARCHIVE"

  echo "==> Renommage du dossier $FOLDER en $TARGET"
  rm -rf "$TARGET"   
  mv "$FOLDER" "$TARGET"

  echo "==> Nettoyage de l’archive"
  rm -f "$ARCHIVE"
fi

echo "==> Construction de l’image Docker $IMAGE_NAME"
docker build -f confs/docker/Dockerfile -t "$IMAGE_NAME" .


# echo "==> Vérification si le conteneur $CONTAINER_NAME existe déjà"
# if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
#   echo "⚠️  Le conteneur $CONTAINER_NAME existe déjà. Suppression..."
#   docker rm -f "$CONTAINER_NAME" || true
# fi



# echo "==> Lancement du conteneur $CONTAINER_NAME"
# docker run -d --name "$CONTAINER_NAME" -p $PORT:80 "$IMAGE_NAME"



# docker update --restart unless-stopped "$CONTAINER_NAME"
# echo  "==> Attente de 10 secondes pour que GLPI démarre..."
# sleep 10

# echo "==> Terminé !"
# echo "Accédez à GLPI via http://localhost:$PORT"
# echo
# echo "🔧 Commandes utiles :"
# echo "  docker logs -f $CONTAINER_NAME      # Voir les journaux"
# echo "  docker exec -it $CONTAINER_NAME bash # Accéder au conteneur"
# echo "  docker stop $CONTAINER_NAME          # Arrêter le conteneur"
# echo "  docker start $CONTAINER_NAME         # Redémarrer le conteneur"
# echo "  docker rm -f $CONTAINER_NAME         # Supprimer le conteneur"
# echo "  docker rmi $IMAGE_NAME               # Supprimer l’image"
# echo "  docker images                        # Lister les images"
# echo "  docker ps -a                         # Lister les conteneurs"
# echo "  docker system prune                  # Nettoyer les ressources inutilisées"
# echo "  docker volume ls                     # Lister les volumes"
