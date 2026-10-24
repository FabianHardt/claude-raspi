# claude-raspi

Eine dauerhaft laufende Claude-Code-Session auf dem Raspberry Pi 5, betrieben als Portainer-Stack.

- **Primär:** [Remote Control](https://code.claude.com/docs/en/remote-control). Du steuerst die Session über claude.ai/code oder die Claude-App. Es gehen nur ausgehende HTTPS-Verbindungen raus, du brauchst keine Port-Freigaben.
- **Fallback:** Web-Terminal (ttyd) auf Port 7681 im LAN, von unterwegs über das VPN. Es zeigt dieselbe tmux-Session `claude`.

## Aufbau

| Datei | Zweck |
|---|---|
| `Dockerfile` | arm64-Image: Debian trixie, Claude Code (native), tmux, ttyd, git, gh, node, python |
| `entrypoint.sh` | kopiert die Config, richtet Git/gh ein und startet tmux + ttyd |
| `session.sh` | Endlosschleife in tmux: `claude remote-control --continue` (dockt nach Neustarts wieder an), ohne Login `claude` |
| `config/settings.json` | Permissions der Session; wird bei jedem Start nach `~/.claude/` kopiert |
| `config/CLAUDE.md` | globale Instruktionen für die Session |
| `.github/workflows/build.yml` | baut `ghcr.io/<owner>/claude-raspi` für linux/arm64 |

Volumes: `claude-home` (`/home/claude`: Login, History, Git-Config) und `workspace` (`/workspace`: Repos).

## Einrichtung

1. **Image bauen:** Repo nach GitHub pushen. Die Action baut und pusht `ghcr.io/<owner>/claude-raspi:latest`. Ist das Package privat, legst du in Portainer unter *Registries* GHCR mit einem PAT (`read:packages`) an.
2. **Stack anlegen:** Portainer → *Stacks* → *Add stack* → *Repository* (dieses Repo, `docker-compose.yml`). Die Env-Variablen trägst du nach `stack.env.example` ein, mindestens `GHCR_OWNER` und `TTYD_CREDENTIAL`. `TTYD_BIND` setzt du auf die LAN-IP des Pi.
3. **Erst-Login:** `http://<pi-ip>:7681` öffnen und dich mit `TTYD_CREDENTIAL` anmelden. In der Claude-Session `/login` ausführen und die angezeigte URL im Browser öffnen. Danach beendest du die Session mit `/exit`. Die Schleife startet dann automatisch `claude remote-control`.
4. **Verbinden:** In claude.ai/code oder in der Claude-App taucht die Session auf.

## Betrieb

- **Update von Claude Code:** Der Auto-Updater ist im Container aus. Die Action baut das Image wöchentlich neu. In Portainer machst du dann *Pull and redeploy*. Mit dem Repo-Secret `PORTAINER_WEBHOOK` (Stack-Webhook) läuft das automatisch.
- **Session neu starten:** Im Web-Terminal `Ctrl-C`, nach 5 s startet sie neu. Alternativ startest du den Container neu.
- **Re-Login:** `docker exec -it claude-raspi rm ~/.claude/.credentials.json`, dann Container neu starten und Schritt 3 wiederholen.
- **Git:** `GH_TOKEN` (fine-grained, nur die nötigen Repos) wird per `gh auth setup-git` für HTTPS genutzt. Die Commit-Identität kommt aus `GIT_USER_NAME`/`GIT_USER_EMAIL`.

## Sicherheit

- Kein Docker-Socket, kein `privileged`, Non-Root-User `claude`.
- Die Permissions erlauben Datei-Edits und Standard-Git. Alles andere muss bestätigt werden, auch vom Handy. Force-Push und das Lesen der Credentials sind verboten.
- ttyd ist nur mit Basic Auth erreichbar und an die LAN-IP gebunden. Leite den Port nicht im Router weiter.
