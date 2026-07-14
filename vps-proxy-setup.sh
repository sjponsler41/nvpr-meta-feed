#!/bin/bash
# NVPR Streamline proxy — one-paste setup for a fresh Ubuntu 24.04 droplet.
# Run as root (DigitalOcean web console logs you in as root already).
#
# What it does:
#   - installs tinyproxy (a small HTTP proxy)
#   - locks it down: password required + ONLY streamlinevrs.com reachable through it
#   - opens the firewall for SSH + the proxy port
#   - prints the finished proxy URL at the end (that's what goes in the GitHub secret)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq tinyproxy ufw curl >/dev/null

# random 24-char password, generated here on YOUR server
PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)

cat >/etc/tinyproxy/tinyproxy.conf <<EOF
User tinyproxy
Group tinyproxy
Port 8888
Timeout 120
MaxClients 20
LogLevel Notice
LogFile "/var/log/tinyproxy/tinyproxy.log"
PidFile "/run/tinyproxy/tinyproxy.pid"
# password is the gate (GitHub runners have no fixed source IP)
BasicAuth nvpr ${PASS}
Allow 0.0.0.0/0
# HTTPS CONNECT only to port 443
ConnectPort 443
# destination lock: ONLY streamlinevrs.com may be reached through this proxy
Filter "/etc/tinyproxy/filter"
FilterDefaultDeny Yes
EOF

cat >/etc/tinyproxy/filter <<'EOF'
streamlinevrs\.com
EOF

systemctl restart tinyproxy
systemctl enable tinyproxy >/dev/null 2>&1 || true

ufw allow OpenSSH >/dev/null
ufw allow 8888/tcp >/dev/null
ufw --force enable >/dev/null

PUBIP=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com)

# stash the credentialed URL root-only; NOT printed to the console
echo "http://nvpr:${PASS}@${PUBIP}:8888" > /root/proxy-url.txt
chmod 600 /root/proxy-url.txt

echo ""
echo "=================================================================="
echo " DONE."
echo ""
echo " Droplet IP (for the PartnerX allowlist, IPv4):"
echo "      ${PUBIP}"
echo ""
echo " Proxy URL (for the GitHub FIXIE_URL secret) is saved in a"
echo " root-only file. To display it, run:"
echo "      cat /root/proxy-url.txt"
echo "=================================================================="
