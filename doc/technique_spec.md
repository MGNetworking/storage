# Spécifications techniques – File Storage API (v1.0)

## Sommaire

1. [Stack technique](#1-stack-technique)
    - [Backend](#backend)
    - [Sécurité & Authentification](#sécurité--authentification)
    - [Cache & Performance](#cache--performance)
    - [Documentation & DevOps](#documentation--devops)
2. [Architecture](#2-architecture)
    - [Vue d'ensemble](#vue-densemble)
    - [Choix architectural](#choix-architectural)
    - [Configuration](#configuration)
3. [API Design](#3-api-design)
    - [POST /api/v1/files/upload](#post-apiv1filesupload)
    - [GET /api/v1/files/{id}](#get-apiv1filesid)
    - [GET /api/v1/files](#get-apiv1files)
    - [DELETE /api/v1/files/{id}](#delete-apiv1filesid)
4. [Sécurité & Performance](#4-sécurité--performance)
    - [Flux d'authentification OAuth2](#flux-dauthentification-oauth2)
    - [Gestion des rôles](#gestion-des-rôles)
    - [Performance - Base de données](#performance---base-de-données)
    - [Performance - Infrastructure](#performance---infrastructure)
    - [Monitoring](#monitoring)
5. [Évolutivité](#5-évolutivité)
    - [Améliorations techniques prévues](#améliorations-techniques-prévues)
    - [Migration potentielle](#migration-potentielle)
6. [Configuration des dépendances](#6-configuration-des-dépendances)
    - [Dépendances Spring Initializr](#dépendances-spring-initializr-à-sélectionner)
    - [Dépendances manuelles requises](#dépendances-manuelles-à-ajouter-au-pomxml)
    - [Instructions de setup](#instructions-de-setup)
7. [Git Workflow & CI/CD](#7-git-workflow--cicd)
   - [Structure des branches](#structure-des-branches)
   - [Pipeline Jenkins](#pipeline-jenkins)
   - [Stratégie de déploiement](#stratégie-de-déploiement)

---

## 1. Stack technique

### Backend

- **Java 17 + Spring Boot 3.x** : Framework mature avec écosystème riche pour développement API REST
- **JUnit 5** : Tests unitaires et d'intégration en approche TDD
- **PostgreSQL 15+** : Base relationnelle avec support JSONB pour métadonnées flexibles
- **Flyway** : Gestion des migrations de base de données versionnées

### Sécurité & Authentification

- **OAuth2 Resource Server** : Validation des tokens JWT
- **Keycloak** : Serveur d'identité centralisé pour la gestion des utilisateurs et rôles
- **Spring Security** : Intégration native avec l'écosystème OAuth2

### Cache & Performance

- **Redis** : Cache des métadonnées fréquemment consultées
- **HikariCP** : Pool de connexions optimisé pour accès concurrent à PostgreSQL

### Documentation & DevOps

- **Swagger/OpenAPI 3** : Documentation automatique des endpoints API
- **Docker + Docker Swarm** : Containerisation et orchestration sur NAS Synology
- **Jenkins** : CI/CD avec injection sécurisée du fichier de configuration `application-nas.yml`

## 2. Architecture

### Vue d'ensemble

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client Web    │    │   File Storage   │    │   PostgreSQL    │
│                 │───▶│      API         │───▶│    Database     │
│                 │    │  (Spring Boot)   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   NAS Storage   │    │    Keycloak     │
                       │   (Files)       │    │   (Identity)    │
                       └─────────────────┘    └─────────────────┘
```

### Choix architectural

- **API autonome** sans Gateway pour simplifier le déploiement MVP
- **Monolithe modulaire** adapté au contexte NAS personnel
- **Docker Swarm** sur Synology pour monitoring et haute disponibilité simple

### Configuration

Utilisation de profils Spring avec injection via Jenkins. Le fichier `application-nas.yml` sera fourni par Jenkins lors du déploiement :

```yaml
# application-nas.yml (fourni par Jenkins)
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USER}
    password: ${DB_PASSWORD}
keycloak:
  auth-server-url: ${KEYCLOAK_URL}
file-storage:
  nas-path: ${NAS_PATH}
```

## 3. API Design

### POST /api/v1/files/upload

**Objectif :** Upload d'un fichier utilisateur

**Request :**

- Content-Type: `multipart/form-data`
- Headers: `Authorization: Bearer {jwt}`
- Body :
    - `file`: (binary) - Fichier à uploader
    - `project`: (string) - Nom du projet (ex: "portfolio")
    - `extraMetadata`: (JSON, optionnel) - Métadonnées personnalisées

**Response 201 :**

```json
{
  "id": "91f4b2f9-23ab-4a1c-9f8a-4c7890a6c543",
  "originalName": "photo.png",
  "storedName": "91f4b2f9-1693456789-photo.png",
  "mimeType": "image/png",
  "size": 204800,
  "url": "https://cloud.monnas.com/files/portfolio/maxime/91f4b2f9-1693456789-photo.png",
  "uploadedAt": "2025-08-31T10:30:00Z"
}
```

**Errors :**

- `400` : Format de fichier invalide ou données manquantes
- `409` : Fichier identique déjà existant (même hash)
- `413` : Fichier trop volumineux (> 10Mo)

### GET /api/v1/files/{id}

**Objectif :** Récupération des métadonnées d'un fichier

**Response 200 :**

```json
{
  "id": "91f4b2f9-23ab-4a1c-9f8a-4c7890a6c543",
  "originalName": "photo.png",
  "mimeType": "image/png",
  "size": 204800,
  "fileHash": "3ac674216f3e15c761ee...",
  "url": "https://cloud.monnas.com/files/...",
  "uploadedAt": "2025-08-31T10:30:00Z",
  "extraMetadata": {
    "width": 1920,
    "height": 1080
  }
}
```

### GET /api/v1/files

**Objectif :** Liste des fichiers de l'utilisateur connecté

**Query Parameters :**

- `project`: (optionnel) Filtrer par projet
- `page`: (défaut: 0) Pagination
- `size`: (défaut: 20) Taille de page

**Response 200 :**

```json
{
  "content": [...],
  "totalElements": 156,
  "totalPages": 8,
  "size": 20,
  "number": 0
}
```

### DELETE /api/v1/files/{id}

**Objectif :** Suppression d'un fichier (utilisateur propriétaire ou ROLE_ADMIN)

**Response :**

- `204` : Suppression réussie
- `403` : Accès interdit
- `404` : Fichier introuvable

## 4. Sécurité & Performance

### Flux d'authentification OAuth2

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│  Keycloak   │────▶│   Client    │────▶│    API      │
│             │     │             │     │             │     │             │
│ 1.Demande   │     │ 2.Login +   │     │ 3.Appel API │     │ 4.Validation│
│ auth        │     │   JWT       │     │   + Token   │     │   Token     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

**Processus :**

1. Client redirigé vers Keycloak pour authentification
2. Keycloak retourne un JWT après login réussi
3. Client inclut le JWT dans chaque requête API
4. API valide le token via Keycloak et extrait les rôles utilisateur

### Gestion des rôles

- **ROLE_USER** : Accès CRUD sur ses propres fichiers
- **ROLE_ADMIN** : Accès global, suppression tous fichiers

### Performance - Base de données

- **Index simple** sur `file_hash` pour détection rapide des doublons
- **Contrainte unique** `(user_id, file_hash)` pour isolation utilisateur
- **Connexion pooling** via HikariCP pour optimiser les accès concurrent

### Performance - Infrastructure

- **Health checks** Docker Swarm pour redémarrage automatique en cas de défaillance
- **Limite upload** 10Mo pour éviter saturation réseau NAS
- **Validation MIME type** côté serveur pour sécurité et performance

### Monitoring

- **Logs structurés** JSON pour faciliter l'analyse
- **Métriques Docker** : CPU, RAM, espace disque disponible
- **Logs centralisés** via Docker logging driver

## 5. Évolutivité

### Améliorations techniques prévues

- **Extraction automatique** de métadonnées avancées (EXIF, durée vidéo)
- **API versioning** pour évolutions futures sans rupture
- **Audit trail** avec table d'historique des actions utilisateur
- **Optimisation cache** : Mise en cache des fichiers statiques côté Nginx

### Migration potentielle

- **Kubernetes** pour environnements de production plus larges
- **S3-compatible storage** pour scalabilité cloud
- **Gateway pattern** si multiplication des microservices

## 6. Configuration des dépendances

### Dépendances Spring Initializr (à sélectionner)
- **Spring Web** → inclut automatiquement : Spring MVC, Tomcat, Jackson
- **Spring Security** → inclut automatiquement : Spring Security Core, Web, Config
- **Spring Data JPA** → inclut automatiquement : Hibernate, HikariCP (pool de connexions)
- **PostgreSQL Driver** → driver JDBC pour PostgreSQL
- **Flyway Migration** → gestion des migrations de schéma
- **OAuth2 Resource Server** → validation JWT, Spring Security OAuth2
- **Spring Data Redis** → client Redis, Lettuce driver
- **Spring Boot Actuator dependencies** → health checks, metrics

### Dépendances automatiquement incluses (invisibles dans Spring Initializr)
- **JUnit 5** → inclus dans `spring-boot-starter-test`
- **HikariCP** → inclus dans `spring-boot-starter-data-jpa`

### Dépendances manuelles à ajouter au `pom.xml`
```xml
<!-- Keycloak (authentification) -->
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
    <version>25.0.3</version>
</dependency>

<!-- SpringDoc OpenAPI (documentation Swagger) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.11</version>
</dependency>
```

### Instructions de setup
1. Générer le projet via Spring Initializr avec les dépendances listées ci-dessus
2. Ajouter manuellement les dépendances Keycloak et OpenAPI dans le `pom.xml`
3. Le fichier `application-nas.yml` sera automatiquement injecté par Jenkins lors du déploiement


## 7. Git Workflow & CI/CD

### Structure des branches
- **master** : Production stable (protégée, pas de push direct)
- **dev** : Branche d'intégration (protégée, merge via PR uniquement)
- **feature/FSA-X** : Branches de développement (nommées selon ticket Jira)
- **nas** : Déploiement production avec rollback automatique

### Pipeline Jenkins
- **Feature → Dev** : Tests automatiques + validation code quality
- **Dev → Nas** : Tests d'intégration + déploiement + rollback si échec
- **Protection** : Aucun merge sans tests passants

### Stratégie de déploiement
- Déploiement automatique sur environnement dev
- Tests d'intégration et régression sur branche nas
- Mécanisme de rollback automatique en cas d'échec
- Notifications Slack/email des déploiements