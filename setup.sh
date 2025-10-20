#!/usr/bin/env bash
set -euo pipefail

# Fichiers des sous-scripts
ENV_SCRIPT="./create-env.sh"
BUILD_SCRIPT="./build-glpi.sh"
COPY_FILES_SCRIPT="./copy-files.sh"

usage() {
  echo "Usage: $0 [env|build|all]"
  echo
  echo "  env     → Générer/mettre à jour le fichier .env"
  echo "  build   → Télécharger GLPI et construire l’image Docker"
  echo "  all     → Faire env + build (installation complète)"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

case "$1" in
  env)
    echo "==> Exécution du script de création .env"
    bash "$ENV_SCRIPT"
    ;;
  build)
    echo "==> Exécution du script de construction GLPI"
    bash "$BUILD_SCRIPT"
    ;;
  all)
    echo "==> Construction GLPI"
    bash "$BUILD_SCRIPT"

    echo "==> Génération du .env"
    bash "$ENV_SCRIPT"
    echo "==> Terminé !"

    echo "==> Copie des fichiers dauvegardés dans le volume"
    bash "$COPY_FILES_SCRIPT"
    echo "==> Terminé !"
    ;;
  *)
    usage
    ;;
esac