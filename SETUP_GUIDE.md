# WireGuard Ubuntu Server → Windows Client RDP Setup Guide

## Overview
This setup creates a WireGuard VPN tunnel between an Ubuntu server and a Windows client,
allowing you to RDP into the Ubuntu server via the VPN IP (10.200.0.1).

## Architecture
```
Windows Client (10.200.0.2) <--WireGuard VPN--> Ubuntu Server (10.200.0.1)
                                                        |
                                                    RDP (3389)
```

## Prerequisites
- Ubuntu Server (20.04/22.04/24.04)
- Windows 10/11 client
- Both machines can reach each other over the internet

---

## Part 1: Ubuntu Server Setup

### Step 1: Run the setup script
```bash
sudo bash setup-wg-server.sh
```

This script will:
1. Install WireGuard
2. Generate server and client key pairs
3. Create the server configuration
4. Enable IP forwarding
5. Start the WireGuard tunnel
6. Output the client config for Windows

### Step 2: Install Ubuntu Desktop (if not already installed)
```bash
sudo apt install -y ubuntu-desktop
# OR for lighter option:
# sudo apt install -y xubuntu-desktop
```

### Step 3: Install and configure XRDP (remote desktop)
```bash
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Fix color depth issue
echo "session=xfce" | sudo tee /etc/xrdp/sesman.ini

# Add user to xrdp-users group (replace 'yourusername')
sudo adduser yourusername xrdp-users

# If using UFW firewall
sudo ufw allow 3389/tcp
```

### Step 4: Verify WireGuard is running
```bash
wg show
wg-quick show wg0
```

---

## Part 2: Windows Client Setup

### Step 1: Install WireGuard Tunnel
Download from: https://www.wireguard.com/install/
- Windows 10/11: Download the latest installer from the official site

### Step 2: Import the client config
1. Open WireGuard
2. Click "Add Tunnel" → "Add tunnel from file"
3. Select the `wg0-client-windows.conf` file (fill in the keys first)
4. Activate the tunnel

### Step 3: Alternatively, manually create the config
1. Open WireGuard
2. Click "Add Tunnel" → "Add empty tunnel"
3. Name it "Ubuntu-VPN"
4. Click "Configure tunnel"
5. Paste the config from the server script output
6. Fill in:
   - `PrivateKey` = client private key from server output
   - `PublicKey` = server public key from server output
   - `Endpoint` = your Ubuntu server's public IP : 51820
7. Click OK, then "Activate"

---

## Part 3: RDP Connection

### From Windows to Ubuntu Server

#### Option A: Using Windows Remote Desktop (mstsc)
1. Press Win + R, type: `mstsc`
2. Enter the VPN IP: `10.200.0.1`
3. Click Connect
4. Log in with your Ubuntu credentials

#### Option B: Using xrdp client on Windows
If mstsc doesn't work well:
1. Download "rdp client" from Microsoft Store
2. Connect to `10.200.0.1`

---

## Troubleshooting

### Server side
```bash
# Check WireGuard status
sudo wg show
sudo journalctl -u wg-quick@wg0 -f

# Check iptables rules
sudo iptables -L -n -v

# Restart WireGuard
sudo wg-quick down wg0
sudo wg-quick up wg0

# Check if port 51820 is open
sudo ufw status
# OR
sudo iptables -L INPUT -n -v
```

### Windows side
```
# Check WireGuard connection
# Open WireGuard app → should show "Tunnel Active"

# Test VPN connectivity
ping 10.200.0.1

# Test RDP
mstsc /v:10.200.0.1
```

### Common issues
1. **Connection timeout**: Check firewall on server (port 51820 UDP)
2. **No internet after connecting**: Check IP forwarding is enabled
3. **RDP won't connect**: Verify xrdp is running (`systemctl status xrdp`)
4. **Key mismatch**: Regenerate keys on server and update client config

---

## Firewall Configuration

### UFW (Ubuntu)
```bash
sudo ufw allow 51820/udp   # WireGuard
sudo ufw allow 3389/tcp    # RDP/xrdp
sudo ufw enable
```

### Windows Firewall (if needed)
WireGuard usually handles this automatically. If not:
- Allow WireGuard through Windows Firewall
- Ensure outbound UDP 51820 is allowed

---

## Files Reference
| File | Purpose |
|------|---------|
| `setup-wg-server.sh` | Server setup script (run on Ubuntu) |
| `wg0-server.conf` | Server WireGuard config template |
| `wg0-client-windows.conf` | Client config template for Windows |
