#!/usr/bin/env bash

# TARGET="https://95.216.195.221"   # oder deine Domain
TARGET="https://mintfv.peddy.net"   # oder deine Domain
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

for p in "${PAYLOADS[@]}"; do
    echo -n "Teste: $p ... "
    STATUS=$(curl -s4 -o /dev/null -w "%{http_code}" "$TARGET$p")
    if [[ "$STATUS" == "444" ]]; then
        echo -e "\e[32mOK (444)\e[0m"
    else
        echo -e "\e[31mFEHLER → HTTP $STATUS\e[0m"
        FAILED=1
    fi
done

echo
if [[ "$FAILED" -eq 0 ]]; then
    echo -e "\e[32mALLE Payloads korrekt mit 444 geblockt ✓\e[0m"
else
    echo -e "\e[31mMindestens ein Test ist fehlgeschlagen ⚠️\e[0m"
fi
