#!/usr/bin/env bash
# mail-lab install script

set -euo pipefail

echo ""
echo "  [mail-lab] Installing..."
echo ""
echo "  This plugin creates three VMs for practicing email server administration:"
echo ""
echo "    1. mail-lab-server  — Mail Server VM"
echo "       Runs Postfix (SMTP) and Dovecot (IMAP)"
echo "       Handles mail delivery for domain mail.lab"
echo ""
echo "    2. mail-lab-client1 — Client VM (alice)"
echo "       Pre-configured mutt client for user alice"
echo "       Send/receive mail via the server"
echo ""
echo "    3. mail-lab-client2 — Client VM (bob)"
echo "       Pre-configured mutt client for user bob"
echo "       Send/receive mail via the server"
echo ""
echo "  What you will learn:"
echo "    - How to configure Postfix as an SMTP server"
echo "    - How to configure Dovecot as an IMAP server"
echo "    - How to send and receive mail between users"
echo "    - How to read and interpret mail server logs"
echo "    - How to use mutt as a terminal mail client"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [mail-lab] Installation complete."
echo "  Run with: qlab run mail-lab"
