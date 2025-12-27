# 🔧 MQTT ACL Troubleshooting Guide

> Häufige Probleme und Lösungen bei der Multi-Tenant MQTT Access Control

---

## 📋 Inhaltsverzeichnis

- [Quick Checklist](#-quick-checklist)
- [ACL funktioniert nicht](#-acl-funktioniert-nicht)
- [Client zeigt SUCCESS aber Nachricht kommt nicht an](#-client-zeigt-success-aber-nachricht-kommt-nicht-an)
- [Permissions Probleme](#️-permissions-probleme)
- [Syntax-Fehler in ACL-Datei](#-syntax-fehler-in-acl-datei)
- [Debug-Logging aktivieren](#-debug-logging-aktivieren)
- [Häufige Fehler](#-häufige-fehler)
- [Test-Checkliste](#-test-checkliste)

---

## ✅ Quick Checklist

Wenn ACLs nicht funktionieren, prüfe in dieser Reihenfolge:

- [ ] Container läuft: `docker compose ps mosquitto`
- [ ] ACL-Datei existiert: `ls -la mosquitto/config/mosquitto.acl`
- [ ] Permissions korrekt: `chmod 640 mosquitto/config/mosquitto.acl`
- [ ] mosquitto.conf verweist auf ACL: `grep acl_file mosquitto/config/mosquitto.conf`
- [ ] Broker neu geladen: `docker compose restart mosquitto`
- [ ] Logs prüfen: `docker compose logs --tail=50 mosquitto`
- [ ] Test mit Logs: [siehe unten](#richtige-test-methode)

---

## 🚫 ACL funktioniert nicht

### Symptom
Client kann Topics lesen/schreiben, obwohl ACL es verbieten sollte.

### Ursachen & Lösungen

#### 1. ACL-Datei wird nicht geladen

**Prüfen:**
```bash
docker compose exec mosquitto cat /mosquitto/config/mosquitto.conf | grep acl_file
```

**Sollte zeigen:**
```conf
acl_file /mosquitto/config/mosquitto.acl
```

**Falls nicht:**
```bash
# Editiere mosquitto.conf
nano mosquitto/config/mosquitto.conf

# Füge hinzu:
allow_anonymous false
password_file /mosquitto/config/mosquitto.passwd
acl_file /mosquitto/config/mosquitto.acl

# Broker neu laden
docker compose restart mosquitto
```

#### 2. ACL-Datei leer oder fehlerhaft

**Prüfen:**
```bash
docker compose exec mosquitto cat /mosquitto/config/mosquitto.acl | head -20
```

**Falls leer:**
```bash
# Kopiere Template
cp mosquitto/config/mosquitto.acl.example mosquitto/config/mosquitto.acl

# Setze Permissions
chmod 640 mosquitto/config/mosquitto.acl
chgrp 2100 mosquitto/config/mosquitto.acl

# Neu laden
docker compose restart mosquitto
```

#### 3. allow_anonymous aktiviert

**Prüfen:**
```bash
docker compose exec mosquitto grep allow_anonymous /mosquitto/config/mosquitto.conf
```

**Falls `true`:**
```bash
# Ändere zu false
nano mosquitto/config/mosquitto.conf
# allow_anonymous false

docker compose restart mosquitto
```

#### 4. Broker nicht neu geladen

**Nach jeder ACL-Änderung:**
```bash
docker compose restart mosquitto

# Validiere
docker compose logs --tail=20 mosquitto | grep -E "(ACL|acl_file)"
```

---

## ✅ Client zeigt SUCCESS aber Nachricht kommt nicht an

### ⚠️ DAS IST NORMALES VERHALTEN bei QoS 0!

**Grund:** MQTT QoS 0 = "Fire and Forget"
- Client sendet Nachricht
- Wartet NICHT auf Bestätigung
- Zeigt IMMER "SUCCESS"
- **Auch wenn Broker die Nachricht per ACL blockiert!**

### Richtige Test-Methode

```bash
# Terminal 1: Logs in Echtzeit
docker compose logs -f mosquitto | grep -E "(Received|Denied)"

# Terminal 2: Publish durchführen
mosquitto_pub -h mintfv.peddy.net -p 1883 \
  -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-b/test" -m "test"

# Terminal 1 sollte zeigen:
# Denied PUBLISH from tenant-a-sensor01 (..., 'tenant/tenant-b/test')
# → ✓ ACL funktioniert!
```

### Alternative: QoS 1 verwenden

```bash
# QoS 1 gibt Fehler bei ACL-Deny zurück
mosquitto_pub -q 1 -h mintfv.peddy.net -p 1883 \
  -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-b/test" -m "test"

# Bei ACL-Deny: Exit-Code 1
# Bei Success: Exit-Code 0
```

**Für Automatisierung:**
```bash
if ! mosquitto_pub -q 1 -u user -P pass -t topic -m msg; then
    echo "ERROR: Publish wurde blockiert oder fehlgeschlagen"
fi
```

---

## 🛡️ Permissions Probleme

### Symptom
```
Error: Unable to open ACL file /mosquitto/config/mosquitto.acl
```

### Lösung

```bash
# Prüfe aktuelle Permissions
ls -la mosquitto/config/mosquitto.acl

# Sollte sein: -rw-r----- 2003:2100
sudo chown 2003:2100 mosquitto/config/mosquitto.acl
sudo chmod 640 mosquitto/config/mosquitto.acl

# Validierung
docker compose restart mosquitto
docker compose logs --tail=20 mosquitto
```

### Warum 640 und nicht 644?

- `640` = Owner kann lesen/schreiben, Gruppe nur lesen
- `600` = Zu restriktiv (nginx kann nicht lesen bei shared setup)
- `644` = World-readable (Sicherheitsrisiko - Passwörter!)
- **Richtig:** `640` mit GID 2100 (ssl-certs group)

---

## 📝 Syntax-Fehler in ACL-Datei

### Häufige Fehler

#### ❌ Fehler 1: Falsche Wildcard-Syntax

```acl
# FALSCH
user sensor01
topic write tenant/tenant-a/sensor01/*  # * ist falsch!

# RICHTIG
user sensor01
topic write tenant/tenant-a/sensor01/#  # # für MQTT wildcards
```

#### ❌ Fehler 2: "topic deny #" verwenden

```acl
# FALSCH - blockiert ALLES inkl. erlaubter Regeln!
user sensor01
topic deny #
topic write tenant/tenant-a/sensor01/#  # Hat keine Wirkung mehr!

# RICHTIG - Mosquitto hat default-deny
user sensor01
topic write tenant/tenant-a/sensor01/#
# Alles andere automatisch denied!
```

#### ❌ Fehler 3: Falsche Reihenfolge

```acl
# FALSCH - first match wins
topic write sensors/#
user admin
# admin kann NICHTS, weil keine user-Zeile davor!

# RICHTIG
user admin
topic write sensors/#
```

#### ❌ Fehler 4: Leerzeichen/Tabs

```acl
# FALSCH - Tab vor "topic"
user admin
	topic write #

# RICHTIG - Keine führenden Spaces/Tabs
user admin
topic write #
```

### ACL-Syntax Validierung

```bash
# Teste Syntax (kein offizielles Tool, aber hilft)
docker compose exec mosquitto mosquitto_sub --help &>/dev/null && echo "OK"

# Prüfe Logs auf Syntax-Fehler
docker compose logs mosquitto | grep -i "error\|warning"

# Erwartete Warnungen (OK):
# "Warning: File mosquitto.acl owner is not root"  # OK wenn UID 2003
```

---

## 🔍 Debug-Logging aktivieren

### Temporär für Debugging

Editiere `mosquitto/config/mosquitto.conf`:

```conf
# Alle Log-Types aktivieren
log_type all
log_type error
log_type warning
log_type notice
log_type information
log_type subscribe
log_type unsubscribe
log_type websockets
log_type debug  # Sehr verbose!
```

**Neu laden:**
```bash
docker compose restart mosquitto

# Logs in Echtzeit
docker compose logs -f mosquitto
```

### Wichtige Log-Messages

**ACL funktioniert:**
```
Denied PUBLISH from <user> (<ip>, <qos>, '<topic>')
Denied SUBSCRIBE from <user> (<ip>, '<topic>')
```

**Authentifizierung funktioniert:**
```
New connection from <ip> on port 1883.
New client connected from <ip> as <clientid> (p2, c1, k60, u'<username>').
```

**ACL-Datei geladen:**
```
Opening ipv4 listen socket on port 1883.
mosquitto version 2.0.22 running
```

### Nach Debugging: Logging reduzieren

```conf
# Nur Errors in Produktion
log_type error
log_type warning
```

---

## 🐛 Häufige Fehler

### 1. Umlaute in Benutzernamen/Passwörtern

**Problem:** mosquitto_passwd unterstützt keine Umlaute zuverlässig

```bash
# ❌ FALSCH
mosquitto_passwd -b file benutzername passwört123

# ✅ RICHTIG - nur ASCII
mosquitto_passwd -b file username password123
```

### 2. CVE-2017-7650: pattern vs topic

**Sicherheitsrisiko:**
```acl
# ❌ GEFÄHRLICH - pattern mit %u/%c ersetzbar
pattern write sensors/%u/#
# Angreifer kann Benutzername manipulieren!

# ✅ SICHERER - explizite user-Zeilen
user sensor01
topic write sensors/sensor01/#
```

**Regel:** Verwende `pattern` nur wenn wirklich nötig und verstanden!

### 3. Passwort-Hash in ACL statt Passwort-Datei

```acl
# ❌ FALSCH - ACL enthält keine Passwörter!
user admin:$7$101$hash
topic write #

# ✅ RICHTIG
# mosquitto.passwd:
admin:$7$101$hash...

# mosquitto.acl:
user admin
topic write #
```

### 4. Topic-Namespace Kollisionen

```acl
# ❌ KONFLIKT - sensor01 in beiden Tenants
user tenant-a-sensor01
topic write sensors/sensor01/#

user tenant-b-sensor01
topic write sensors/sensor01/#
# Beide schreiben in gleichen Topic!

# ✅ RICHTIG - Tenant-Namespaces
user tenant-a-sensor01
topic write tenant/tenant-a/sensor01/#

user tenant-b-sensor01
topic write tenant/tenant-b/sensor01/#
```

---

## ✅ Test-Checkliste

Führe diese Tests nach jeder ACL-Änderung durch:

### 1. Authentifizierung

```bash
# Test 1: Korrektes Passwort
mosquitto_pub -h localhost -p 1883 -u admin -P admin123 -t test -m "ok"
# Erwarte: SUCCESS

# Test 2: Falsches Passwort
mosquitto_pub -h localhost -p 1883 -u admin -P wrong -t test -m "ok"
# Erwarte: Connection error (Auth failed)

# Test 3: Unbekannter User
mosquitto_pub -h localhost -p 1883 -u unknown -P pass -t test -m "ok"
# Erwarte: Connection error (Auth failed)
```

### 2. ACL Positive Tests (Sollte funktionieren)

```bash
# Erlaubter Publish
mosquitto_pub -u tenant-a-admin -P alpha2024! \
  -t "tenant/tenant-a/test" -m "ok"

# Prüfe Log:
docker compose logs --tail=5 mosquitto | grep "Received PUBLISH"
# ✓ Sollte Publish zeigen
```

### 3. ACL Negative Tests (Sollte blockiert werden)

```bash
# Verbotener Publish
mosquitto_pub -u tenant-a-sensor01 -P sensor01 \
  -t "tenant/tenant-b/test" -m "hack"

# Prüfe Log:
docker compose logs --tail=5 mosquitto | grep "Denied PUBLISH"
# ✓ Sollte "Denied" zeigen
```

### 4. Cross-Tenant Isolation

```bash
# Tenant A → Tenant B
mosquitto_pub -u tenant-a-admin -P alpha2024! \
  -t "tenant/tenant-b/admin" -m "cross"

# Prüfe Log: Denied PUBLISH
# ✓ Sollte blockiert sein
```

### 5. Admin-Rechte

```bash
# Master kann überall schreiben
mosquitto_pub -u master-admin -P master2024! \
  -t "tenant/tenant-a/test" -m "ok"
mosquitto_pub -u master-admin -P master2024! \
  -t "tenant/tenant-b/test" -m "ok"

# Prüfe Logs: Beide sollten Received PUBLISH zeigen
```

### 6. Automatisiertes Test-Skript

```bash
# Vollständige ACL-Validierung
./test-acl.sh

# Nur bestimmter Tenant
./test-acl.sh --tenant tenant-a

# Mit Debug-Output
./test-acl.sh --verbose
```

---

## 📞 Weitere Hilfe

- **MOSQUITTO.md**: Vollständige Dokumentation
- **TENANT-CREDENTIALS.md**: Passwörter und Benutzer (git-ignored)
- **test-acl.sh**: Automatisiertes Test-Skript
- **Docker Logs**: `docker compose logs -f mosquitto`

### Nützliche Commands

```bash
# Container Status
docker compose ps mosquitto

# Live-Logs
docker compose logs -f mosquitto

# Konfiguration prüfen
docker compose exec mosquitto cat /mosquitto/config/mosquitto.conf

# ACL-Datei prüfen
docker compose exec mosquitto cat /mosquitto/config/mosquitto.acl

# Neustart
docker compose restart mosquitto

# Kompletter Rebuild
docker compose down mosquitto
docker compose up -d mosquitto
```

---

## 🔗 Referenzen

- [MQTT Specification - QoS Levels](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718101)
- [HiveMQ: MQTT Essentials - QoS](https://www.hivemq.com/blog/mqtt-essentials-part-6-mqtt-quality-of-service-levels/)
- [Mosquitto ACL Documentation](https://mosquitto.org/man/mosquitto-conf-5.html)
- [CVE-2017-7650: ACL Pattern Vulnerability](https://mosquitto.org/2017/05/security-advisory-cve-2017-7650/)

---

**Letzte Aktualisierung:** {{ date }}  
**MintFV Version:** 1.0
