#!/usr/bin/env bash
# scripts/teardown-cluster.sh
# Supprime le cluster Kind et nettoie l'environnement
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()    { echo -e "\033[0;34m[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

CLUSTER_NAME="${1:-psa-lab}"

echo -e "${YELLOW}⚠️  Suppression du cluster '${CLUSTER_NAME}'${NC}"
read -rp "Confirmer ? [y/N] " confirm
[[ "${confirm,,}" != "y" ]] && { log_info "Annulé."; exit 0; }

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  log_success "Cluster '${CLUSTER_NAME}' supprimé"
else
  log_warn "Cluster '${CLUSTER_NAME}' non trouvé"
fi

# Nettoyer les images Docker Kind (optionnel)
read -rp "Supprimer les images Docker Kind également ? [y/N] " clean_images
if [[ "${clean_images,,}" == "y" ]]; then
  docker images "kindest/node" --format "{{.ID}}" | xargs -r docker rmi
  log_success "Images Kind supprimées"
fi

log_success "Nettoyage terminé"
