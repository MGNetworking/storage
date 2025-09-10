#!/bin/bash

echo "Arrêt des conteneurs..."
docker-compose down

echo "Nettoyage complet (conteneurs + volumes + réseaux)..."
read -p "Voulez-vous supprimer aussi les volumes ? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down --volumes --remove-orphans
    echo "Conteneurs, volumes et réseaux supprimés."
else
    docker-compose down --remove-orphans
    echo "Conteneurs arrêtés, volumes conservés."
fi

echo "Nettoyage terminé."