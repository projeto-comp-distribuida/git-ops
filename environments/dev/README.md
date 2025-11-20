# Development Environment

This directory contains environment-specific values for the development environment.

## Files

- `values-auth.yaml`: Overrides for auth service
- `values-gestao-de-alunos.yaml`: Overrides for gestao-de-alunos service
- `values-gestao-de-professores.yaml`: Overrides for gestao-de-professores service
- `values-gestao-de-turmas-e-horarios.yaml`: Overrides for schedule management service
- `values-gestao-de-notas.yaml`: Overrides for grade management service
- `values-distrischool-front.yaml`: Overrides for the DistriSchool frontend
- `values-prometheus.yaml`: Overrides for Prometheus monitoring stack
- `values-grafana.yaml`: Overrides for Grafana dashboards

## Usage

These values are automatically merged with the base values.yaml files in each service's chart directory when deployed via ArgoCD.





















