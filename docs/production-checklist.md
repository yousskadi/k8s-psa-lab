# Checklist Production — Pod Security Admissions

## Avant de déployer en production

### Cluster
- [ ] Kubernetes 1.25+ (PSA intégré, PSP supprimées)
- [ ] `AdmissionConfiguration` configurée avec politique par défaut `baseline`
- [ ] Namespaces système exemptés dans `AdmissionConfiguration`
- [ ] Logs d'audit activés et centralisés
- [ ] Métriques `pod_security_evaluations_total` remontées dans Prometheus

### Namespaces
- [ ] Chaque namespace a des labels PSA explicites
- [ ] Versions PSS fixées (`v1.28`, pas `latest`)
- [ ] Namespaces `privileged` documentés avec annotations obligatoires
- [ ] Labels PSA dans les manifests Git (pas juste appliqués manuellement)

### Workloads
- [ ] Tous les Deployments/StatefulSets/DaemonSets testés avec `--dry-run=server`
- [ ] `runAsNonRoot: true` défini (pod ou container level)
- [ ] `seccompProfile.type: RuntimeDefault` défini
- [ ] `allowPrivilegeEscalation: false` dans chaque container
- [ ] `capabilities.drop: [ALL]` dans chaque container
- [ ] Pas de `hostPath` volumes (ou exception documentée)
- [ ] Images applicatives avec utilisateur non-root (ex: `USER 1000` dans Dockerfile)

### CI/CD
- [ ] Pipeline CI crée un cluster Kind éphémère pour les tests
- [ ] `kubectl apply --dry-run=server` dans la CI
- [ ] Rapport de conformité généré automatiquement
- [ ] Blocage du merge/deploy si violations PSA détectées

### Monitoring & Alerting
- [ ] Alerte sur `pod_security_evaluations_total{decision="deny",mode="enforce"}`
- [ ] Dashboard Grafana pour visualiser les violations PSA au fil du temps
- [ ] Logs d'audit Kubernetes envoyés dans SIEM (Elastic, Splunk, etc.)

### Documentation
- [ ] Procédure de demande d'exception documentée
- [ ] Runbook de migration PSP→PSA disponible
- [ ] Équipes dev formées aux exigences du profil `restricted`
- [ ] Procédure d'upgrade PSS lors d'un upgrade Kubernetes

---

## Commandes de validation finale

```bash
# 1. Vérifier tous les namespaces
./scripts/audit-namespaces.sh

# 2. Vérifier la conformité des pods en cours
./scripts/check-compliance.sh

# 3. Tester tous les manifests en dry-run
find manifests/ -name '*.yaml' | xargs -I {} \
  kubectl apply --dry-run=server -f {} 2>&1

# 4. Vérifier qu'aucun namespace privilégié n'est sans annotation
kubectl get namespaces -o json | jq -r '
  .items[]
  | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == "privileged")
  | select(.metadata.annotations["psa-exception-reason"] == null)
  | .metadata.name + " : MANQUE ANNOTATION"'
```
