# otel-demo Helm Chart — Extended README

This supplemental README points to the central documentation in `docs/` and provides quick install commands.

Important links
- Project docs root: `docs/README.md`
- Architecture: `docs/ARCHITECTURE_EXTENDED.md`
- Helm guidance: `docs/HELM_K8S_EXTENDED.md`
- Quickstart: `docs/QUICKSTART.md`

Quick install (dev)

```bash
helm lint ./helm-charts/otel-demo
helm upgrade --install otel-demo ./helm-charts/otel-demo -n dev --create-namespace -f helm-charts/otel-demo/values-dev.yaml --atomic
```

If you maintain the main `helm-charts/otel-demo/README.md`, consider adding a short link section pointing to these extended docs.
