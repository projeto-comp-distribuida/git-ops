# GitOps Repository

This repository serves as the single source of truth for all service deployments. ArgoCD monitors this repository and automatically deploys changes to Kubernetes clusters.

## Structure

```
gitops-repo/
├── apps/                      # Service Helm charts
│   ├── auth/
│   ├── gestao-de-alunos/
│   ├── gestao-de-professores/
│   ├── grafana/
│   ├── prometheus/
│   ├── distrischool-api-gateway/
│   └── argocd/               # ArgoCD Application manifests
├── base/                      # Shared configurations and templates
└── environments/              # Environment-specific configurations
    ├── dev/                   # Development environment
    ├── staging/               # Staging environment (prepared for future)
    └── prod/                  # Production environment (prepared for future)
```

## Services

- **auth**: Authentication service
- **gestao-de-alunos**: Student management service
- **gestao-de-professores**: Teacher management service
- **prometheus**: Central metrics collection for Spring Boot services
- **grafana**: Visualization and dashboarding for collected metrics
- **distrischool-api-gateway**: API Gateway service (entry point for all services)

## Repository

This GitOps repository is hosted at: `https://github.com/projeto-comp-distribuida/git-ops.git`

## CI/CD Integration

Each service's CI/CD pipeline should update this repository by:
1. Updating the Helm values.yaml for the service with new image tags
2. Committing and pushing changes to this repository
3. ArgoCD will automatically detect changes and deploy updates

## ArgoCD Applications

ArgoCD Application manifests are located in `apps/argocd/` and reference the Helm charts in `apps/<service>/`.

All ArgoCD applications are configured to:
- Use automated sync with self-healing enabled
- Automatically create namespaces
- Merge environment-specific values from `environments/<env>/values-*.yaml`

## API Gateway

The **distrischool-api-gateway** service acts as the entry point for all client requests. It routes traffic to the appropriate microservices:

- Routes `/api/auth/**` to the auth service
- Routes `/api/students/**` to the gestao-de-alunos service  
- Routes `/api/teachers/**` to the gestao-de-professores service

The API gateway:
- Has ingress enabled (unlike other services) to receive external traffic
- Routes requests to backend services using ClusterIP service names
- Handles CORS configuration for frontend applications
- Provides health monitoring via Spring Boot Actuator endpoints

Backend services (auth, gestao-de-alunos, gestao-de-professores) have ingress disabled and use ClusterIP type, making them accessible only within the cluster for the API gateway to route requests.

## Environment Management

Currently, only the `dev` environment is active. Staging and production directories are prepared for future use.

