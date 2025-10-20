#!/usr/bin/env bash
set -euo pipefail

# =============================
#  SCRIPT DE MIGRATION GLPI
# =============================

# === VARIABLES ===
ENV_FILE=".env"
GPG_FILE=".env.gpg"

MYSQL_ROOT_PASSWORD=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
LISTEN_PORT=""
GPG_PASS=""

OLD_DB_HOST=""
OLD_DB_USER=""
OLD_DB_PASSWORD=""
OLD_DB_NAME=""

# === COULEURS ===
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# === NETTOYAGE ===
cleanup() {
  stty echo 2>/dev/null || true
  echo -e "\n${RED}[ABANDON]${NC} Script interrompu."
  exit 1
}
trap cleanup SIGINT

# === VÉRIFICATION .env ===
if [ -f "$ENV_FILE" ]; then
  echo -e "${YELLOW}.env existe déjà.${NC}"
  read -r -p "Voulez-vous l'écraser ? [y/N] : " resp
  resp=${resp:-N}
  case "$resp" in
    [yY]|[yY][eE][sS])
      echo -e "${YELLOW}Écrasement de $ENV_FILE...${NC}"
      ;;
    *)
      echo -e "${RED}Abandon. Aucune modification effectuée.${NC}"
      exit 0
      ;;
  esac
fi

# === FONCTION DE SAISIE ===
create_env_variable() {
    local prompt="$1"
    local type="$2"
    local variable="$3"
    local input=""
    local password=""
    local password_confirm=""

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
                  echo -e "${RED}Le port $input est déjà utilisé.${NC}"
              else
                  declare -g "$variable=$input"
                  break
              fi
          else
              echo -e "${RED}Veuillez entrer un numéro de port valide (1-65535).${NC}"
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
                echo -e "${RED}Les mots de passe ne correspondent pas. Veuillez réessayer.${NC}"
            fi
        done
    fi 
}

# === INFOS ANCIENNE BASE ===
create_env_variable "Entrez le host de l'ancienne base MySQL (ex: localhost ou IP): " "DATABASE_INFO" OLD_DB_HOST
create_env_variable "Entrez le nom de l'utilisateur de l'ancienne base: " "DATABASE_INFO" OLD_DB_USER
create_env_variable "Entrez le mot de passe de l'utilisateur de l'ancienne base: " "PASSWORD" OLD_DB_PASSWORD
create_env_variable "Entrez le nom de l'ancienne base de données: " "DATABASE_INFO" OLD_DB_NAME

# === NOUVELLE BASE ===
create_env_variable "Entrez le port d'écoute de la nouvelle version de GLPI: " "PORT" LISTEN_PORT
create_env_variable "Entrez le mot de passe root MySQL : " "PASSWORD" MYSQL_ROOT_PASSWORD
create_env_variable "Entrez le nom de la nouvelle base de données : " "DATABASE_INFO" MYSQL_DATABASE
create_env_variable "Entrez le nom du nouvel utilisateur MySQL : " "DATABASE_INFO" MYSQL_USER
create_env_variable "Entrez le mot de passe de l'utilisateur MySQL $MYSQL_USER : " "PASSWORD" MYSQL_PASSWORD

# === CRÉATION .env ===
cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
LISTEN_PORT=$LISTEN_PORT
EOF

chmod 600 "$ENV_FILE"
echo -e "${GREEN}[OK]${NC} .env créé avec succès (${ENV_FILE})"

# === EXPORT ANCIENNE BASE ===
BACKUP_FILE="old_db_$(date +%Y%m%d_%H%M%S).sql"

echo -e "\n${YELLOW}Export de l'ancienne base de données '$OLD_DB_NAME' depuis $OLD_DB_HOST...${NC}"

while true; do
  if mysqldump -h "$OLD_DB_HOST" -u "$OLD_DB_USER" -p"$OLD_DB_PASSWORD" "$OLD_DB_NAME" > "$BACKUP_FILE" 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC} Export terminé : $BACKUP_FILE"
    break
  else
    echo -e "${RED}[ERREUR] Échec de connexion à l'ancienne base MySQL.${NC}"
    read -r -p "Host MySQL : " OLD_DB_HOST
    read -r -p "Utilisateur MySQL : " OLD_DB_USER
    printf "Mot de passe MySQL %s : " "$OLD_DB_USER"
    stty -echo
    read -r OLD_DB_PASSWORD
    stty echo
    printf "\n"
    read -r -p "Nom de la base : " OLD_DB_NAME
  fi
done

# === CHIFFREMENT .env ===
if [ -f "$GPG_FILE" ]; then
  read -r -p ".env.gpg existe déjà. Voulez-vous le remplacer ? [y/N] : " resp
  [[ $resp =~ ^[Yy]$ ]] || { echo "Abandon."; exit 0; }
fi

read -s -p "Entrez une phrase secrète pour chiffrer le .env : " GPG_PASS
printf "\n"

gpg --batch --yes --passphrase "$GPG_PASS" -c "$ENV_FILE"
echo -e "${GREEN}[OK]${NC} Fichier .env chiffré avec succès ($GPG_FILE créé)"

# === TEST DU DÉCHIFFREMENT ===
if ! gpg --batch --yes --passphrase "$GPG_PASS" -d "$GPG_FILE" > "$ENV_FILE" 2>/dev/null; then
  echo -e "${RED}[ERREUR] Vérifiez la phrase secrète.${NC}"
  exit 1
fi

# === DÉMARRAGE DOCKER ===
echo -e "\n${YELLOW}Démarrage du service Docker...${NC}"
docker compose --env-file .env -f confs/docker/docker-compose.yml up -d

# === ATTENTE DU CONTAINER MYSQL ===
MYSQL_CONTAINER="glpi-database"
echo "Vérification du démarrage de MySQL..."
timeout=60
while [ $timeout -gt 0 ]; do
  if docker exec "$MYSQL_CONTAINER" mysqladmin ping -h"localhost" --silent; then
    echo -e "${GREEN}[OK]${NC} MySQL est prêt."
    break
  fi
  sleep 2
  ((timeout-=2))
done

if [ $timeout -le 0 ]; then
  echo -e "${RED}[ERREUR] MySQL ne répond pas après 60 secondes.${NC}"
  exit 1
fi

# === IMPORT DUMP DANS NOUVELLE BASE ===
echo -e "\n${YELLOW}Import du dump dans la nouvelle base '$MYSQL_DATABASE'...${NC}"

while true; do
  if docker exec "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $MYSQL_DATABASE;" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Connexion réussie. Début de l'import..."
    docker exec -i "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" < "$BACKUP_FILE"
    echo -e "${GREEN}[OK]${NC} Import terminé avec succès."
    break
  else
    echo -e "${RED}[ERREUR] Échec de connexion à la base MySQL dans le conteneur.${NC}"
    read -r -p "Nom de l'utilisateur MySQL : " MYSQL_USER
    printf "Mot de passe MySQL %s : " "$MYSQL_USER"
    stty -echo
    read -r MYSQL_PASSWORD
    stty echo
    printf "\n"
  fi
done

# === NETTOYAGE ===
shred -u "$ENV_FILE"
unset GPG_PASS
echo -e "${GREEN}[OK]${NC} Fichier .env supprimé en toute sécurité."
echo -e "${GREEN}=== Migration terminée avec succès ===${NC}"
