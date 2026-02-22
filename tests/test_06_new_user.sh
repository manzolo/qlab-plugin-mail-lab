#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — Add a New User${RESET}"; echo ""

# 6.1 Create user charlie on the server
ssh_server "sudo useradd -m -s /bin/bash charlie 2>/dev/null || true"
ssh_server "echo 'charlie:labpass' | sudo chpasswd" 2>/dev/null
ssh_server "sudo mkdir -p /home/charlie/Maildir/new /home/charlie/Maildir/cur /home/charlie/Maildir/tmp && sudo chown -R charlie:charlie /home/charlie/Maildir" 2>/dev/null

charlie_id=$(ssh_server "id charlie 2>/dev/null" || echo "")
assert_contains "User charlie created" "$charlie_id" "uid="

# 6.2 Send mail to charlie (from server)
ssh_server "sudo -u alice bash -c 'echo \"Welcome Charlie!\" | mail -s \"Hello Charlie\" charlie@mail.lab'" 2>/dev/null
sleep 3

# 6.3 Charlie received the message
charlie_mail=$(ssh_server "sudo ls /home/charlie/Maildir/new/ 2>/dev/null" || echo "")
assert_contains "Charlie received mail" "$charlie_mail" "."

# 6.4 Read charlie's message
charlie_msg=$(ssh_server "sudo bash -c 'cat /home/charlie/Maildir/new/*' 2>/dev/null | head -20" || echo "")
assert_contains "Message content correct" "$charlie_msg" "Hello Charlie|Welcome"

# 6.5 IMAP login as charlie
imap_charlie=$(ssh_server "{ echo 'a1 LOGIN charlie labpass'; sleep 1; echo 'a2 LOGOUT'; } | nc -w5 localhost 143 2>/dev/null" || echo "")
assert_contains "Charlie can login via IMAP" "$imap_charlie" "a1 OK"

# Cleanup: remove charlie
ssh_server "sudo userdel -r charlie 2>/dev/null || true"

report_results "Exercise 6"
