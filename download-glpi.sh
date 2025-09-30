#!/bin/bash
set -e  # Stoppe le script en cas d’erreur

# Variables
URL="https://github.com/glpi-project/glpi/releases/download/10.0.19/glpi-10.0.19.tgz"
ARCHIVE="glpi-10.0.19.tgz"
FOLDER="glpi"
TARGET="app"

echo "==> Téléchargement de $URL"
wget -q "$URL" -O "$ARCHIVE"

echo "==> Décompression de l’archive"
tar -xzf "$ARCHIVE"

echo "==> Renommage du dossier $FOLDER en $TARGET"
rm -rf "$TARGET"   # supprime le dossier cible s’il existe déjà
mv "$FOLDER" "$TARGET"

echo "==> Nettoyage de l’archive"
rm -f "$ARCHIVE"

echo "==> Terminé ! Le dossier GLPI est prêt dans ./$TARGET"
