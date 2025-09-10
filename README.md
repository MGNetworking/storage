# Configuration des variables d'environnement

## Variables obligatoires

| Variable      | Description                | Context LOCAL             | Context DOCKER            |
|---------------|----------------------------|---------------------------|---------------------------|
| `DB_HOST`     | Host de la base de données | `localhost` ou `192.168.x.x` | `postgres` (nom service)  |
| `DB_PORT`     | Port de la base de données | `5432`                    | `5432`                    |
| `DB_NAME`     | Nom de la base de données  | `filestorage`             | `filestorage`             |
| `DB_SCHEMA`   | Schéma de la base          | `files`                   | `files`                   |
| `DB_USER`     | Utilisateur BDD            | `admin_dev`               | `admin_dev`               |
| `DB_PASSWORD` | Mot de passe BDD           | `uGwX87DidU`              | `uGwX87DidU`              |

## Variables optionnelles (avec valeurs par défaut)

| Variable        | Défaut  | Description               | Context LOCAL | Context DOCKER |
|-----------------|---------|---------------------------|---------------|----------------|
| `SERVER_PORT`   | `8666`  | Port du serveur           | `8666`        | `8666`         |
| `LOG_LEVEL_APP` | `DEBUG` | Niveau de log application | `DEBUG`       | `INFO`         |

## 📝 **Légende des contextes**

- **Context LOCAL** : Développement sur poste local (IDE IntelliJ)
    - Base de données PostgreSQL installée localement ou accessible par IP
    - Variables définies dans IntelliJ Run Configuration

- **Context DOCKER** : Déploiement avec Docker Compose
    - Base de données PostgreSQL dans un container
    - Résolution DNS par nom de service Docker
    - Variables définies dans docker-compose.yml ou fichier .env

## ⚙️ **Configuration IntelliJ**

1. Aller dans **Run/Debug Configurations**
2. Créer votre configuration Maven
3. Cliquer sur **"Modify options"** (en haut à droite)
4. Cocher **"Environment variables"** dans le menu déroulant
5. Dans la nouvelle section **Environment Variables** qui apparaît, cliquer sur l'icône pour ouvrir l'éditeur
6. Ajouter les variables une par une :
   ```
   DB_HOST=localhost
   DB_PORT=
   DB_NAME=filestorage
   DB_SCHEMA=files
   DB_USER=
   DB_PASSWORD=
   ```
7. Valider avec **OK**

**⚠️ Important** : Le champ "Run" doit contenir uniquement `spring-boot:run`