# Development Environment

This directory contains environment-specific values for the development environment.

## Files

- `values-auth.yaml`: Overrides for auth service
- `values-gestao-de-alunos.yaml`: Overrides for gestao-de-alunos service
- `values-gestao-de-professores.yaml`: Overrides for gestao-de-professores service

## Usage

These values are automatically merged with the base values.yaml files in each service's chart directory when deployed via ArgoCD.

