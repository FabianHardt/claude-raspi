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
git config --global --unset-all credential.https://github.com.helper || true
git config --global --add credential.https://github.com.helper ""
git config --global --add credential.https://github.com.helper ghtokens
git config --global credential.https://github.com.useHttpPath true

# Re-login on every start so removed or rotated tokens don't linger in the home volume.
rm -f "$HOME/.config/gh/hosts.yml"
default_account=""
for entry in ${GH_TOKENS:-}; do
    [[ -n "${entry#*=}" ]] || continue
    account="${entry%%=*}"
    if printf '%s' "${entry#*=}" | gh auth login --hostname github.com --git-protocol https --with-token; then
        default_account="${default_account:-$account}"
    else
        echo "gh login failed for $account" >&2
    fi
done
if [[ -n "$default_account" ]]; then
    gh auth switch --hostname github.com --user "$default_account" >/dev/null
fi

tmux new-session -d -s claude /usr/local/bin/session.sh

exec ttyd --port 7681 --writable --credential "$TTYD_CREDENTIAL" \
    tmux new-session -A -s claude /usr/local/bin/session.sh
