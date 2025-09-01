# Spécification fonctionnelle – File Storage API (v1.0)

## Sommaire

1. [Gateway et CORS](#1-gateway-et-cors)
2. [Authentification (JWT avec Keycloak)](#2-authentification-jwt-avec-keycloak)
3. [Sauvegarde des fichiers](#3-sauvegarde-des-fichiers)
4. [Récupération des fichiers](#4-récupération-des-fichiers)
5. [Formats autorisés](#5-formats-autorisés)
6. [Métadonnées et gestion des doublons](#6-métadonnées-et-gestion-des-doublons)
    - [Structure de la table `files`](#structure-de-la-table-files)
    - [Gestion des doublons](#gestion-des-doublons)
    - [Exemple de structure](#exemple-de-structure)
7. [Évolutivité](#7-évolutivité)

---

## 1. Gateway et CORS

- Le **CORS (Cross-Origin Resource Sharing)** sera géré uniquement au niveau du **Gateway**.
- Le service **File Storage API** exposera ses endpoints uniquement en interne, publiés par le Gateway.
- **Décision :** CORS → gestion centralisée au Gateway.

## 2. Authentification (JWT avec Keycloak)

- File Storage API sera configuré en tant que **Resource Server**.
- Validation des tokens JWT fournis par le Gateway (délégation à Keycloak).
- Rôles définis dans Keycloak :
    - `ROLE_USER` → upload/téléchargement de ses fichiers.
    - `ROLE_ADMIN` → gestion complète (suppression, accès global).
- **Décision :** Auth via Keycloak, le service ne gère que la validation JWT.

## 3. Sauvegarde des fichiers

- Stockage dans des **dossiers prédéfinis** sur le NAS.
- **Format de chemin :** `/{projet}/{utilisateur}/{nom-unique}`
- **Génération du nom unique :** UUID + timestamp + extension originale
- Exemple : `/portfolio/maxime/91f4b2f9-1693456789-photo.png`
- **Décision :** Démarrage simple (MVP), création dynamique de dossiers envisagée plus tard.

## 4. Récupération des fichiers

- Les fichiers seront initialement **publics** via URL directe Nginx.
- Exemple : `https://cloud.monnas.com/files/portfolio/maxime/91f4b2f9-1693456789-photo.png`
- **Limitation :** Pas de gestion de fichiers privés dans cette version → prévu dans une évolution future via endpoints sécurisés.

## 5. Formats autorisés

- Tous les **MIME types standards** acceptés : `jpg`, `png`, `gif`, `pdf`, `mp4`…
- Validation côté backend pour bloquer les fichiers dangereux (`.exe`, scripts, etc.).
- Limite de taille : max **10Mo par fichier**.

## 6. Métadonnées et gestion des doublons

### Structure de la table `files`

- Métadonnées communes à tous les fichiers :
    - `id` (UUID) : identifiant unique généré par l'API
    - `user_id` (UUID) : propriétaire du fichier
    - `original_name` : nom original du fichier
    - `stored_name` : nom généré sur le disque (UUID + timestamp)
    - `file_hash` (SHA-256) : identité numérique du fichier pour la détection de doublons
    - `mime_type`, `size`, `storage_path`, `uploaded_at`
    - `extra_metadata` (JSON) : métadonnées spécifiques (dimensions, durée, etc.)

### Gestion des doublons

- **Règle métier :** Un utilisateur ne peut pas avoir deux fichiers identiques (même hash)
- **Contrainte DB :** `UNIQUE (user_id, file_hash)`
- **Indépendance utilisateurs :** Les doublons sont autorisés entre différents utilisateurs
- **Recherche rapide :** Index sur `file_hash` pour vérification instantanée

### Exemple de structure

```sql
CREATE TABLE files (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_name VARCHAR(255) NOT NULL,
    file_hash CHAR(64) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size BIGINT NOT NULL,
    storage_path VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    extra_metadata JSONB,
    CONSTRAINT unique_file_per_user UNIQUE (user_id, file_hash)
);
```

- **Décision :** Table générique unique (`files`) → pas besoin de séparer images/docs/vidéos.

## 7. Évolutivité

Ce projet démarre avec un périmètre limité (**MVP**) mais pourra être enrichi :

- Gestion des dossiers dynamiques.
- Support de fichiers privés sécurisés.
- Extraction automatique de métadonnées avancées (ex: durée vidéo, nombre de pages PDF).
- Intégration possible avec un CDN (Cloudflare, CloudFront).