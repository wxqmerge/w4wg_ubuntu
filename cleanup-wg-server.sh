#!/bin/bash
# cleanup-wg-server.sh - Remove all WireGuard settings from Ubuntu server (UFW)
# Run with: sudo bash cleanup-wg-server.sh

set -e

echo "=== WireGuard Server Cleanup ==="

# Stop and disable WireGuard
echo "[1/6] Stopping WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true
ip link delete wg0 2>/dev/null || true
echo "Done."

# Remove UFW rules for WireGuard and RDP
echo "[2/6] Removing UFW rules..."
ufw delete allow 51820/udp 2>/dev/null || true
ufw delete allow 3389/tcp 2>/dev/null || true
ufw delete allow in on wg0 2>/dev/null || true
ufw delete route allow in on wg0 out on eth0 2>/dev/null || true
ufw delete route allow in on eth0 out on wg0 2>/dev/null || true
echo "Done."

# Remove MASQUERADE from UFW before.rules
echo "[3/6] Removing MASQUERADE rule..."
if [ -f /etc/ufw/before.rules ]; then
    sed -i '/# WireGuard NAT/d' /etc/ufw/before.rules
    sed -i '/\*nat/,/COMMIT/d' /etc/ufw/before.rules
    echo "  Removed NAT rules from before.rules"
fi

# Revert UFW forward policy
echo "[4/6] Reverting UFW forward policy..."
if [ -f /etc/default/ufw ]; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=DROP/' /etc/default/ufw
    echo "  Reset DEFAULT_FORWARD_POLICY=DROP"
fi

# Remove WireGuard config files
echo "[5/6] Removing config and key files..."
rm -f /etc/wireguard/wg0.conf
rm -f /etc/wireguard/private.key
rm -f /etc/wireguard/public.key
rm -f /etc/wireguard/client-private.key
rm -f /etc/wireguard/client-public.key
echo "Done."

# Uninstall WireGuard package
echo "[6/6] Removing WireGuard package..."
apt-get remove --purge -y wireguard wireguard-tools 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
echo "Done."

echo ""
echo "=== Cleanup Complete ==="
echo "WireGuard has been fully removed from this server."
