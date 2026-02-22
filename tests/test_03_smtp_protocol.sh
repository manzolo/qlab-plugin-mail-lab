#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — SMTP Protocol${RESET}"; echo ""

# Clean up
ssh_server "sudo bash -c 'rm -f /home/bob/Maildir/new/* /home/bob/Maildir/cur/*'" 2>/dev/null || true

# 3.1 SMTP banner is accessible
banner=$(ssh_server "echo 'QUIT' | nc -w5 localhost 25 2>/dev/null" || echo "")
assert_contains "SMTP banner received" "$banner" "220.*mail"

# 3.2 EHLO command works
ehlo_resp=$(ssh_server "{ echo 'EHLO testclient'; sleep 1; echo 'QUIT'; } | nc -w5 localhost 25 2>/dev/null" || echo "")
assert_contains "EHLO response received" "$ehlo_resp" "250"

# 3.3 Send a mail via raw SMTP
smtp_result=$(ssh_server "{ echo 'EHLO testclient'; sleep 1; echo 'MAIL FROM:<alice@mail.lab>'; sleep 1; echo 'RCPT TO:<bob@mail.lab>'; sleep 1; echo 'DATA'; sleep 1; echo 'Subject: SMTP Test'; echo ''; echo 'Sent via raw SMTP'; echo '.'; sleep 1; echo 'QUIT'; } | nc -w15 localhost 25 2>/dev/null" || echo "")
assert_contains "MAIL FROM accepted" "$smtp_result" "250"
assert_contains "Message queued" "$smtp_result" "queued|250"

# 3.4 Wait and verify the message arrived
sleep 3
bob_smtp_mail=$(ssh_server "sudo bash -c 'cat /home/bob/Maildir/new/*' 2>/dev/null | head -20" || echo "")
assert_contains "SMTP test message delivered" "$bob_smtp_mail" "SMTP Test|raw SMTP"

# Clean up
ssh_server "sudo bash -c 'rm -f /home/bob/Maildir/new/* /home/bob/Maildir/cur/*'" 2>/dev/null

report_results "Exercise 3"
