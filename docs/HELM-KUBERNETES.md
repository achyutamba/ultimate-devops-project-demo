# Helm Charts and Kubernetes Documentation

## Table of Contents

- [Overview](#overview)
- [Helm Chart Structure](#helm-chart-structure)
- [Values Configuration](#values-configuration)
- [Templates](#templates)
- [Deployment Guide](#deployment-guide)
- [Configuration Management](#configuration-management)
- [Autoscaling](#autoscaling)
- [Security](#security)
- [Networking](#networking)
- [Observability Integration](#observability-integration)
- [Troubleshooting](#troubleshooting)

---

## Overview

The OpenTelemetry Demo uses Helm 3 for package management and deployment to Kubernetes. This provides:

- **Templating**: Dynamic Kubernetes manifests
- **Version control**: Track deployment versions
- **Rollback**: Easy rollback to previous versions
- **Environment management**: Different values files per environment
- **Modularity**: Reusable charts

### Key Features

✅ **18 Microservices**: All services templated and configurable  
✅ **Multi-environment**: Dev, Staging, Production value files  
✅ **Security hardened**: Pod Security Contexts, non-root containers  
✅ **Resource management**: CPU/memory requests and limits  
✅ **Autoscaling**: HPA for key services  
✅ **Network policies**: Traffic isolation  
✅ **Observability**: OpenTelemetry, Prometheus, Grafana  
✅ **Ingress**: Configurable ingress with TLS  

---

## Helm Chart Structure

```
helm-charts/otel-demo/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values-dev.yaml         # Development overrides
├── values-staging.yaml     # Staging overrides
├── values-production.yaml  # Production overrides
├── README.md               # Installation guide
│
└── templates/              # Kubernetes manifests
    ├── _helpers.tpl        # Helper functions
    ├── serviceaccount.yaml # Service account
    │
    ├── *-deployment.yaml   # Deployments (18 services)
    ├── *-service.yaml      # Services
    ├── flagd-configmap.yaml # Feature flags config
    ├── frontendproxy-ingress.yaml # Ingress
    │
    ├── hpa/                # Horizontal Pod Autoscalers
    │   ├── frontend-hpa.yaml
    │   ├── cart-hpa.yaml
    │   └── recommendation-hpa.yaml
    │
    ├── networkpolicy/      # Network isolation
    │   └── networkpolicy.yaml
    │
    └── observability/      # Monitoring stack
        ├── namespace.yaml
        ├── otel-collector.yaml
        ├── prometheus.yaml
        └── grafana.yaml
```

---

## Values Configuration

### Global Settings

```yaml
global:
  # Pod annotations (applied to all services)
  podAnnotations: {}
  
  # Pod security context (applied to all pods)
  podSecurityContext: {}
  
  # Container security context
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
  
  # Default resource limits
  resources:
    requests:
      cpu: "50m"
      memory: "64Mi"
    limits:
      cpu: "500m"
      memory: "256Mi"
```

### Service Configuration Pattern

Each service follows this structure:

```yaml
<service-name>:
  replicaCount: 1
  image:
    repository: "ghcr.io/open-telemetry/demo"
    tag: "1.12.0-<service-name>"
    pullPolicy: "IfNotPresent"
  service:
    type: ClusterIP
    port: 8080
    targetPort: 8080
  env:
    CUSTOM_VAR: "value"
  resources:  # Override global resources
    requests:
      cpu: "100m"
      memory: "128Mi"
```

### Environment-Specific Values

#### Development (`values-dev.yaml`)

```yaml
# Low resource usage, single replicas
frontend:
  replicaCount: 1
  resources:
    requests:
      cpu: "50m"
      memory: "64Mi"
    limits:
      cpu: "200m"
      memory: "128Mi"

# HPA disabled in dev
hpa:
  enabled: false
```

#### Staging (`values-staging.yaml`)

```yaml
# Mirrors production configuration
frontend:
  replicaCount: 2
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "256Mi"

# HPA enabled
hpa:
  enabled: true
```

#### Production (`values-production.yaml`)

```yaml
# High availability configuration
frontend:
  replicaCount: 3
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "512Mi"

# HPA with higher limits
hpa:
  enabled: true
  items:
    - name: frontend
      minReplicas: 3
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
```

---

## Templates

### Deployment Template Example

```yaml
# templates/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "otel-demo.fullname" . }}-frontend
  labels:
    {{- include "otel-demo.labels" . | nindent 4 }}
    app.kubernetes.io/component: frontend
spec:
  replicas: {{ .Values.frontend.replicaCount }}
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        {{- include "otel-demo.labels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ .Values.serviceAccountName }}
      
      # Security context
      securityContext:
        {{- toYaml .Values.global.podSecurityContext | nindent 8 }}
      
      containers:
      - name: frontend
        image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
        imagePullPolicy: {{ .Values.frontend.image.pullPolicy }}
        
        # Security context
        securityContext:
          {{- toYaml .Values.global.containerSecurityContext | nindent 10 }}
        
        # Ports
        ports:
        - name: http
          containerPort: {{ .Values.frontend.service.targetPort }}
          protocol: TCP
        
        # Environment variables
        env:
        - name: FRONTEND_PORT
          value: "{{ .Values.frontend.service.targetPort }}"
        {{- range $key, $value := .Values.frontend.env }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        
        # Resource limits
        resources:
          {{- toYaml .Values.frontend.resources | default .Values.global.resources | nindent 10 }}
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Service Template Example

```yaml
# templates/frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "otel-demo.fullname" . }}-frontend
  labels:
    {{- include "otel-demo.labels" . | nindent 4 }}
    app.kubernetes.io/component: frontend
spec:
  type: {{ .Values.frontend.service.type }}
  ports:
    - port: {{ .Values.frontend.service.port }}
      targetPort: {{ .Values.frontend.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    app: frontend
```

### Helper Functions (`_helpers.tpl`)

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "otel-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otel-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otel-demo.labels" -}}
helm.sh/chart: {{ include "otel-demo.chart" . }}
{{ include "otel-demo.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otel-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otel-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

---

## Deployment Guide

### Prerequisites

1. **Kubernetes cluster** (AKS, Minikube, Kind)
2. **Helm 3** installed
3. **kubectl** configured
4. **Namespace** created (optional)

### Installation

#### 1. Development Environment

```bash
# Create namespace
kubectl create namespace otel-demo-dev

# Install chart
helm install otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-dev.yaml \
  --namespace otel-demo-dev

# Verify deployment
kubectl get pods -n otel-demo-dev
```

#### 2. Staging Environment

```bash
# Create namespace
kubectl create namespace otel-demo-staging

# Install with staging values
helm install otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-staging.yaml \
  --namespace otel-demo-staging
```

#### 3. Production Environment

```bash
# Create namespace
kubectl create namespace otel-demo-prod

# Install with production values
helm install otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-production.yaml \
  --namespace otel-demo-prod \
  --timeout 15m \
  --wait
```

### Upgrade

```bash
# Upgrade with new values
helm upgrade otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-production.yaml \
  --namespace otel-demo-prod

# Upgrade with image tag override
helm upgrade otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-production.yaml \
  --set frontend.image.tag=1.13.0 \
  --namespace otel-demo-prod
```

### Rollback

```bash
# List releases
helm history otel-demo -n otel-demo-prod

# Rollback to previous version
helm rollback otel-demo -n otel-demo-prod

# Rollback to specific revision
helm rollback otel-demo 5 -n otel-demo-prod
```

### Uninstall

```bash
# Delete release
helm uninstall otel-demo -n otel-demo-prod

# Delete namespace
kubectl delete namespace otel-demo-prod
```

---

## Configuration Management

### Override Values

#### Method 1: Multiple Values Files

```bash
helm install otel-demo ./helm-charts/otel-demo \
  -f values.yaml \
  -f values-production.yaml \
  -f custom-overrides.yaml
```

#### Method 2: Command-Line Overrides

```bash
helm install otel-demo ./helm-charts/otel-demo \
  --set frontend.replicaCount=5 \
  --set frontend.resources.limits.cpu=2000m
```

#### Method 3: JSON/YAML Strings

```bash
helm install otel-demo ./helm-charts/otel-demo \
  --set-json 'frontend.env={"LOG_LEVEL":"debug","FEATURE_FLAG":"true"}'
```

### Environment Variables

Add custom environment variables:

```yaml
# values-custom.yaml
frontend:
  env:
    LOG_LEVEL: "info"
    FEATURE_XYZ_ENABLED: "true"
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
```

### Secrets Integration

#### From Kubernetes Secrets

```yaml
# Deployment template
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-credentials
      key: password
```

#### From Azure Key Vault

```yaml
# Using Azure Key Vault CSI driver
volumeMounts:
- name: secrets-store
  mountPath: "/mnt/secrets"
  readOnly: true

volumes:
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: "azure-kv-sync"
```

---

## Autoscaling

### Horizontal Pod Autoscaler (HPA)

#### Enable HPA

```yaml
# values-production.yaml
hpa:
  enabled: true
  items:
    - name: frontend
      minReplicas: 3
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
      targetMemoryUtilizationPercentage: 80
    
    - name: recommendation
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 75
```

#### HPA Template

```yaml
# templates/hpa/frontend-hpa.yaml
{{- if .Values.hpa.enabled }}
{{- $hpaConfig := (index .Values.hpa.items 0) }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "otel-demo.fullname" . }}-frontend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "otel-demo.fullname" . }}-frontend
  minReplicas: {{ $hpaConfig.minReplicas }}
  maxReplicas: {{ $hpaConfig.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ $hpaConfig.targetCPUUtilizationPercentage }}
  {{- if $hpaConfig.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ $hpaConfig.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
```

#### Monitor HPA

```bash
# View HPA status
kubectl get hpa -n otel-demo-prod

# Describe HPA
kubectl describe hpa otel-demo-frontend -n otel-demo-prod

# Watch HPA in real-time
kubectl get hpa -n otel-demo-prod --watch
```

### Vertical Pod Autoscaler (VPA)

*Optional: For automatic resource request adjustments*

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: frontend-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-demo-frontend
  updatePolicy:
    updateMode: "Auto"
```

---

## Security

### Pod Security Context

```yaml
# Applied to all pods
global:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
      - ALL
```

### Service Account

```yaml
# templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccountName }}
  labels:
    {{- include "otel-demo.labels" . | nindent 4 }}
```

Usage in deployments:

```yaml
spec:
  serviceAccountName: {{ .Values.serviceAccountName }}
```

### Network Policies

#### Enable Network Policies

```yaml
# values.yaml
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
```

#### Network Policy Template

```yaml
# templates/networkpolicy/networkpolicy.yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "otel-demo.fullname" . }}-default
spec:
  podSelector:
    matchLabels:
      {{- include "otel-demo.selectorLabels" . | nindent 6 }}
  policyTypes:
  {{- range .Values.networkPolicy.policyTypes }}
  - {{ . }}
  {{- end }}
  
  # Allow ingress from same namespace
  ingress:
  - from:
    - podSelector:
        matchLabels:
          {{- include "otel-demo.selectorLabels" . | nindent 10 }}
  
  # Allow egress to DNS, same namespace, external
  egress:
  - to:
    - podSelector:
        matchLabels:
          {{- include "otel-demo.selectorLabels" . | nindent 10 }}
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
{{- end }}
```

### Image Pull Secrets

```yaml
# For private container registries
imagePullSecrets:
  - name: acr-credentials
```

Create secret:

```bash
kubectl create secret docker-registry acr-credentials \
  --docker-server=<acr-name>.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --namespace otel-demo-prod
```

---

## Networking

### Service Types

#### ClusterIP (Default)

Internal-only service:

```yaml
frontend:
  service:
    type: ClusterIP
    port: 8080
```

#### LoadBalancer

External access via cloud load balancer:

```yaml
frontend:
  service:
    type: LoadBalancer
    port: 80
    targetPort: 8080
```

#### NodePort

Access via node IP:

```yaml
frontend:
  service:
    type: NodePort
    port: 8080
    nodePort: 30080
```

### Ingress

#### Configure Ingress

```yaml
# values-production.yaml
frontendproxy:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: otel-demo.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: otel-demo-tls
        hosts:
          - otel-demo.example.com
```

#### Ingress Template

```yaml
# templates/frontendproxy-ingress.yaml
{{- if .Values.frontendproxy.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "otel-demo.fullname" . }}-frontend
  annotations:
    {{- range $key, $value := .Values.frontendproxy.ingress.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
spec:
  ingressClassName: {{ .Values.frontendproxy.ingress.className }}
  {{- if .Values.frontendproxy.ingress.tls }}
  tls:
    {{- range .Values.frontendproxy.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.frontendproxy.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "otel-demo.fullname" $ }}-frontendproxy
                port:
                  number: 8080
          {{- end }}
    {{- end }}
{{- end }}
```

---

## Observability Integration

### OpenTelemetry Collector

```yaml
# templates/observability/otel-collector.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: {{ .Values.observability.namespace }}
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:latest
        ports:
        - containerPort: 4317  # OTLP gRPC
        - containerPort: 4318  # OTLP HTTP
        - containerPort: 8888  # Metrics
        volumeMounts:
        - name: config
          mountPath: /etc/otel
      volumes:
      - name: config
        configMap:
          name: otel-collector-config
```

### Prometheus

```yaml
# templates/observability/prometheus.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: {{ .Values.observability.namespace }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        emptyDir: {}
```

### Service Annotations

Add Prometheus scraping annotations:

```yaml
# In deployment template
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

---

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

```bash
# Check pod status
kubectl get pods -n otel-demo-prod

# Describe pod
kubectl describe pod <pod-name> -n otel-demo-prod

# View logs
kubectl logs <pod-name> -n otel-demo-prod

# View previous logs (if crashed)
kubectl logs <pod-name> -n otel-demo-prod --previous
```

#### 2. Image Pull Errors

**Error**: `ErrImagePull` or `ImagePullBackOff`

**Solutions**:
- Verify image exists: `docker pull <image>`
- Check image pull secrets
- Verify ACR integration

```bash
# Test ACR connectivity from AKS
kubectl run -it --rm debug --image=<acr-name>.azurecr.io/test:latest --restart=Never
```

#### 3. Resource Constraints

**Error**: `Pod exceeded memory/CPU limits`

**Solutions**:
- Increase resource limits in values file
- Check actual usage: `kubectl top pods -n otel-demo-prod`
- Review metrics in Prometheus/Grafana

#### 4. Service Not Accessible

```bash
# Check service
kubectl get svc -n otel-demo-prod

# Check endpoints
kubectl get endpoints <service-name> -n otel-demo-prod

# Port-forward for testing
kubectl port-forward svc/otel-demo-frontend 8080:8080 -n otel-demo-prod
```

#### 5. Helm Installation Failures

```bash
# Debug template rendering
helm template otel-demo ./helm-charts/otel-demo \
  -f values-production.yaml \
  --debug

# Dry-run installation
helm install otel-demo ./helm-charts/otel-demo \
  -f values-production.yaml \
  --dry-run --debug

# Lint chart
helm lint ./helm-charts/otel-demo
```

### Debugging Commands

```bash
# Get all resources
kubectl get all -n otel-demo-prod

# Check events
kubectl get events -n otel-demo-prod --sort-by='.lastTimestamp'

# Exec into pod
kubectl exec -it <pod-name> -n otel-demo-prod -- /bin/sh

# Copy files from pod
kubectl cp <pod-name>:/path/to/file ./local-file -n otel-demo-prod

# Check resource usage
kubectl top pods -n otel-demo-prod
kubectl top nodes
```

---

## Best Practices

### 1. Resource Management

Always set requests and limits:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

### 2. Health Checks

Define liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

### 3. Labels and Annotations

Use consistent labeling:

```yaml
labels:
  app.kubernetes.io/name: otel-demo
  app.kubernetes.io/component: frontend
  app.kubernetes.io/version: "1.12.0"
  app.kubernetes.io/managed-by: helm
```

### 4. Configuration Management

- Use ConfigMaps for non-sensitive config
- Use Secrets for sensitive data
- Use environment-specific values files
- Never hardcode credentials

### 5. Deployment Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

## Next Steps

1. **Deploy to Dev**: Test chart installation
2. **Configure Monitoring**: Set up Prometheus and Grafana
3. **Enable HPA**: Test autoscaling behavior
4. **Add Network Policies**: Implement traffic restrictions
5. **Production Deployment**: Deploy with production values
6. **CI/CD Integration**: Automate with Azure Pipelines

---

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
