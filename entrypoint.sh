#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TTYD_CREDENTIAL:-}" ]]; then
    echo "TTYD_CREDENTIAL (user:password) must be set" >&2
    exit 1
fi

# The image is the source of truth for these files; the home volume only keeps state.
mkdir -p "$HOME/.claude"
cp /opt/claude-config/settings.json "$HOME/.claude/settings.json"
cp /opt/claude-config/CLAUDE.md "$HOME/.claude/CLAUDE.md"

if [[ -n "${GIT_USER_NAME:-}" ]]; then
    git config --global user.name "$GIT_USER_NAME"
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi
if [[ -n "${GH_TOKEN:-}" ]]; then
    gh auth setup-git
fi

tmux new-session -d -s claude /usr/local/bin/session.sh

exec ttyd --port 7681 --writable --credential "$TTYD_CREDENTIAL" \
    tmux new-session -A -s claude /usr/local/bin/session.sh
