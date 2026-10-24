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
| `scripts/deploy.sh`, `Makefile` | `make deploy`: legt den Portainer-Stack per API an oder aktualisiert ihn |
| `.github/workflows/build.yml` | baut `ghcr.io/<owner>/claude-raspi` für linux/arm64 |

Volumes: `claude-home` (`/home/claude`: Login, History, Git-Config) und `workspace` (`/workspace`: Repos).

## Einrichtung

1. **Image:** Jeder Push auf `main` baut `ghcr.io/fabianhardt/claude-raspi:latest`. Das Package ist public, Portainer braucht also keine Registry-Credentials.
2. **Konfiguration:** `cp deploy/.env.deploy.example deploy/.env.deploy` und die Werte ausfüllen: Portainer-Access-Token, `TTYD_CREDENTIAL`, `GH_TOKENS`. Die Datei ist gitignored.
3. **Deploy:** `make deploy`. Das Skript `scripts/deploy.sh` legt den Stack in Portainer über die API als Git-Stack aus diesem Repo an. Gibt es den Stack schon, macht es einen Git-Redeploy mit Image-Pull.
4. **Erst-Login:** `http://192.168.2.98:7681` öffnen und dich mit `TTYD_CREDENTIAL` anmelden. In der Claude-Session `/login` ausführen und die angezeigte URL im Browser öffnen. Danach beendest du die Session mit `/exit`. Die Schleife startet dann automatisch `claude remote-control`.
5. **Verbinden:** In claude.ai/code oder in der Claude-App taucht die Session „Raspberry Pi“ auf.

## Betrieb

- **Update von Claude Code:** Der Auto-Updater ist im Container aus. Die Action baut das Image wöchentlich neu. Danach holst du das neue Image mit `make deploy`. Portainer ist nur im LAN erreichbar, deshalb kann die GitHub Action nicht selbst redeployen.
- **Copy & Scroll im Web-Terminal:** Die tmux-Maus ist aus, damit der Browser normal markieren und kopieren kann. Den Verlauf scrollst du mit `Ctrl-b [` und Pfeiltasten oder Bild-auf/ab, mit `q` geht es zurück.
- **Session neu starten:** Im Web-Terminal `Ctrl-C`, nach 5 s startet sie neu. Alternativ startest du den Container neu.
- **Re-Login:** `docker exec -it claude-raspi rm ~/.claude/.credentials.json`, dann Container neu starten und Schritt 3 wiederholen.
- **Git/GitHub:** `GH_TOKENS="FabianHardt=<pat> fabi4711=<pat>"` enthält fine-grained PATs pro Account. Der erste Eintrag ist der Default. Git (HTTPS) wählt den Token über `git-credential-ghtokens` anhand des Repo-Owners. Fremde Owner wie Orgs bekommen den Default. `gh` ist mit allen Accounts eingeloggt, der Default ist aktiv. Wechseln geht mit `gh auth switch -u <account>`. Die Commit-Identität kommt aus `GIT_USER_NAME`/`GIT_USER_EMAIL`.

## Sicherheit

- Kein Docker-Socket, kein `privileged`, Non-Root-User `claude`.
- Die Session läuft im **Auto Mode**: Ein Klassifikator prüft jede Aktion. Sichere Schritte laufen ohne Rückfrage, riskante werden blockiert. Die Umgebungsbeschreibung dafür steht in `config/settings.json` (`autoMode.environment`). Force-Push und das Lesen der Credentials sind zusätzlich hart verboten.
- ttyd ist nur mit Basic Auth erreichbar und an die LAN-IP gebunden. Leite den Port nicht im Router weiter.
