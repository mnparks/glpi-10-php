#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
MYSQL_ROOT_PASSWORD=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
LISTEN_PORT=""
# Fonction de nettoyage si Ctrl-C
cleanup() {
  stty echo 2>/dev/null || true  # restaure l'affichage du terminal

  exit 1
}

# Attrape Ctrl-C (SIGINT) et autres sorties normales
trap cleanup SIGINT

# If .env exists, ask whether to overwrite
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
              # Vérifier si le port est déjà utilisé
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
            # Prompt for password (masked)
            printf "%s" "$prompt"
            # read -s works in bash; ensure no echo
            stty -echo
            read -r password
            stty echo
            printf "\n"

            # Confirm password (masked)
            printf "Confirmez le mot de passe : "
            stty -echo
            read -r password_confirm
            stty echo
            printf "\n"

            # Check match
        if [ "$password" = "$password_confirm" ] && [ -n "$password" ]; then
            eval "$variable='$password'" 
                break
            else
            echo "Les mots de passe ne correspondent pas. Veuillez réessayer."
            # clear variables and loop again
            password=""
            password_confirm=""
            fi
        done
    fi 
}

create_env_variable "Entrez le port d'ecoute: " "PORT" LISTEN_PORT
create_env_variable "Entrez le mot de passe root MySQL: " "PASSWORD" MYSQL_ROOT_PASSWORD
create_env_variable "Entrez le nom de la base de donnees MySQL: " "DATABASE_INFO" MYSQL_DATABASE
create_env_variable "Entrez le nom de l'utilisateur MySQL: " "DATABASE_INFO" MYSQL_USER
create_env_variable "Entrez le mot de passe de l'utilisateur MySQL $MYSQL_USER: " "PASSWORD" MYSQL_PASSWORD

# Write to .env file
cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
LISTEN_PORT=$LISTEN_PORT
EOF
# Set secure permissions
chmod 600 "$ENV_FILE"

echo ".env créé avec succès et permissions définies sur 600."
echo "Emplacement : $(pwd)/$ENV_FILE"

gpg -c .env

gpg -d .env.gpg > .env
docker compose --env-file .env -f confs/docker/docker-compose.yml up -d
shred -u .env
