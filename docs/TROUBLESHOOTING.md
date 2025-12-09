# Troubleshooting — Common issues and fixes

This guide collects common errors you may encounter when working with this project and how to resolve them.

1) `az login` refresh token expired (AADSTS700082)
- Symptom: `Authentication failed ... The refresh token has expired due to inactivity`.
- Fix: Re-run interactive login or device code flow.

```bash
az login --use-device-code
# or
az login
```

- If you still have no subscriptions listed, use `az login --allow-no-subscriptions` to get tenant-level access, then confirm the correct subscription with `az account list` and `az account set --subscription <id>`.

2) Terraform backend access errors
- Symptom: cannot read/write state, or access denied to storage account/container
- Fix: Ensure the principal used has `Storage Blob Data Contributor` on the storage account and the container exists. Validate access with `az storage blob list` using the same principal.

3) Provider version mismatch
- Symptom: `Incompatible provider` or `required_version` error
- Fix: Update local `terraform` binary to match `required_version` in `main.tf` or adjust the `required_providers` to versions compatible with your terraform binary.

4) Helm lint or template errors
- Symptom: `helm lint` shows missing template values or `nil` errors when rendering
- Fix: run `helm template` locally with the same `-f values-*.yaml` files used in pipelines. Make sure required values are present. Add defaults into `values.yaml` for required fields.

5) No metrics in Prometheus / missing scrape
- Symptom: metrics not visible in Prometheus
- Fix: ensure `prometheus.io/scrape: "true"` annotation is present, service monitors exist, and Prometheus has permissions to scrape.

6) AKS kubeconfig issues in pipeline
- Symptom: `az aks get-credentials` fails or `kubectl` complains
- Fix: Ensure the service principal has `Azure Kubernetes Service Cluster User Role` or use `az aks get-credentials --admin` with care. Confirm cluster access through portal IAM.

7) Helm upgrade stuck or pods CrashLoopBackOff
- Fix: `kubectl describe pod` and `kubectl logs` to find the crash reason. Roll back with `helm rollback` if necessary.

8) Terraform resource conflicts or drift
- Symptom: `plan` shows changes you didn’t expect
- Fix: check for out-of-band changes, consider `terraform import` if resources were created outside Terraform, and review module inputs for computed values triggering changes.

9) Key Vault access denied from AKS
- Symptom: pods cannot read secrets via Key Vault CSI
- Fix: verify AKS managed identity or service principal is in Key Vault access policies or assigned Key Vault roles (depending on RBAC model). Check Key Vault firewall rules and network restrictions.

10) Image pull failures
- Symptom: `ImagePullBackOff` referencing ACR
- Fix: confirm AKS has pull permissions to ACR: `az role assignment list --assignee <aks-managed-identity>` and ensure `acr_id` is linked to AKS or use `az acr update --admin-enabled` (not recommended for prod).

If you hit an issue not covered here, capture logs, relevant resource IDs, and open an issue with the `docs/` pointers to the failing components.
