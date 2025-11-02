# Re-encrypting Sealed Secrets

## Problem

The error "Failed to unseal: no key could decrypt secret" occurs when sealed secrets were encrypted with a different key than what the current sealed-secrets controller has. This typically happens when:
- The sealed-secrets controller was reinstalled/recreated
- The cluster was replaced
- The controller's private key was lost

## Solution

Re-encrypt all secrets using the current cluster's sealed-secrets controller.

## Steps to Fix

### 1. Ensure kubeseal is installed

```bash
# Check if kubeseal is installed
kubeseal --version

# If not installed, install it:
# Linux:
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xzf kubeseal-*.tar.gz
sudo mv kubeseal /usr/local/bin/

# macOS:
brew install kubeseal
```

### 2. Ensure secrets are in the .env file

The scripts will automatically read secrets from `scripts/.env`. Make sure this file exists and contains all required variables:

```bash
# The .env file should be in the scripts directory
# It should contain:
AUTH0_DOMAIN=your-domain
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
AUTH0_AUDIENCE=your-audience
SPRING_DATASOURCE_URL=jdbc:postgresql://...
SPRING_DATASOURCE_USERNAME=your-username
SPRING_DATASOURCE_PASSWORD=your-password
```

**Note:** The `.env` file is gitignored and should never be committed to the repository.

### 3. Ensure you're connected to the correct cluster

```bash
# Set your kubeconfig if needed
export KUBECONFIG=/path/to/your/config
# Or use the repo's config file
export KUBECONFIG=./config

# Verify connection
kubectl get nodes
```

### 4. (Optional) Delete existing SealedSecret resources

If you're getting errors about existing SealedSecret resources that can't be unsealed, you may want to delete them first:

```bash
# For auth-dev
kubectl delete sealedsecret -n auth-dev --all

# For gestao-de-alunos-dev
kubectl delete sealedsecret -n gestao-de-alunos-dev --all

# For gestao-de-professores-dev
kubectl delete sealedsecret -n gestao-de-professores-dev --all
```

**Note:** This will delete the SealedSecret resources, but the actual Kubernetes Secrets they created (if any) will remain. You can delete those too if needed:
```bash
kubectl delete secret -n <namespace> <secret-name>
```

### 5. Re-encrypt secrets for each service

Run the re-encrypt script for each affected service. The scripts will automatically read secrets from `scripts/.env`:

#### For auth-dev:
```bash
./scripts/re-encrypt-secrets.sh auth auth-dev
```

#### For gestao-de-alunos-dev:
```bash
./scripts/re-encrypt-secrets.sh gestao-de-alunos gestao-de-alunos-dev
```

#### For gestao-de-professores-dev:
```bash
./scripts/re-encrypt-secrets.sh gestao-de-professores gestao-de-professores-dev
```

Each script will:
1. Automatically load secret values from `scripts/.env`
2. Encrypt them using the current cluster's sealed-secrets controller
3. Output the encrypted values in YAML format

### 6. Update the values files

Copy the encrypted values from the script output into the corresponding values files:

- `environments/dev/values-auth.yaml` (for auth-dev)
- `environments/dev/values-gestao-de-alunos.yaml` (for gestao-de-alunos-dev)
- `environments/dev/values-gestao-de-professores.yaml` (for gestao-de-professores-dev)

Update the `sealedSecrets.data` section with the new encrypted values.

### 7. Commit and push

```bash
git add environments/dev/values-*.yaml
git commit -m "Re-encrypt secrets with current cluster key"
git push
```

ArgoCD will automatically sync the changes and the sealed secrets should now unseal correctly.

## Troubleshooting

### If you don't have the secret values

If you don't have access to the original secret values, you'll need to:
1. Retrieve them from your secret management system (e.g., password manager, Azure Key Vault)
2. Or regenerate new credentials and update all dependent systems

### If namespaces don't exist

The script will automatically create the namespace if it doesn't exist.

### If the sealed-secrets controller is not running

Check if the controller is running:
```bash
kubectl get pods -n kube-system | grep sealed-secrets
```

If it's not running, you may need to install/reinstall it. See `scripts/setup-argocd.sh` or your cluster setup documentation.

## Security Notes

- Never commit unencrypted secrets to git
- Always use sealed secrets for sensitive data
- Keep backups of your sealed-secrets controller's private key
- Rotate secrets regularly

