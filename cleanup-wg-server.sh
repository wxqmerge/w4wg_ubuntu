#!/bin/bash
# cleanup-wg-server.sh - Remove all WireGuard settings from Ubuntu server
# Run with: sudo bash cleanup-wg-server.sh

set -e

echo "=== WireGuard Server Cleanup ==="

# Stop and disable WireGuard
echo "[1/5] Stopping WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true
echo "Done."

# Remove iptables rules added by WireGuard
echo "[2/5] Removing iptables rules..."
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
echo "Done."

# Remove WireGuard config files
echo "[3/5] Removing config and key files..."
rm -f /etc/wireguard/wg0.conf
rm -f /etc/wireguard/private.key
rm -f /etc/wireguard/public.key
rm -f /etc/wireguard/client-private.key
rm -f /etc/wireguard/client-public.key
echo "Done."

# Uninstall WireGuard package
echo "[4/5] Removing WireGuard package..."
apt-get remove --purge -y wireguard wireguard-tools 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
echo "Done."

# Revert sysctl changes
echo "[5/5] Reverting sysctl changes..."
sed -i '/^net.ipv4.ip_forward=1$/d' /etc/sysctl.conf
# Also remove commented version
sed -i 's/^#net.ipv4.ip_forward=1$/net.ipv4.ip_forward=0/' /etc/sysctl.conf 2>/dev/null || true
sysctl -p 2>/dev/null || true
echo "Done."

echo ""
echo "=== Cleanup Complete ==="
echo "WireGuard has been fully removed from this server."
