#!/bin/bash
# add-wg-client.sh - Add a new WireGuard client to existing server
# Usage: sudo bash add-wg-client.sh [client_number]
# Default: client_number = 2

set -e

CLIENT_NUM="${1:-2}"

# Validate client number
if ! [[ "$CLIENT_NUM" =~ ^[0-9]+$ ]] || [ "$CLIENT_NUM" -lt 2 ]; then
    echo "Error: Client number must be 2 or greater."
    echo "Usage: sudo bash $0 [client_number]"
    echo "Example: sudo bash $0 3"
    exit 1
fi

# Check if WireGuard is installed and running
if ! command -v wg &>/dev/null; then
    echo "Error: WireGuard not installed. Run setup-wg-server.sh first."
    exit 1
fi

if ! ip link show wg0 &>/dev/null; then
    echo "Error: wg0 interface not found. Is WireGuard running?"
    exit 1
fi

# Read server config to find used IPs
USED_IPS=$(wg show wg0 dump 2>/dev/null | awk -F'\t' '{print $1}' | sort -t. -k3,3n -k4,4n | tail -1)
if [ -z "$USED_IPS" ]; then
    NEXT_IP="10.200.0.2"
else
    # Get last octet and increment
    LAST_OCTET=$(echo "$USED_IPS" | awk -F. '{print $4}')
    NEXT_OCTET=$((LAST_OCTET + 1))
    NEXT_IP="10.200.0.${NEXT_OCTET}"
fi

# Check if this specific client number IP is already used
CLIENT_IP="10.200.0.${CLIENT_NUM}"
if wg show wg0 dump 2>/dev/null | awk -F'\t' '{print $1}' | grep -q "^${CLIENT_IP}$"; then
    echo "Error: Client IP ${CLIENT_IP} is already in use."
    echo "Current clients:"
    wg show wg0 dump 2>/dev/null | awk -F'\t' '{print "  " $1}'
    exit 1
fi

# Generate client keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

echo "=== Adding WireGuard Client ${CLIENT_NUM} ==="
echo "Client IP: ${CLIENT_IP}"
echo ""

# Add peer to server config
echo "Adding peer to server config..."
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# Reload WireGuard
echo "Reloading WireGuard..."
wg-quick down wg0
wg-quick up wg0

# Save client private key
CLIENT_KEY_FILE="/etc/wireguard/client-${CLIENT_NUM}.key"
echo "$CLIENT_PRIVATE_KEY" > "$CLIENT_KEY_FILE"
chmod 600 "$CLIENT_KEY_FILE"

# Output client config
echo ""
echo "========================================="
echo "Client ${CLIENT_NUM} Config"
echo "========================================="
echo "Private key saved to: ${CLIENT_KEY_FILE}"
echo ""
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/public.key)

# Read port from config
PORT=$(grep -oP 'ListenPort = \K[0-9]+' /etc/wireguard/wg0.conf)

cat <<EOF
[Interface]
Address = ${CLIENT_IP}/24
PrivateKey = ${CLIENT_PRIVATE_KEY}
DNS = 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0
Endpoint = <YOUR_SERVER_PUBLIC_IP>:${PORT}
PersistentKeepalive = 21
EOF
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Copy the config above to the Windows client"
echo "2. Replace <YOUR_SERVER_PUBLIC_IP> with the server's public IP"
echo "3. Import into WireGuard on Windows"
echo "4. Activate the tunnel"
echo ""
echo "All clients:"
wg show wg0 dump 2>/dev/null | awk -F'\t' '{printf "  %s -> %s\n", $1, $2}'
