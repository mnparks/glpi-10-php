#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
MYSQL_ROOT_PASSWORD=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
LISTEN_PORT=""

OLD_DB_HOST=""
OLD_DB_USER=""
OLD_DB_PASSWORD=""
OLD_DB_NAME=""

# Fonction de nettoyage si Ctrl-C
cleanup() {
  stty echo 2>/dev/null || true  # restaure l'affichage du terminal
  unset GPG_PASS 2>/dev/null || true
  exit 1
}
trap cleanup SIGINT

# Vérifier si .env existe déjà
if [ -f "$ENV_FILE" ]; then
  echo ".env existe déjà."
  read -r -p "Voulez-vous l'écraser ? [y/N] : " resp
  resp=${resp:-N}
  case "$resp" in
    [yY]|[yY][eE][sS])
      echo "Écrasement de $ENV_FILE..."
      ;;
    *)
      echo "Abandon. Aucune modification effectuée."
      exit 0
      ;;
  esac
fi

create_env_variable() {
    local prompt="$1"
    local type="$2"
    local variable="$3"
    local password=""
    local password_confirm=""
    local input=""

    if [ "$type" == "DATABASE_INFO" ]; then
        printf "%s" "$prompt"
        read -r input
        declare -g "$variable=$input"

    elif [ "$type" == "PORT" ]; then
        while true; do
          printf "%s" "$prompt"
          read -r input
          if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
              if ss -tuln | grep -q ":$input\b"; then
                  echo "Le port $input est déjà utilisé. Veuillez en choisir un autre."
              else
                  declare -g "$variable=$input"
                  break
              fi
          else
              echo "Veuillez entrer un numéro de port valide (1-65535)."
          fi
        done

    else
        while true; do
            printf "%s" "$prompt"
            stty -echo
            read -r password
            stty echo
            printf "\n"

            printf "Confirmez le mot de passe : "
            stty -echo
            read -r password_confirm
            stty echo
            printf "\n"

            if [ "$password" = "$password_confirm" ] && [ -n "$password" ]; then
                eval "$variable='$password'"
                break
            else
                echo "Les mots de passe ne correspondent pas. Veuillez réessayer."
                password=""
                password_confirm=""
            fi
        done
    fi
}

# ==== INFOS ANCIENNE BASE ====
create_env_variable "Entrez le host de l'ancienne base MySQL (ex: localhost ou IP): " "DATABASE_INFO" OLD_DB_HOST
create_env_variable "Entrez le nom de l'utilisateur de l'ancienne base: " "DATABASE_INFO" OLD_DB_USER
create_env_variable "Entrez le mot de passe de l'utilisateur de l'ancienne base: " "PASSWORD" OLD_DB_PASSWORD
create_env_variable "Entrez le nom de l'ancienne base de données: " "DATABASE_INFO" OLD_DB_NAME

# ==== NOUVELLE BASE ====
create_env_variable "Entrez le port d'écoute : " "PORT" LISTEN_PORT
create_env_variable "Entrez le mot de passe root MySQL : " "PASSWORD" MYSQL_ROOT_PASSWORD
create_env_variable "Entrez le nom de la nouvelle base de données : " "DATABASE_INFO" MYSQL_DATABASE
create_env_variable "Entrez le nom du nouvel utilisateur MySQL : " "DATABASE_INFO" MYSQL_USER
create_env_variable "Entrez le mot de passe de l'utilisateur MySQL $MYSQL_USER : " "PASSWORD" MYSQL_PASSWORD

# ==== ÉCRITURE DU FICHIER .env ====
cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
LISTEN_PORT=$LISTEN_PORT
EOF

chmod 600 "$ENV_FILE"
echo ".env créé avec succès et permissions définies sur 600."
echo "Emplacement : $(pwd)/$ENV_FILE"

# ==== EXPORTER L'ANCIENNE BASE ====
BACKUP_FILE="old_db_$(date +%Y%m%d_%H%M%S).sql"
echo "Export de l'ancienne base de données '$OLD_DB_NAME' depuis $OLD_DB_HOST..."
mysqldump -h "$OLD_DB_HOST" -u "$OLD_DB_USER" -p"$OLD_DB_PASSWORD" "$OLD_DB_NAME" > "$BACKUP_FILE"
echo "✅ Export terminé : $BACKUP_FILE"

# ==== CHIFFRER LE .env (MODE BATCH) ====
read -s -p "Entrez une phrase secrète pour chiffrer le .env : " GPG_PASS
printf "\n"

gpg --batch --yes --passphrase "$GPG_PASS" -c "$ENV_FILE"
unset GPG_PASS
echo "✅ Fichier .env chiffré avec succès (.env.gpg créé)"

# ==== DÉCHIFFRER ET DÉMARRER DOCKER ====
gpg --batch --yes --passphrase "$GPG_PASS" -d "$ENV_FILE.gpg" > "$ENV_FILE" 2>/dev/null || true
echo "Démarrage du service Docker..."
docker compose --env-file "$ENV_FILE" -f confs/docker/docker-compose.yml up -d

# ==== ATTENTE DU CONTAINER MYSQL ====
echo "Vérification du démarrage de MySQL..."
MYSQL_CONTAINER=$(docker ps --filter "ancestor=mysql" --format "{{.ID}}" | head -n 1)
timeout=60
while [ $timeout -gt 0 ]; do
  if docker exec "$MYSQL_CONTAINER" mysqladmin ping -h"localhost" --silent; then
    echo "✅ MySQL est prêt."
    break
  fi
  sleep 2
  ((timeout-=2))
done

if [ $timeout -le 0 ]; then
  echo "❌ MySQL ne répond pas après 60 secondes. Abandon."
  exit 1
fi

# ==== IMPORT DU DUMP ====
echo "Import du dump dans la nouvelle base '$MYSQL_DATABASE'..."
docker exec -i "$MYSQL_CONTAINER" \
  mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" < "$BACKUP_FILE"
echo "✅ Import terminé avec succès dans la base '$MYSQL_DATABASE'."

# ==== NETTOYAGE ====
shred -u "$ENV_FILE"
echo "Fichier .env supprimé en toute sécurité."
