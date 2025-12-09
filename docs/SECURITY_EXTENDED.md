# Security & Secrets — Guidance and Best Practices

This doc covers security posture for the demo and recommended operational practices.

Identity & Access Management
- Use managed identity/service principal with least privilege for CI/CD and automation.
- For Terraform: create a dedicated service principal for state operations with Storage Blob Data Contributor on the state storage account.
- For ACR push: give CI `AcrPush` role on the registry.

Key Vault
- Store DB passwords, connection strings, and other sensitive values in Key Vault.
- Prefer Key Vault access via the Key Vault CSI provider in AKS.
- Use Key Vault access policies or RBAC (depending on your tenant configuration) to give only needed principals access.

RBAC
- Use Kubernetes RBAC roles and rolebindings to scope permissions per namespace and service account.
- Terraform `rbac-least-privilege` module provides starting templates; review before applying to prod.

Network security
- Use NSGs for subnet-level boundaries and Kubernetes NetworkPolicies for pod-level least privilege.
- Deny all ingress by default; create allow policies for required flows (ingress -> frontend, frontend -> APIs, APIs -> DB)

Pod security
- Enforce `runAsNonRoot` and drop Linux capabilities via `securityContext` in Helm values.
- Apply `podSecurity` policies (restricted baseline) via namespace labels if cluster supports PodSecurity admission.

Image security
- Scan images in CI with Trivy (or similar) and fail builds for critical CVEs.
- Pin images to digest in production for reproducible rollbacks.

Secrets handling in CI/CD
- Do not commit secrets. Use pipeline secrets, Azure Key Vault-backed variables, or a secure secret store.
- When creating Kubernetes secrets in pipeline, ensure they are created as `kubectl create secret generic --from-literal=... --dry-run=client -o yaml | kubectl apply -f -` to avoid persisting intermediate files.

Audit & monitoring
- Enable diagnostic logs for Key Vault and ACR and ingest into Log Analytics for alerting.
- Monitor suspicious activity for service principals and unusual role assignments.

Rotation & recovery
- Rotate database passwords and service principal credentials on a schedule.
- Enable soft-delete and purge protection options for Key Vault in production.

This doc accompanies `docs/TERRAFORM_EXTENDED.md` (which provisions Key Vault and RBAC pieces) and the pipeline docs (which describe secret consumption patterns).
