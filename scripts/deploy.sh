#!/usr/bin/env bash
# Creates or redeploys the Portainer stack from this Git repo; config comes from deploy/.env.deploy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Own parser instead of `source`, so values like "Raspberry Pi" or "a&b" stay literal.
if [ -f deploy/.env.deploy ]; then
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw#"${raw%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    case "$line" in '#'*) continue ;; esac
    [ "${line#*=}" = "$line" ] && continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    export "$key=$value"
  done < deploy/.env.deploy
fi

require_var() {
  if [ -z "${!1:-}" ]; then
    echo "✗ Fehlende Variable: $1 (deploy/.env.deploy)" >&2
    exit 1
  fi
}
for var in PORTAINER_URL PORTAINER_API_KEY PORTAINER_ENDPOINT_ID GHCR_OWNER TTYD_CREDENTIAL; do
  require_var "$var"
done
for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "✗ Werkzeug fehlt: $tool" >&2; exit 1; }
done

STACK_NAME="${STACK_NAME:-claude-raspi}"
REPO_URL="${REPO_URL:-https://github.com/FabianHardt/claude-raspi}"
REPO_REF="${REPO_REF:-refs/heads/main}"
PORTAINER_URL="${PORTAINER_URL%/}"

STACK_ENV_KEYS=(
  GHCR_OWNER IMAGE_TAG TTYD_BIND TTYD_CREDENTIAL GH_TOKEN
  GIT_USER_NAME GIT_USER_EMAIL RC_SESSION_NAME TZ
)
ENV_JSON="[]"
for key in "${STACK_ENV_KEYS[@]}"; do
  [ -n "${!key:-}" ] || continue
  ENV_JSON=$(jq --arg n "$key" --arg v "${!key}" '. + [{name:$n, value:$v}]' <<<"$ENV_JSON")
done

api() {
  local method="$1" path="$2" body="${3:-}"
  local resp code
  resp=$(mktemp)
  code=$(curl -sS -o "$resp" -w "%{http_code}" -X "$method" \
    -H "X-API-Key: $PORTAINER_API_KEY" -H "Content-Type: application/json" \
    "$PORTAINER_URL/api$path" ${body:+-d "$body"})
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    echo "✗ Portainer $method $path → HTTP $code:" >&2
    cat "$resp" >&2; echo >&2
    rm -f "$resp"
    exit 1
  fi
  cat "$resp"
  rm -f "$resp"
}

STACK_ID=$(api GET /stacks | jq -r --arg n "$STACK_NAME" --argjson e "$PORTAINER_ENDPOINT_ID" \
  '.[] | select(.Name == $n and .EndpointId == $e) | .Id')

if [ -z "$STACK_ID" ]; then
  echo "→ Stack '$STACK_NAME' anlegen aus $REPO_URL ($REPO_REF)"
  PAYLOAD=$(jq -n --arg name "$STACK_NAME" --arg url "$REPO_URL" --arg ref "$REPO_REF" \
    --argjson env "$ENV_JSON" \
    '{name:$name, repositoryURL:$url, repositoryReferenceName:$ref,
      composeFile:"docker-compose.yml", repositoryAuthentication:false, env:$env}')
  api POST "/stacks/create/standalone/repository?endpointId=$PORTAINER_ENDPOINT_ID" "$PAYLOAD" >/dev/null
else
  echo "→ Stack $STACK_ID redeployen (git pull + image pull)"
  PAYLOAD=$(jq -n --arg ref "$REPO_REF" --argjson env "$ENV_JSON" \
    '{repositoryReferenceName:$ref, env:$env, prune:false, pullImage:true}')
  api PUT "/stacks/$STACK_ID/git/redeploy?endpointId=$PORTAINER_ENDPOINT_ID" "$PAYLOAD" >/dev/null
fi

echo "✓ Stack '$STACK_NAME' deployt. Web-Terminal: http://${TTYD_BIND:-<pi-ip>}:7681"
