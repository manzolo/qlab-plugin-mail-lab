#!/usr/bin/env bash
# mail-lab run script — boots three VMs for mail server labs (Postfix + Dovecot)

set -euo pipefail

PLUGIN_NAME="mail-lab"
SERVER_VM="mail-lab-server"
CLIENT1_VM="mail-lab-client1"
CLIENT2_VM="mail-lab-client2"

# Internal LAN — direct VM-to-VM link via QEMU socket multicast
INTERNAL_MCAST="230.0.0.1:10200"
SERVER_INTERNAL_IP="192.168.100.1"
CLIENT1_INTERNAL_IP="192.168.100.2"
CLIENT2_INTERNAL_IP="192.168.100.3"
SERVER_LAN_MAC="52:54:00:00:07:01"
CLIENT1_LAN_MAC="52:54:00:00:07:02"
CLIENT2_LAN_MAC="52:54:00:00:07:03"

echo "============================================="
echo "  mail-lab: Mail Server Lab (Postfix + Dovecot)"
echo "============================================="
echo ""
echo "  This lab creates three VMs connected by an"
echo "  internal LAN (192.168.100.0/24):"
echo ""
echo "    1. $SERVER_VM"
echo "       Internal IP: $SERVER_INTERNAL_IP"
echo "       Postfix (SMTP) + Dovecot (IMAP)"
echo ""
echo "    2. $CLIENT1_VM"
echo "       Internal IP: $CLIENT1_INTERNAL_IP"
echo "       Mail client for user alice"
echo ""
echo "    3. $CLIENT2_VM"
echo "       Internal IP: $CLIENT2_INTERNAL_IP"
echo "       Mail client for user bob"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 768)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by all VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  All VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for all VMs"
echo ""

# --- Mail Server VM cloud-init ---
info "Creating cloud-init for $SERVER_VM..."
cat > "$LAB_DIR/user-data-server" <<'USERDATA'
#cloud-config
hostname: mail-lab-server
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - rsyslog
  - postfix
  - dovecot-imapd
  - mailutils
  - nano
  - net-tools
  - iputils-ping
  - tcpdump
  - netcat-openbsd
  - zsh
  - vim
  - nano
  - fonts-powerline
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          maillan:
            match:
              macaddress: "52:54:00:00:07:01"
            addresses:
              - 192.168.100.1/24
  - path: /etc/postfix/main.cf.lab
    permissions: '0644'
    content: |
      smtpd_banner = $myhostname ESMTP mail.lab
      biff = no
      append_dot_mydomain = no
      readme_directory = no
      compatibility_level = 3.6

      myhostname = mail.lab
      mydomain = mail.lab
      myorigin = $mydomain
      mydestination = $myhostname, mail.lab, localhost.localdomain, localhost
      mynetworks = 127.0.0.0/8, 192.168.100.0/24

      inet_interfaces = all
      inet_protocols = ipv4

      home_mailbox = Maildir/
      mailbox_size_limit = 0
      recipient_delimiter = +

      smtpd_relay_restrictions = permit_mynetworks, reject_unauth_destination
  - path: /etc/dovecot/conf.d/99-mail-lab.conf
    permissions: '0644'
    content: |
      mail_location = maildir:~/Maildir
      disable_plaintext_auth = no
      auth_mechanisms = plain login
      service imap-login {
        inet_listener imap {
          address = 0.0.0.0
          port = 143
        }
      }
      passdb {
        driver = pam
      }
      userdb {
        driver = passwd
      }
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mmail-lab-server\033[0m — \033[1mMail Server Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Mail Server (Postfix + Dovecot)
        \033[1;33mDomain:\033[0m  \033[1;36mmail.lab\033[0m
        \033[1;33mInternal IP:\033[0m  \033[1;36m192.168.100.1\033[0m

        \033[1;33mServices:\033[0m
          \033[0;32mPostfix\033[0m   SMTP on port 25
          \033[0;32mDovecot\033[0m   IMAP on port 143

        \033[1;33mMail users:\033[0m
          \033[0;32malice\033[0m     alice@mail.lab (password: labpass)
          \033[0;32mbob\033[0m       bob@mail.lab   (password: labpass)

        \033[1;33mUseful Commands:\033[0m
          \033[0;32msudo tail -f /var/log/mail.log\033[0m     follow mail logs
          \033[0;32msudo postqueue -p\033[0m                  show mail queue
          \033[0;32msudo doveadm mailbox list -u alice\033[0m list alice's mailboxes
          \033[0;32msystemctl status postfix\033[0m           Postfix status
          \033[0;32msystemctl status dovecot\033[0m           Dovecot status

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /tmp/setup-zsh.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc
      sed -i 's/^plugins=(.*)/plugins=(git)/' ~/.zshrc
runcmd:
  - netplan apply
  # Create mail users alice and bob
  - useradd -m -s /bin/bash alice
  - echo "alice:labpass" | chpasswd
  - useradd -m -s /bin/bash bob
  - echo "bob:labpass" | chpasswd
  # Create Maildir for both users
  - mkdir -p /home/alice/Maildir/{new,cur,tmp}
  - chown -R alice:alice /home/alice/Maildir
  - mkdir -p /home/bob/Maildir/{new,cur,tmp}
  - chown -R bob:bob /home/bob/Maildir
  # Configure Postfix
  - cp /etc/postfix/main.cf.lab /etc/postfix/main.cf
  - systemctl restart postfix
  - systemctl enable postfix
  # Configure Dovecot
  - systemctl restart dovecot
  - systemctl enable dovecot
  # MOTD setup
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - sudo -Hu labuser bash /tmp/setup-zsh.sh
  - chsh -s /usr/bin/zsh labuser
  - echo "=== mail-lab-server VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-server"

cat > "$LAB_DIR/meta-data-server" <<METADATA
instance-id: ${SERVER_VM}-001
local-hostname: ${SERVER_VM}
METADATA

success "Created cloud-init for $SERVER_VM"

# --- Client1 VM cloud-init (alice) ---
info "Creating cloud-init for $CLIENT1_VM (alice)..."
cat > "$LAB_DIR/user-data-client1" <<'USERDATA'
#cloud-config
hostname: mail-lab-client1
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - mailutils
  - mutt
  - telnet
  - nano
  - net-tools
  - iputils-ping
  - curl
  - zsh
  - vim
  - nano
  - fonts-powerline
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          maillan:
            match:
              macaddress: "52:54:00:00:07:02"
            addresses:
              - 192.168.100.2/24
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;31mmail-lab-client1\033[0m — \033[1mAlice's Mail Client\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Mail client for \033[1;32malice\033[0m
        \033[1;33mInternal IP:\033[0m  \033[1;36m192.168.100.2\033[0m
        \033[1;33mMail Server:\033[0m  \033[1;36m192.168.100.1\033[0m (mail.lab)

        \033[1;33mSwitch to alice:\033[0m
          \033[0;32msudo -u alice bash\033[0m

        \033[1;33mSend mail (as alice):\033[0m
          \033[0;32mecho "Hello Bob!" | mail -s "Hello" bob@mail.lab\033[0m

        \033[1;33mRead mail with mutt (as alice):\033[0m
          \033[0;32mmutt\033[0m

        \033[1;33mTest server connectivity:\033[0m
          \033[0;32mping mail.lab\033[0m
          \033[0;32mtelnet mail.lab 25\033[0m     (test SMTP)
          \033[0;32mtelnet mail.lab 143\033[0m    (test IMAP)

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mMail user:\033[0m   \033[1;36malice\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /tmp/setup-zsh.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc
      sed -i 's/^plugins=(.*)/plugins=(git)/' ~/.zshrc
runcmd:
  - netplan apply
  # Add mail.lab to /etc/hosts
  - echo "192.168.100.1 mail.lab" >> /etc/hosts
  # Create alice user for mail operations
  - useradd -m -s /bin/bash alice
  - echo "alice:labpass" | chpasswd
  # Create mutt config for alice
  - |
    cat > /home/alice/.muttrc <<'MUTTRC'
    set realname = "Alice"
    set from = "alice@mail.lab"
    set folder = "imap://alice:labpass@mail.lab:143/"
    set spoolfile = "imap://alice:labpass@mail.lab:143/INBOX"
    set smtp_url = "smtp://alice@mail.lab:25/"
    set ssl_starttls = no
    set ssl_force_tls = no
    set imap_check_subscribed = yes
    set mail_check = 30
    MUTTRC
  - chown alice:alice /home/alice/.muttrc
  - chmod 600 /home/alice/.muttrc
  # MOTD setup
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - sudo -Hu labuser bash /tmp/setup-zsh.sh
  - chsh -s /usr/bin/zsh labuser
  - echo "=== mail-lab-client1 VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-client1"

cat > "$LAB_DIR/meta-data-client1" <<METADATA
instance-id: ${CLIENT1_VM}-001
local-hostname: ${CLIENT1_VM}
METADATA

success "Created cloud-init for $CLIENT1_VM"

# --- Client2 VM cloud-init (bob) ---
info "Creating cloud-init for $CLIENT2_VM (bob)..."
cat > "$LAB_DIR/user-data-client2" <<'USERDATA'
#cloud-config
hostname: mail-lab-client2
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - mailutils
  - mutt
  - telnet
  - nano
  - net-tools
  - iputils-ping
  - curl
  - zsh
  - vim
  - nano
  - fonts-powerline
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          maillan:
            match:
              macaddress: "52:54:00:00:07:03"
            addresses:
              - 192.168.100.3/24
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;31mmail-lab-client2\033[0m — \033[1mBob's Mail Client\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  Mail client for \033[1;32mbob\033[0m
        \033[1;33mInternal IP:\033[0m  \033[1;36m192.168.100.3\033[0m
        \033[1;33mMail Server:\033[0m  \033[1;36m192.168.100.1\033[0m (mail.lab)

        \033[1;33mSwitch to bob:\033[0m
          \033[0;32msudo -u bob bash\033[0m

        \033[1;33mSend mail (as bob):\033[0m
          \033[0;32mecho "Hello Alice!" | mail -s "Hello" alice@mail.lab\033[0m

        \033[1;33mRead mail with mutt (as bob):\033[0m
          \033[0;32mmutt\033[0m

        \033[1;33mTest server connectivity:\033[0m
          \033[0;32mping mail.lab\033[0m
          \033[0;32mtelnet mail.lab 25\033[0m     (test SMTP)
          \033[0;32mtelnet mail.lab 143\033[0m    (test IMAP)

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mMail user:\033[0m   \033[1;36mbob\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /tmp/setup-zsh.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc
      sed -i 's/^plugins=(.*)/plugins=(git)/' ~/.zshrc
runcmd:
  - netplan apply
  # Add mail.lab to /etc/hosts
  - echo "192.168.100.1 mail.lab" >> /etc/hosts
  # Create bob user for mail operations
  - useradd -m -s /bin/bash bob
  - echo "bob:labpass" | chpasswd
  # Create mutt config for bob
  - |
    cat > /home/bob/.muttrc <<'MUTTRC'
    set realname = "Bob"
    set from = "bob@mail.lab"
    set folder = "imap://bob:labpass@mail.lab:143/"
    set spoolfile = "imap://bob:labpass@mail.lab:143/INBOX"
    set smtp_url = "smtp://bob@mail.lab:25/"
    set ssl_starttls = no
    set ssl_force_tls = no
    set imap_check_subscribed = yes
    set mail_check = 30
    MUTTRC
  - chown bob:bob /home/bob/.muttrc
  - chmod 600 /home/bob/.muttrc
  # MOTD setup
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - sudo -Hu labuser bash /tmp/setup-zsh.sh
  - chsh -s /usr/bin/zsh labuser
  - echo "=== mail-lab-client2 VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-client2"

cat > "$LAB_DIR/meta-data-client2" <<METADATA
instance-id: ${CLIENT2_VM}-001
local-hostname: ${CLIENT2_VM}
METADATA

success "Created cloud-init for $CLIENT2_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_SERVER="$LAB_DIR/cidata-server.iso"
genisoimage -output "$CIDATA_SERVER" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-server" "meta-data=$LAB_DIR/meta-data-server" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_SERVER"

CIDATA_CLIENT1="$LAB_DIR/cidata-client1.iso"
genisoimage -output "$CIDATA_CLIENT1" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-client1" "meta-data=$LAB_DIR/meta-data-client1" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_CLIENT1"

CIDATA_CLIENT2="$LAB_DIR/cidata-client2.iso"
genisoimage -output "$CIDATA_CLIENT2" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-client2" "meta-data=$LAB_DIR/meta-data-client2" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_CLIENT2"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_SERVER="$LAB_DIR/${SERVER_VM}-disk.qcow2"
if [[ -f "$OVERLAY_SERVER" ]]; then rm -f "$OVERLAY_SERVER"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_SERVER" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for server."
    exit 1
}

OVERLAY_CLIENT1="$LAB_DIR/${CLIENT1_VM}-disk.qcow2"
if [[ -f "$OVERLAY_CLIENT1" ]]; then rm -f "$OVERLAY_CLIENT1"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_CLIENT1" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for client1."
    exit 1
}

OVERLAY_CLIENT2="$LAB_DIR/${CLIENT2_VM}-disk.qcow2"
if [[ -f "$OVERLAY_CLIENT2" ]]; then rm -f "$OVERLAY_CLIENT2"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_CLIENT2" "${QLAB_DISK_SIZE:-}" || {
    error "Failed to create overlay disk for client2."
    exit 1
}
echo ""

# =============================================
# Step 5: Start all VMs
# =============================================
info "Step 5: Starting VMs (internal LAN: 192.168.100.0/24)"
echo ""

# Multi-VM: resource check, cleanup trap, rollback on failure
MEMORY_TOTAL=$(( MEMORY * 3 ))
check_host_resources "$MEMORY_TOTAL" 3
declare -a STARTED_VMS=()
register_vm_cleanup STARTED_VMS

info "Starting $SERVER_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_SERVER" "$CIDATA_SERVER" "$MEMORY" "$SERVER_VM" auto \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${SERVER_LAN_MAC}" || exit 1

echo ""

info "Starting $CLIENT1_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_CLIENT1" "$CIDATA_CLIENT1" "$MEMORY" "$CLIENT1_VM" auto \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${CLIENT1_LAN_MAC}" || exit 1

echo ""

info "Starting $CLIENT2_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_CLIENT2" "$CIDATA_CLIENT2" "$MEMORY" "$CLIENT2_VM" auto \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${CLIENT2_LAN_MAC}" || exit 1

# Successful start — disable cleanup trap
trap - EXIT

echo ""
echo "============================================="
echo "  mail-lab: All VMs are booting"
echo "============================================="
echo ""
echo "  Mail Server VM:"
echo "    SSH:          qlab shell $SERVER_VM"
echo "    Log:          qlab log $SERVER_VM"
echo "    Internal IP:  $SERVER_INTERNAL_IP"
echo "    Services:     Postfix (SMTP:25) + Dovecot (IMAP:143)"
echo ""
echo "  Client1 VM (alice):"
echo "    SSH:          qlab shell $CLIENT1_VM"
echo "    Log:          qlab log $CLIENT1_VM"
echo "    Internal IP:  $CLIENT1_INTERNAL_IP"
echo ""
echo "  Client2 VM (bob):"
echo "    SSH:          qlab shell $CLIENT2_VM"
echo "    Log:          qlab log $CLIENT2_VM"
echo "    Internal IP:  $CLIENT2_INTERNAL_IP"
echo ""
echo "  Domain:        mail.lab"
echo "  Internal LAN:  192.168.100.0/24"
echo "  Credentials:   labuser / labpass"
echo "  Mail users:    alice / labpass, bob / labpass"
echo ""
echo "  Quick test (after boot ~90s):"
echo "    qlab shell $CLIENT1_VM"
echo "    sudo -u alice bash"
echo "    echo \"Hi Bob!\" | mail -s \"Hello\" bob@mail.lab"
echo ""
echo "    qlab shell $CLIENT2_VM"
echo "    sudo -u bob mutt"
echo ""
echo "  Stop all VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=1024 qlab run ${PLUGIN_NAME}"
echo "============================================="
