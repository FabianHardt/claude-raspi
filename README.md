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
| `scripts/deploy.sh`, `Makefile` | `make deploy`: legt den Portainer-Stack per API an (Git-Ref `deploy`, Polling) oder aktualisiert ihn |
| `renovate.json` | Renovate: Versionen pinnen, Patch- und Digest-Updates automatisch mergen |
| `.github/workflows/build.yml` | baut `ghcr.io/<owner>/claude-raspi` für linux/arm64 |

Volumes: `claude-home` (`/home/claude`: Login, History, Git-Config) und `workspace` (`/workspace`: Repos).

## Einrichtung

1. **Image:** Jeder Push auf `main` baut `ghcr.io/fabianhardt/claude-raspi:latest`. Das Package ist public, Portainer braucht also keine Registry-Credentials.
2. **Konfiguration:** `cp deploy/.env.deploy.example deploy/.env.deploy` und die Werte ausfüllen: Portainer-Access-Token, `TTYD_CREDENTIAL`, `GH_TOKENS`. Die Datei ist gitignored.
3. **Deploy:** `make deploy`. Das Skript `scripts/deploy.sh` legt den Stack in Portainer über die API als Git-Stack aus diesem Repo an. Gibt es den Stack schon, aktualisiert es Git-Ref, Polling und Env. Einen Redeploy löst es nur aus, wenn sich die Env geändert hat; neue Images kommen über das Polling.
4. **Erst-Login:** `http://192.168.2.98:7681` öffnen und dich mit `TTYD_CREDENTIAL` anmelden. In der Claude-Session `/login` ausführen und die angezeigte URL im Browser öffnen. Danach beendest du die Session mit `/exit`. Die Schleife startet dann automatisch `claude remote-control`.
5. **Verbinden:** In claude.ai/code oder in der Claude-App taucht die Session „Raspberry Pi“ auf.

## Betrieb

- **Updates (Renovate):** Gepinnt sind Claude Code und ttyd (als `ARG` im Dockerfile), das Debian-Basisimage (per Digest) und die GitHub Actions (per SHA). Renovate prüft sie und wartet bei jeder neuen Version 3 Tage (`minimumReleaseAge`). Patch- und Digest-Updates mergt Renovate nachts zwischen 1 und 5 Uhr selbst. Minor- und Major-Updates kommen als PR, den du mergst. Zusätzlich baut die Action einmal pro Woche ohne Cache neu, damit Debian-Security-Updates reinkommen.
- **Rollout:** Nach jedem Image-Build auf `main` schreibt die Action eine `docker-compose.yml` mit Image-Digest auf den Branch `deploy`. Portainer prüft `deploy` alle 5 Minuten und redeployt bei einer Änderung. Weil der Branch erst nach dem Image-Push weiterzieht, gibt es keine Race-Condition. Rollback: einen Commit auf `deploy` reverten. Ein Redeploy startet den Container neu und unterbricht dabei laufende Arbeit. Danach dockt `--continue` wieder an die Session an.
- **Env ändern** (zum Beispiel Tokens): `deploy/.env.deploy` anpassen und `make deploy` ausführen.
- **Polling greift nicht mehr:** In Portainer 2.45 kann ein manueller Git-Redeploy den GitOps-Workflow dauerhaft auf `unknown` setzen; direkt nach dem Speichern ist `unknown` bis zum nächsten Poll normal ([portainer#13298](https://github.com/portainer/portainer/issues/13298)). Dann werden neue `deploy`-Commits nicht mehr ausgerollt. Abhilfe: Stack in Portainer löschen (die Volumes bleiben erhalten) und `make deploy` erneut ausführen. Unter *App Delivery → Workflows* sollte danach alles `Healthy` sein.
- **Copy & Scroll im Web-Terminal:** Die tmux-Maus ist aus, damit der Browser normal markieren und kopieren kann. Den Verlauf scrollst du mit `Ctrl-b [` und Pfeiltasten oder Bild-auf/ab, mit `q` geht es zurück.
- **Session neu starten:** Im Web-Terminal `Ctrl-C`, nach 5 s startet sie neu. Alternativ startest du den Container neu.
- **Re-Login:** `docker exec -it claude-raspi rm ~/.claude/.credentials.json`, dann Container neu starten und Schritt 3 wiederholen.
- **Git/GitHub:** `GH_TOKENS="FabianHardt=<pat> fabi4711=<pat>"` enthält fine-grained PATs pro Account. Der erste Eintrag ist der Default. Git (HTTPS) wählt den Token über `git-credential-ghtokens` anhand des Repo-Owners. Fremde Owner wie Orgs bekommen den Default. `gh` ist mit allen Accounts eingeloggt, der Default ist aktiv. Wechseln geht mit `gh auth switch -u <account>`. Die Commit-Identität kommt aus `GIT_USER_NAME`/`GIT_USER_EMAIL`.

## Sicherheit

- Kein Docker-Socket, kein `privileged`, Non-Root-User `claude`.
- Die Session läuft im **Auto Mode**: Ein Klassifikator prüft jede Aktion. Sichere Schritte laufen ohne Rückfrage, riskante werden blockiert. Die Umgebungsbeschreibung dafür steht in `config/settings.json` (`autoMode.environment`). Force-Push und das Lesen der Credentials sind zusätzlich hart verboten.
- ttyd ist nur mit Basic Auth erreichbar und an die LAN-IP gebunden. Leite den Port nicht im Router weiter.
