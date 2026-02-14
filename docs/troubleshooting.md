# Guide de Dépannage PSA

## Erreurs courantes et solutions

### 1. Pod refusé — violations baseline

```
Error from server (Forbidden): pods "mon-pod" is forbidden:
violates PodSecurity "baseline:v1.28": host namespaces (hostPID=true)
```

**Cause :** Le pod utilise `hostPID`, `hostIPC` ou `hostNetwork`.  
**Solutions :**
- Supprimer `hostPID/hostIPC/hostNetwork` du spec si non nécessaire
- Ou déplacer le workload dans un namespace avec profil `privileged`
- Documenter obligatoirement l'exception via annotations

---

### 2. Pod refusé — violations restricted

```
violates PodSecurity "restricted:v1.28":
  allowPrivilegeEscalation != false (container "app"),
  unrestricted capabilities (container "app"),
  seccompProfile not set
```

**Correctif complet :**

```yaml
securityContext:              # Niveau POD
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
containers:
  - securityContext:          # Niveau CONTAINER
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
```

---

### 3. Pods existants non recheckés

**Comportement normal :** Quand vous ajoutez/modifiez un label PSA sur un namespace, les pods **existants** ne sont PAS re-vérifiés. Seuls les nouveaux pods sont soumis au contrôle.

**Pour forcer la re-validation :**
```bash
kubectl rollout restart deployment/mon-app -n mon-namespace
```

---

### 4. Warning "would violate PodSecurity restricted"

Ce n'est pas un blocage, juste un avertissement. Le pod est créé mais ne satisfait pas le profil `restricted` (vous avez `warn=restricted` sur le namespace).

**Pour corriger :** Adapter le securityContext (voir checklist dans README).

---

### 5. Namespace kube-system sans labels PSA

C'est **normal et attendu**. Les namespaces système sont exemptés dans la configuration globale (`AdmissionConfiguration.exemptions.namespaces`).

---

## Commandes de diagnostic

```bash
# Voir pourquoi un pod est refusé
kubectl describe pod <nom> -n <namespace>

# Tester AVANT d'appliquer
kubectl apply --dry-run=server -f mon-pod.yaml

# Voir les labels PSA d'un namespace
kubectl get namespace mon-ns -o json | \
  jq '.metadata.labels | with_entries(select(.key | startswith("pod-security")))'

# Auditer tous les pods pour violations restricted
./scripts/check-compliance.sh --level restricted

# Voir les violations dans les logs d'audit Kind
docker exec psa-lab-control-plane \
  cat /var/log/kubernetes/audit.log 2>/dev/null | \
  jq 'select(.annotations["pod-security.kubernetes.io/audit-violations"] != null)' \
  2>/dev/null | head -20
```

---

## Volumes autorisés par profil

| Type de volume | privileged | baseline | restricted |
|----------------|-----------|----------|------------|
| `emptyDir` | ✅ | ✅ | ✅ |
| `configMap` | ✅ | ✅ | ✅ |
| `secret` | ✅ | ✅ | ✅ |
| `persistentVolumeClaim` | ✅ | ✅ | ✅ |
| `projected` | ✅ | ✅ | ✅ |
| `hostPath` | ✅ | ✅ | ❌ |
| `hostPath` (readOnly) | ✅ | ✅ | ❌ |
| `nfs` | ✅ | ✅ | ❌ |
| `cephfs` | ✅ | ✅ | ❌ |

---

## Capabilities autorisées par profil restricted

Le profil `restricted` exige `drop: [ALL]` puis n'autorise qu'une seule capability en ajout :

```yaml
capabilities:
  drop: [ALL]
  add:
    - NET_BIND_SERVICE   # La SEULE capability autorisée par restricted
```

Toutes les autres capabilities (`NET_RAW`, `SYS_PTRACE`, `DAC_OVERRIDE`, etc.) sont **interdites** par `restricted`.

---

## Ressources utiles

- [PSA Documentation officielle](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [PSS Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Migration depuis PSP](https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/)
- [seccomp profiles](https://kubernetes.io/docs/tutorials/security/seccomp/)
