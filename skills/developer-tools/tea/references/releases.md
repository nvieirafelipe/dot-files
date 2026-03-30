# Release Management

These illustrate common patterns. Consider what fits your context.

## Creating releases

```bash
# Basic release
tea releases create --tag v1.0.0 --title "Release 1.0" --note "Changelog here"

# Draft release
tea releases create --tag v1.0.0 --title "Release 1.0" --draft

# Pre-release
tea releases create --tag v1.0.0-rc1 --title "Release Candidate 1" --prerelease

# With file attachments
tea releases create --tag v1.0.0 --title "Release 1.0" \
  --asset ./dist/binary-linux-amd64 \
  --asset ./dist/binary-darwin-amd64
```

## Listing releases

```bash
tea releases ls
tea releases ls --output json
```

## Editing releases

```bash
tea releases edit 1 --title "Updated Title" --note "Updated notes"
```

## Deleting releases

```bash
# Delete release only
tea releases delete 1 --confirm

# Delete release and its tag
tea releases delete 1 --confirm --delete-tag
```

## Managing release assets

```bash
# List assets for a release
tea releases assets list 1

# Add asset to existing release
tea releases assets create 1 --asset ./dist/binary.tar.gz

# Delete asset
tea releases assets delete 1 --asset-id 5
```
