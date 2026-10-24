# Umgebung: Claude Code auf dem Raspberry Pi

- Du läufst in einem Docker-Container auf einem Raspberry Pi 5 (arm64, Debian trixie) im Heimnetz.
- Gesteuert wirst du meist per Remote Control vom Handy: halte Antworten knapp und Rückfragen eindeutig.
- Arbeitsverzeichnis ist `/workspace`; Repos werden dort geklont. Nur `/workspace` und `$HOME` sind persistent.
- Kein Docker-Zugriff, kein root/sudo. Fehlende Tools lieber projektlokal installieren (`python3 -m venv`, `npm install`).
- Heimnetz-Dienste sind direkt per LAN-IP erreichbar; Zugangsdaten stehen nur in Umgebungsvariablen.

## Git
- Nie direkt auf den Default-Branch committen, sondern einen Feature-Branch anlegen.
- Kein Merge, Push oder Rebase in den Default-Branch ohne ausdrückliche Zustimmung.
- Keine AI-Attribution (kein `Co-Authored-By: Claude`, kein „Generated with …“) in Commits oder PRs.
