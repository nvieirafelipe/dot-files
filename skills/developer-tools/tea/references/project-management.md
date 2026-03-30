# Project Management

These illustrate common patterns. Consider what fits your context.

## Labels

```bash
# List labels
tea labels ls
# Export labels to file
tea labels ls --save

# Create label
tea labels create --name bug --color "#d73a4a" --description "Something is broken"

# Update label
tea labels update --id 1 --name bugfix --color "#ff0000"

# Delete label
tea labels delete --id 1
```

## Milestones

```bash
# List milestones
tea milestones ls
tea milestones ls --state open

# Create milestone
tea milestones create --title "v1.0" --description "First release" --deadline "2026-06-01"

# Close / reopen
tea milestones close 1
tea milestones reopen 1

# Add/remove issues from milestone
tea milestones issues add 1 42
tea milestones issues remove 1 42

# Delete milestone
tea milestones delete 1
```

## Organizations

```bash
# List organizations
tea orgs ls

# Create organization
tea orgs create --name my-org --description "Description" --visibility public

# Delete organization
tea orgs delete my-org
```

## Branches

```bash
# List branches
tea branches ls

# Add branch protection
tea branches protect main

# Remove branch protection
tea branches unprotect main
```

## Time tracking

```bash
# Log time on an issue
tea times add 42 1h30m

# List time entries
tea times ls 42
tea times ls 42 --mine
tea times ls 42 --total

# Delete time entry
tea times delete 42 1

# Reset all tracked time
tea times reset 42
```

## Notifications

```bash
# List notifications
tea notifications ls
tea notifications ls --states unread
tea notifications ls --mine

# Mark as read / unread
tea notifications read 1
tea notifications unread 1

# Pin / unpin
tea notifications pin 1
tea notifications unpin 1
```

## Webhooks

```bash
# List webhooks
tea webhooks ls

# Create webhook
tea webhooks create --type gitea --url https://example.com/hook \
  --events push,pull_request --active

# Update webhook
tea webhooks update 1 --url https://example.com/new-hook

# Delete webhook
tea webhooks delete 1
```

## Login management

```bash
# List configured logins
tea login ls

# Add login
tea login add --name codeberg --url https://codeberg.org --token <token>

# Set default login
tea login default codeberg

# Delete login
tea login delete myforge

# Check current user
tea whoami
```

## Open in browser

```bash
# Open current repo in browser
tea open

# Open specific issue or PR
tea open 42
```
