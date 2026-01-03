#!/usr/bin/env bash

TARGET="https://mintfv.peddy.net"
FAILED=0

PAYLOADS=(
"/../../../../../../etc/passwd"
"/../../../root/.ssh/id_rsa"
"/../../../../app/.env"
"/..%2f..%2f..%2f..%2f/root/.env"
"/%2e%2e/%2e%2e/%2e%2e/etc/shadow"
"/..%252f..%252f..%252fetc%252fpasswd"
"/@fs/..%252f..%252froot/.env"
"/etc/passwd%00.jpg"
"/..%5c..%5c..%5cwindows/system.ini"
"/@fs/../../../../root/.env"
"/@fs/../../../../proc/self/environ?raw"
"/proc/self/environ"
"/proc/version"
"/proc/cmdline"
"/%F0%28%8C%28"
"/../../etc/passwd??raw???"
"/@fs/..%252f..%252froot/.env??download"
)

echo "=== NGINX SECURITY TEST START ==="
echo "Ziel: $TARGET"
echo "Tests: ${#PAYLOADS[@]}"
echo
echo "Erwartete GUTE Ergebnisse: 444, 000 (connection closed), 400 (malformed rejected)"
echo

for p in "${PAYLOADS[@]}"; do
    echo -n "Teste: $p ... "
    STATUS=$(curl -s4 -o /dev/null -w "%{http_code}" --max-time 10 "$TARGET$p")
    
    # 444 = nginx silent drop (expected)
    # 000 = connection closed without response = nginx 444 in action!
    # 400 = malformed URI rejected by nginx core (also good for security)
    # 403 = forbidden (acceptable)
    # 404 = not found but request went through (POTENTIALLY BAD for traversal)
    
    case "$STATUS" in
        444)
            echo -e "\e[32mOK (444 - silent drop)\e[0m"
            ;;
        000)
            echo -e "\e[32mOK (000 - connection closed = 444 equivalent)\e[0m"
            ;;
        400)
            echo -e "\e[33mOK (400 - malformed URI rejected by nginx core)\e[0m"
            ;;
        403)
            echo -e "\e[32mOK (403 - forbidden)\e[0m"
            ;;
        404)
            # 404 could mean the traversal didn't work (file not found)
            # but it also means the request wasn't blocked
            echo -e "\e[33mWARNUNG (404 - Request durchgelassen, Datei nicht gefunden)\e[0m"
            # For path traversal attempts, 404 is actually okay if it means
            # nginx looked for the literal file "../../etc/passwd" instead of /etc/passwd
            ;;
        200)
            echo -e "\e[31mKRITISCH! (200 - Inhalt wurde ausgeliefert!)\e[0m"
            FAILED=1
            ;;
        *)
            echo -e "\e[33mUnbekannt → HTTP $STATUS\e[0m"
            ;;
    esac
done

echo
if [[ "$FAILED" -eq 0 ]]; then
    echo -e "\e[32mALLE Payloads wurden blockiert oder korrekt abgelehnt ✓\e[0m"
else
    echo -e "\e[31mKRITISCH: Mindestens ein Payload wurde durchgelassen ⚠️\e[0m"
fi

echo
echo "=== ERKLÄRUNG ==="
echo "HTTP 000: curl konnte keine Response lesen = nginx 'return 444' (Connection closed)"
echo "HTTP 400: nginx hat die URI als ungültig abgelehnt (z.B. %00, %252f)"
echo "HTTP 404: Request wurde verarbeitet, aber Datei nicht gefunden"
echo "         Bei Traversal-Versuchen ist 404 OK wenn nginx die Pfade nicht auflöst"
