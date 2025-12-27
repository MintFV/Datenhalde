# Node-RED Security Setup

## Übersicht

Diese Anleitung zeigt, wie du sensible Credentials aus `settings.js` in Environment-Variablen auslagerst.

## Dateien

| Datei | Beschreibung | Git? |
|-------|--------------|------|
| `settings.js` | Bereinigte Konfiguration | ✅ JA |
| `.env.example` | Template für Secrets | ✅ JA |
| `.env` | Echte Secrets | ❌ NEIN |

## Installation

### 1. Backup erstellen

```bash
cd ~/mintfv
cp nodered/data/settings.js nodered/data/settings.js.backup-$(date +%Y%m%d-%H%M%S)
```

### 2. Neue settings.js installieren

```bash
# Bereinigte settings.js herunterladen (Button oben ⬆️)
cp ~/Downloads/settings.js nodered/data/settings.js
```

### 3. .env-Datei erstellen

```bash
# .env.example als Vorlage kopieren
cp .env.example .env

# WICHTIG: .env editieren und deine Werte eintragen!
nano .env
```

### 4. docker-compose.yaml anpassen

Füge zu deinem Node-RED Service hinzu:

```yaml
services:
  nodered:
    # ... bestehende Config ...
    env_file:
      - .env
```

### 5. .gitignore prüfen

```bash
# .env muss in .gitignore stehen!
grep -q "^.env$" .gitignore || echo ".env" >> .gitignore
```

### 6. Node-RED neustarten

```bash
docker restart mintfv-nodered

# Logs prüfen
docker logs -f mintfv-nodered

# Sollte zeigen:
# "Settings file: /data/settings.js"
# KEINE Fehler über fehlende credentialSecret!
```

### 7. Login testen

```bash
# Browser öffnen
https://mintfv.peddy.net/nodered/

# Login:
# Username: admin
# Password: <dein Passwort>
```

## Neue Secrets generieren

### Neues Admin-Passwort

```bash
# 1. Hash generieren
docker exec -it mintfv-nodered npx node-red admin hash-pw

# 2. Passwort eingeben
# 3. Hash kopieren

# 4. In .env eintragen
nano .env
# NODE_RED_ADMIN_PASSWORD_HASH=<neuer-hash>

# 5. Restart
docker restart mintfv-nodered
```

### Neuer Credential Secret

```bash
# 1. Key generieren
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# 2. In .env eintragen
nano .env
# NODE_RED_CREDENTIAL_SECRET=<neuer-key>

# ACHTUNG: Bestehende Flow-Credentials gehen verloren!
# Nur bei Neuinstallation verwenden!
```

## Troubleshooting

### Node-RED startet nicht

```bash
# Logs prüfen
docker logs mintfv-nodered

# Häufige Fehler:
# - "credentialSecret is required" → .env fehlt oder falsch gemountet
# - "Cannot read property 'username'" → Falsches Format in .env
```

### Login funktioniert nicht

```bash
# Passwort-Hash prüfen
docker exec -it mintfv-nodered sh -c 'echo $NODE_RED_ADMIN_PASSWORD_HASH'

# Sollte den Hash zeigen, nicht leer sein
```

### Environment-Variablen werden nicht geladen

```bash
# docker-compose.yaml prüfen
grep -A 5 "nodered:" docker-compose.yaml | grep "env_file"

# Container neu erstellen (nicht nur restart!)
docker-compose up -d --force-recreate nodered
```

## Security Best Practices

1. ✅ `.env` in `.gitignore` halten
2. ✅ `.env.example` ins Git committen (ohne echte Werte)
3. ✅ `credentialSecret` NIEMALS ändern nach dem ersten Start
4. ✅ Admin-Passwort regelmäßig ändern
5. ✅ Backups der `.env` außerhalb des Repos speichern

## Was committen?

```bash
# ✅ JA
git add nodered/data/settings.js
git add .env.example
git add .gitignore

# ❌ NEIN
# .env wird automatisch durch .gitignore ausgeschlossen
```
