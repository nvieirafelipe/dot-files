# CI/CD and Actions

These illustrate common patterns. Consider what fits your context.

Gitea Actions is compatible with GitHub Actions syntax. Tea provides CLI access to manage secrets, variables, and workflow runs.

## Workflow runs

```bash
# List runs
tea actions runs list

# View a specific run
tea actions runs view 42

# Follow logs in real time
tea actions runs logs 42 --follow

# Cancel a run
tea actions runs cancel 42

# Delete a run
tea actions runs delete 42
```

## Secrets

```bash
# List secrets
tea actions secrets list

# Create a secret
tea actions secrets create MY_SECRET

# Delete a secret
tea actions secrets delete MY_SECRET
```

## Variables

```bash
# List variables
tea actions variables list

# Set a variable
tea actions variables set MY_VAR value

# Delete a variable
tea actions variables delete MY_VAR
```

## Workflows

```bash
# List workflow definitions
tea actions workflows
```
