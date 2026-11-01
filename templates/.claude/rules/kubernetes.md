---
paths:
  - "k8s/**"
  - "charts/**"
  - "**/kustomization.yaml"
  - "**/values*.yaml"
  - "terraform/**"
---

# Kubernetes / Kustomize / Argo CD conventions (infra)

- **GitOps**: Argo CD syncs `HEAD` with prune + selfHeal. A merged change is live: never commit
  something you have not rendered. Render before you push:
  `kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone <dir>` (or `make render`).
- **Pin everything**: image tags (never `:latest`, use a version or digest), chart versions, remote
  resources by tag or commit, never a `master`/`main` raw URL.
- **Secrets**: only `VaultSecret` CRs or `${CFG_*}` placeholders. Never a literal secret, never a
  base64 `Secret` manifest. Vault roles are per namespace and per service account.
- **Every workload** sets resources (requests + limits), probes, `securityContext`
  (`runAsNonRoot`, `readOnlyRootFilesystem` where possible, drop ALL capabilities) and, for new
  namespaces, a default-deny `NetworkPolicy` with explicit allows.
- **Production apps** never run with debug on (`APP_DEBUG=false`, `LOG_LEVEL` info or warn).
- Alerts and ServiceMonitors reference labels that exist; check with the rendered output.
- **Vault secrets, policies and roles are always managed through Terraform (`infra/terraform`),
  never by hand**: no `vault kv put`, `vault policy write` or `vault write auth/...`. Change
  `secrets_variables.tfvars`, `policies/*.hcl` or `roles.tf` and let the owner run
  `terraform apply`; a hand-made change drifts from the state and is reverted by the next apply.
- Terraform: `terraform fmt` and `terraform validate`; never read or print `*.tfvars` or state.
- Terraform `plan`/`apply` run on the owner's machine (the state backend, Garage S3, holds every
  secret in clear and its credentials never reach agents or CI): write what to run in the PR or a
  local-session prompt.
- Agents never need cluster-admin or `kubectl exec`: changes go through a PR, results through CI.
