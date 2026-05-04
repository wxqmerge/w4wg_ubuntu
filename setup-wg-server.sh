#!/bin/bash
# setup-wg-server.sh - WireGuard Server Setup Script for Ubuntu
# Run with: sudo bash setup-wg-server.sh

set -e

echo "=== WireGuard Server Setup for Ubuntu ==="

# 1. Install WireGuard
echo "[1/6] Installing WireGuard..."
apt-get update
apt-get install -y wireguard iptables

# 2. Generate server key pair
echo "[2/6] Generating server keys..."
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
echo "[3/6] Generating client keys..."
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
echo "[4/6] Creating server configuration..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.200.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
SaveConfig = false

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.200.0.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
echo "Server config written to /etc/wireguard/wg0.conf"

# 5. Enable IP forwarding
echo "[5/6] Enabling IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf 2>/dev/null || true
sysctl -p

# 6. Start WireGuard
echo "[6/6] Starting WireGuard server..."
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
