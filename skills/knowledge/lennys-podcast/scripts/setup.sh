#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/ChatPRD/lennys-podcast-transcripts.git"
TARGET_DIR="$HOME/lennys-podcast-transcripts"

if [ -d "$TARGET_DIR/.git" ]; then
    echo "Transcripts already cloned at $TARGET_DIR"
    echo "Pulling latest changes..."
    git -C "$TARGET_DIR" pull --ff-only
else
    echo "Cloning Lenny's Podcast transcripts to $TARGET_DIR..."
    git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
fi

episode_count=$(find "$TARGET_DIR/episodes" -name "transcript.md" | wc -l | tr -d ' ')
topic_count=$(find "$TARGET_DIR/index" -name "*.md" -not -name "README.md" | wc -l | tr -d ' ')

echo ""
echo "Setup complete:"
echo "  Episodes: $episode_count"
echo "  Topics:   $topic_count"
echo "  Location: $TARGET_DIR"
