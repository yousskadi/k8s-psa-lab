# Guide de Migration PSP → PSA

> Pour les clusters Kubernetes < 1.25 utilisant encore les PodSecurityPolicy (PSP)

## Vue d'ensemble

| Étape | Action | Impact |
|-------|--------|--------|
| 1 | Activer warn + audit sur chaque namespace | Aucun — observation seule |
| 2 | Identifier et corriger les violations | Aucun — correction dev |
| 3 | Activer enforce=baseline | Bloque les pires violations |
| 4 | Corriger les violations baseline restantes | Corrections ciblées |
| 5 | Activer enforce=restricted | Sécurité maximale |
| 6 | Supprimer les PSP | Nettoyage final |

---

## Étape 1 — Activer l'observation (warn + audit)

```bash
# Pour chaque namespace à migrer
kubectl label namespace mon-namespace \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=v1.28 \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=v1.28

# Redéployer pour voir les warnings
kubectl rollout restart deployment -n mon-namespace
```

---

## Étape 2 — Corriger les violations

Les warnings dans kubectl ressemblent à :
```
Warning: would violate PodSecurity "restricted:v1.28":
  allowPrivilegeEscalation != false (container "app"),
  unrestricted capabilities (container "app"),
  seccompProfile not set (pod or container "app")
```

**Corrections type :**
- Ajouter `allowPrivilegeEscalation: false`
- Ajouter `capabilities.drop: [ALL]`
- Ajouter `seccompProfile.type: RuntimeDefault`
- Changer `runAsUser: 0` → `runAsUser: 1000` dans le Dockerfile

---

## Étape 3 — Activer enforce=baseline

```bash
kubectl label namespace mon-namespace \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=v1.28 \
  --overwrite

# Forcer la re-validation
kubectl rollout restart deployment -n mon-namespace
```

---

## Étape 4 et 5 — Monter vers restricted

```bash
# Appliquer manifests/04-migration/ dans l'ordre
kubectl apply -f manifests/04-migration/step1-audit-only.yaml
# ... corrections ...
kubectl apply -f manifests/04-migration/step2-baseline-enforce.yaml
# ... corrections ...
kubectl apply -f manifests/04-migration/step3-restricted-enforce.yaml
```

---

## Script de migration automatisé

```bash
#!/bin/bash
# Migrer un namespace en 3 phases
NAMESPACE="$1"

echo "Phase 1: Observation"
kubectl label ns "$NAMESPACE" \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn-version=v1.28 \
  pod-security.kubernetes.io/audit-version=v1.28

echo "Redéployez vos workloads et corrigez les warnings, puis appuyez sur Entrée..."
read -r

echo "Phase 2: Enforce baseline"
kubectl label ns "$NAMESPACE" \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=v1.28 \
  --overwrite
kubectl rollout restart deployment -n "$NAMESPACE"

echo "Vérifiez que tout tourne, puis appuyez sur Entrée pour passer à restricted..."
read -r

echo "Phase 3: Enforce restricted"
kubectl label ns "$NAMESPACE" \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite
kubectl rollout restart deployment -n "$NAMESPACE"
echo "✅ Migration terminée !"
```
