#!/bin/bash
# setup-wg-server.sh - WireGuard Server Setup Script for Ubuntu
# Run with: sudo bash setup-wg-server.sh

set -e

echo "=== WireGuard Server Setup for Ubuntu ==="

# 1. Install WireGuard
echo "[1/7] Installing WireGuard..."
apt-get update
apt-get install -y wireguard ufw

# 2. Generate server key pair
echo "[2/7] Generating server keys..."
if [ ! -f /etc/wireguard/private.key ]; then
    wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
    chmod 600 /etc/wireguard/private.key
    echo "Server private key: $(cat /etc/wireguard/private.key)"
    echo "Server public key: $(cat /etc/wireguard/public.key)"
else
    echo "Keys already exist. Skipping generation."
fi

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/private.key)

# 3. Generate client key pair
echo "[3/7] Generating client keys..."
if [ ! -f /etc/wireguard/client-private.key ]; then
    wg genkey | tee /etc/wireguard/client-private.key | wg pubkey > /etc/wireguard/client-public.key
    chmod 600 /etc/wireguard/client-private.key
    echo "Client private key: $(cat /etc/wireguard/client-private.key)"
    echo "Client public key: $(cat /etc/wireguard/client-public.key)"
else
    echo "Client keys already exist. Skipping generation."
fi

CLIENT_PUBLIC_KEY=$(cat /etc/wireguard/client-public.key)

# 4. Create server config
echo "[4/7] Creating server configuration..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.200.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = ufw route allow in on wg0 out on eth0; ufw route allow in on eth0 out on wg0; ufw allow in on wg0
PostDown = ufw route deny in on wg0 out on eth0; ufw route deny in on eth0 out on wg0
SaveConfig = false

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.200.0.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
echo "Server config written to /etc/wireguard/wg0.conf"

# 5. Configure UFW firewall
echo "[5/7] Configuring UFW firewall..."
ufw_default=$(grep '^DEFAULT_FORWARD_POLICY=' /etc/default/ufw | cut -d= -f2)
if [ "$ufw_default" != "ACCEPT" ]; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=ACCEPT/' /etc/default/ufw
    echo "  Set DEFAULT_FORWARD_POLICY=ACCEPT"
fi

# Add MASQUERADE to UFW before.rules
if ! grep -q 'ufw-before-forward' /etc/ufw/before.rules 2>/dev/null; then
    cat >> /etc/ufw/before.rules <<'UFW_NAT'
# WireGuard NAT
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.200.0.0/24 -o eth0 -j MASQUERADE
COMMIT
UFW_NAT
    echo "  Added MASQUERADE rule to before.rules"
fi

# Allow WireGuard and RDP ports
ufw allow 51820/udp 2>/dev/null || true
ufw allow 3389/tcp 2>/dev/null || true

# Enable UFW if not already enabled
ufw_status=$(ufw status | head -1)
if [[ "$ufw_status" != *"Status: active"* ]]; then
    echo "y" | ufw enable
    echo "  UFW enabled"
else
    echo "  UFW already active"
fi
echo "Done."

# 6. Enable IP forwarding
echo "[6/7] Enabling IP forwarding..."
if [ ! -f /etc/sysctl.conf ]; then
    touch /etc/sysctl.conf
    echo "  Created /etc/sysctl.conf"
fi
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p 2>/dev/null || true

# 7. Start WireGuard
echo "[7/7] Starting WireGuard server..."
wg-quick up wg0
systemctl enable wg-quick@wg0.service

# 7. Generate client config
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Client config (save this for Windows):"
echo "---------------------------------------"
CLIENT_PRIVATE_KEY=$(cat /etc/wireguard/client-private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/public.key)
cat <<EOF
[Interface]
Address = 10.200.0.2/24
PrivateKey = ${CLIENT_PRIVATE_KEY}
DNS = 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0
Endpoint = <YOUR_SERVER_PUBLIC_IP>:51820
PersistentKeepalive = 21

EOF
echo "---------------------------------------"
echo ""
echo "Next steps:"
echo "1. Copy the client config above to your Windows machine"
echo "2. Install WireGuard on Windows"
echo "3. Import the config and connect"
echo "4. RDP to your Ubuntu server: mstsc /v:10.200.0.1"
echo ""
echo "Server IP on VPN: 10.200.0.1"
echo "Client IP on VPN: 10.200.0.2"
