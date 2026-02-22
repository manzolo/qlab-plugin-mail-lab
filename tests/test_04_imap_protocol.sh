#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — IMAP Protocol${RESET}"; echo ""

# First, send a test message so there's something in the inbox
ssh_server "sudo -u alice bash -c 'echo \"IMAP test message\" | mail -s \"IMAP Test\" bob@mail.lab'" 2>/dev/null
sleep 3

# 4.1 IMAP banner is accessible
banner=$(ssh_server "echo 'a0 LOGOUT' | nc -w5 localhost 143 2>/dev/null" || echo "")
assert_contains "IMAP banner received" "$banner" "OK.*Dovecot|CAPABILITY"

# 4.2 IMAP LOGIN works
login_resp=$(ssh_server "{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 LOGOUT'; } | nc -w5 localhost 143 2>/dev/null" || echo "")
assert_contains "IMAP LOGIN successful" "$login_resp" "a1 OK"

# 4.3 SELECT INBOX works
select_resp=$(ssh_server "{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 SELECT INBOX'; sleep 1; echo 'a3 LOGOUT'; } | nc -w5 localhost 143 2>/dev/null" || echo "")
assert_contains "INBOX selected" "$select_resp" "a2 OK|EXISTS"

# 4.4 SEARCH ALL returns results
search_resp=$(ssh_server "{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 SELECT INBOX'; sleep 1; echo 'a3 SEARCH ALL'; sleep 1; echo 'a4 LOGOUT'; } | nc -w5 localhost 143 2>/dev/null" || echo "")
assert_contains "SEARCH ALL returns results" "$search_resp" "SEARCH"

# 4.5 Dovecot mailbox list via doveadm
mailboxes=$(ssh_server "sudo doveadm mailbox list -u bob 2>/dev/null" || echo "")
assert_contains "Doveadm lists bob's mailboxes" "$mailboxes" "INBOX"

# Clean up
ssh_server "sudo bash -c 'rm -f /home/bob/Maildir/new/* /home/bob/Maildir/cur/*'" 2>/dev/null

report_results "Exercise 4"
