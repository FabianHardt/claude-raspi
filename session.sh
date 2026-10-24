#!/usr/bin/env bash
cd /workspace || exit 1

while true; do
    if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        # --continue fails when no session was recorded yet (first start)
        rc=(claude remote-control --name "${RC_SESSION_NAME:-Raspberry Pi}" --permission-mode auto)
        "${rc[@]}" --continue || "${rc[@]}"
    else
        echo "Nicht eingeloggt: in der folgenden Session /login ausführen und danach /exit."
        claude
    fi
    echo "Claude beendet (Exit $?), Neustart in 5s ..."
    sleep 5
done
