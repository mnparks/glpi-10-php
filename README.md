# 🚀 Installation automatisée de GLPI avec Docker

Ce dépôt contient une série de scripts Bash permettant d’automatiser l’installation, la configuration et le déploiement de **GLPI** dans un environnement **Dockerisé**.

## 📁 Structure du projet

```
├── setup.sh               # Script principal (point d’entrée)
├── build-glpi.sh          # Téléchargement et construction de l’image GLPI
├── create-env.sh          # Création et chiffrement du fichier .env + import DB
├── copy-files.sh          # Synchronisation du dossier /files de GLPI
└── confs/
    └── docker/
        ├── Dockerfile
        └── docker-compose.yml
```

---

## 🔧 Pré-requis

Avant de lancer l’installation, assurez-vous que votre environnement possède :

- **Docker** ≥ 20.10  
- **Docker Compose** ≥ 2.x  
- **GPG** (pour le chiffrement du fichier `.env`)
- **wget** et **tar** installés
- Accès à Internet pour télécharger GLPI

---

## ⚙️ Donner les permissions d’exécution

Avant toute exécution, vous devez rendre les scripts exécutables :

```bash
chmod +x setup.sh build-glpi.sh create-env.sh copy-files.sh
```

> 💡 Cette étape est indispensable pour que les scripts puissent être exécutés directement en ligne de commande.

---

## 🚀 Exécution du script principal

Le script principal `setup.sh` gère l’ensemble du processus.  
Il peut être lancé avec trois options :

### 1️⃣ Générer uniquement le fichier `.env`
```bash
./setup.sh env
```
→ Crée et chiffre le fichier `.env`, exporte et importe les bases de données.

### 2️⃣ Construire uniquement GLPI
```bash
./setup.sh build
```
→ Télécharge GLPI, construit l’image Docker, et prépare l’environnement d’exécution.

### 3️⃣ Installation complète (recommandée)
```bash
./setup.sh all
```
→ Effectue automatiquement les étapes `build` + `env`.

---

## 🧱 Résumé du processus `./setup.sh all`

1. Téléchargement et installation de **GLPI 10.0.19**
2. Construction de l’image Docker (`glpi:beta`)
3. Création et chiffrement du fichier `.env`
4. Lancement du **docker-compose**
5. Attente du démarrage de MySQL
6. Import automatique de l’ancienne base
7. Nettoyage sécurisé du fichier `.env`

---

## 🧩 Scripts utiles

### 🗃️ `copy-files.sh`
Permet de copier le dossier `/files` du GLPI existant vers le nouveau conteneur,  
en **excluant automatiquement** les sous-dossiers temporaires (`_cache`, `_tmp`, etc.) :

```bash
./copy-files.sh
```

---

## 🔐 Sécurité

- Le fichier `.env` est **chiffré** avec GPG (`.env.gpg`).
- Le fichier `.env` original est **supprimé de manière sécurisée** après utilisation.
- Les permissions du `.env` sont restreintes à l’utilisateur (chmod 600).

---

## 🧹 Nettoyage

Pour supprimer les ressources inutilisées :
```bash
docker system prune
```

Pour supprimer le conteneur et l’image :
```bash
docker rm -f glpi-container
docker rmi glpi:beta
```

---

## 🌐 Accès

Une fois l’installation terminée, accédez à GLPI via :  
👉 http://localhost:8080

---

## 👨‍💻 Auteur

**Heriniaina Safidy Rabemorasata**  
Scripts et automatisation pour déploiement GLPI Docker  
© 2025

