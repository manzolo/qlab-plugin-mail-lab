#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — Mail Server Anatomy${RESET}"; echo ""

# 1.1 Postfix is running
postfix_status=$(ssh_server "systemctl is-active postfix 2>/dev/null" || echo "unknown")
assert_contains "Postfix is active" "$postfix_status" "active"

# 1.2 Dovecot is running
dovecot_status=$(ssh_server "systemctl is-active dovecot 2>/dev/null" || echo "unknown")
assert_contains "Dovecot is active" "$dovecot_status" "active"

# 1.3 SMTP port 25 listening
ports=$(ssh_server "ss -tlnp 2>/dev/null")
assert_contains "Port 25 (SMTP) listening" "$ports" ":25"

# 1.4 IMAP port 143 listening
assert_contains "Port 143 (IMAP) listening" "$ports" ":143"

# 1.5 Mail users exist
alice_id=$(ssh_server "id alice 2>/dev/null" || echo "")
assert_contains "User alice exists" "$alice_id" "uid="

bob_id=$(ssh_server "id bob 2>/dev/null" || echo "")
assert_contains "User bob exists" "$bob_id" "uid="

# 1.6 Maildir structure exists
alice_maildir=$(ssh_server "sudo ls -d /home/alice/Maildir 2>/dev/null" || echo "")
assert_contains "Alice Maildir exists" "$alice_maildir" "Maildir"

bob_maildir=$(ssh_server "sudo ls -d /home/bob/Maildir 2>/dev/null" || echo "")
assert_contains "Bob Maildir exists" "$bob_maildir" "Maildir"

# 1.7 Internal network connectivity
client1_ping=$(ssh_client1 "ping -c1 -W2 192.168.100.1 2>/dev/null" || echo "")
assert_contains "Client1 can reach server" "$client1_ping" "1 received"

client2_ping=$(ssh_client2 "ping -c1 -W2 192.168.100.1 2>/dev/null" || echo "")
assert_contains "Client2 can reach server" "$client2_ping" "1 received"

# 1.8 mail.lab in /etc/hosts on clients
hosts_c1=$(ssh_client1 "cat /etc/hosts 2>/dev/null" || echo "")
assert_contains "Client1 has mail.lab in hosts" "$hosts_c1" "mail.lab"

hosts_c2=$(ssh_client2 "cat /etc/hosts 2>/dev/null" || echo "")
assert_contains "Client2 has mail.lab in hosts" "$hosts_c2" "mail.lab"

report_results "Exercise 1"
