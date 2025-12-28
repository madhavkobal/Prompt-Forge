# Kubernetes Deployment Guide

Deploy PromptForge on Kubernetes.

## Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- Helm 3+ (optional)

## Quick Deploy

```bash
# Create namespace
kubectl create namespace promptforge

# Create secrets
kubectl create secret generic promptforge-secrets \
  --from-literal=database-url=postgresql://user:pass@postgres:5432/promptforge \
  --from-literal=secret-key=your-secret-key \
  --from-literal=gemini-api-key=your-gemini-key \
  -n promptforge

# Apply manifests
kubectl apply -f k8s/ -n promptforge

# Check status
kubectl get pods -n promptforge
```

## PostgreSQL Deployment

```yaml
# postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: promptforge_prod
        - name: POSTGRES_USER
          value: promptforge
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: promptforge-secrets
              key: db-password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
  - port: 5432
  selector:
    app: postgres
```

## Backend Deployment

```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: promptforge-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: promptforge-backend
  template:
    metadata:
      labels:
        app: promptforge-backend
    spec:
      containers:
      - name: backend
        image: promptforge/backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: promptforge-secrets
              key: database-url
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: promptforge-secrets
              key: secret-key
        - name: GEMINI_API_KEY
          valueFrom:
            secretKeyRef:
              name: promptforge-secrets
              key: gemini-api-key
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: promptforge-backend
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
  selector:
    app: promptforge-backend
```

## Ingress Configuration

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: promptforge-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - promptforge.example.com
    secretName: promptforge-tls
  rules:
  - host: promptforge.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: promptforge-backend
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: promptforge-frontend
            port:
              number: 80
```

## Scaling

```bash
# Scale backend
kubectl scale deployment promptforge-backend --replicas=5 -n promptforge

# Horizontal Pod Autoscaler
kubectl autoscale deployment promptforge-backend \
  --min=3 --max=10 --cpu-percent=70 -n promptforge
```

## Monitoring

```bash
# Install Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Add ServiceMonitor
kubectl apply -f monitoring/servicemonitor.yaml -n promptforge
```
