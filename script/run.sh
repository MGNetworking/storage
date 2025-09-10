#!/bin/bash

set -e  # Arrêt en cas d'erreur

echo "Nettoyage des anciens conteneurs..."
docker-compose down --remove-orphans

echo "Compilation du projet Maven sans les tests..."
./mvnw clean package -DskipTests

echo "Construction de l'image Docker..."
docker build -t sonatype-nexus.backhole.ovh/file-storage-api:local .

echo "🚀 Deploiement local..."
docker-compose up -d

echo "Logs de l'application (dernières 20 lignes) du projet ..."
docker-compose logs file-storage-api