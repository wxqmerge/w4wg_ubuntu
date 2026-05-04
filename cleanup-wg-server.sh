#!/bin/bash
# cleanup-wg-server.sh - Remove all WireGuard settings from Ubuntu server (UFW)
# Run with: sudo bash cleanup-wg-server.sh

set -e

echo "=== WireGuard Server Cleanup ==="

# 1. Stop and disable WireGuard service
echo "[1/7] Stopping WireGuard service..."
systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true
echo "Done."

# 2. Remove config file first (wg-quick down needs it, then delete)
echo "[2/7] Removing config file..."
if [ -f /etc/wireguard/wg0.conf ]; then
    cp /etc/wireguard/wg0.conf /tmp/wg0.conf.bak 2>/dev/null || true
    # Bring it down while config exists
    wg-quick down wg0 2>/dev/null || true
    rm -f /etc/wireguard/wg0.conf
    rm -f /tmp/wg0.conf.bak
    echo "  Config removed, interface should be down"
else
    echo "  No config found, trying to bring down anyway..."
    wg-quick down wg0 2>/dev/null || true
fi
echo "Done."

# 3. Force delete the interface if still present
echo "[3/7] Force deleting wg0 interface..."
for i in 1 2 3; do
    if ip link show wg0 >/dev/null 2>&1; then
        echo "  Attempt $i: deleting wg0..."
        ip link delete wg0 2>/dev/null || true
        sleep 1
    else
        echo "  wg0 already gone"
        break
    fi
done
echo "Done."

# 4. Remove UFW rules for WireGuard and RDP
echo "[4/7] Removing UFW rules..."
ufw delete allow 51820/udp 2>/dev/null || true
ufw delete allow 3389/tcp 2>/dev/null || true
ufw delete allow in on wg0 2>/dev/null || true
ufw delete route allow in on wg0 out on eth0 2>/dev/null || true
ufw delete route allow in on eth0 out on wg0 2>/dev/null || true
echo "Done."

# 5. Remove MASQUERADE from UFW before.rules
echo "[5/7] Removing MASQUERADE rule..."
if [ -f /etc/ufw/before.rules ]; then
    sed -i '/# WireGuard NAT/d' /etc/ufw/before.rules
    sed -i '/\*nat/,/COMMIT/d' /etc/ufw/before.rules
    echo "  Removed NAT rules from before.rules"
fi

# 6. Revert UFW forward policy
echo "  Reverting UFW forward policy..."
if [ -f /etc/default/ufw ]; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=DROP/' /etc/default/ufw
    echo "  Reset DEFAULT_FORWARD_POLICY=DROP"
fi
echo "Done."

# 7. Remove WireGuard key files
echo "  Removing key files..."
rm -f /etc/wireguard/private.key
rm -f /etc/wireguard/public.key
rm -f /etc/wireguard/client-private.key
rm -f /etc/wireguard/client-public.key
echo "Done."

# 8. Uninstall WireGuard package
echo "[6/7] Removing WireGuard package..."
apt-get remove --purge -y wireguard wireguard-tools 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
echo "Done."

# 9. Revert sysctl changes
echo "[7/7] Reverting sysctl changes..."
if [ -f /etc/sysctl.conf ]; then
    sed -i '/^net.ipv4.ip_forward=1$/d' /etc/sysctl.conf
    sed -i 's/^#net.ipv4.ip_forward=1$/net.ipv4.ip_forward=0/' /etc/sysctl.conf 2>/dev/null || true
    sysctl -p 2>/dev/null || true
    echo "  Cleaned sysctl.conf"
else
    echo "  No sysctl.conf found, skipping"
fi
echo "Done."

echo ""
echo "=== Cleanup Complete ==="
echo "WireGuard has been fully removed from this server."
echo ""
echo "Verify: ip addr show wg0"
echo "Expected: 'Device "wg0" does not exist'"
