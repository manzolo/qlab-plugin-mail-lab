#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — Send and Receive Mail${RESET}"; echo ""

# Clean up any previous test messages
ssh_server "sudo bash -c 'rm -f /home/alice/Maildir/new/* /home/alice/Maildir/cur/* /home/bob/Maildir/new/* /home/bob/Maildir/cur/*'" 2>/dev/null || true

# 2.1 Send mail from alice to bob (on server where Postfix delivers locally)
ssh_server "sudo -u alice bash -c 'echo \"Test message from alice\" | mail -s \"Test Alice to Bob\" bob@mail.lab'" 2>/dev/null
sleep 3

# 2.2 Check bob received the message on the server
bob_mail=$(ssh_server "sudo ls /home/bob/Maildir/new/ 2>/dev/null" || echo "")
assert_contains "Bob received mail in Maildir" "$bob_mail" "."

# 2.3 Read the message content
bob_msg=$(ssh_server "sudo bash -c 'cat /home/bob/Maildir/new/*' 2>/dev/null | head -30" || echo "")
assert_contains "Message contains subject" "$bob_msg" "Test Alice to Bob|alice"

# 2.4 Send mail from bob to alice
ssh_server "sudo -u bob bash -c 'echo \"Reply from bob\" | mail -s \"Test Bob to Alice\" alice@mail.lab'" 2>/dev/null
sleep 3

# 2.5 Check alice received the message
alice_mail=$(ssh_server "sudo ls /home/alice/Maildir/new/ 2>/dev/null" || echo "")
assert_contains "Alice received mail in Maildir" "$alice_mail" "."

# 2.6 Read alice's message
alice_msg=$(ssh_server "sudo bash -c 'cat /home/alice/Maildir/new/*' 2>/dev/null | head -30" || echo "")
assert_contains "Alice's message from bob" "$alice_msg" "Test Bob to Alice|bob"

# Clean up test messages
ssh_server "sudo bash -c 'rm -f /home/alice/Maildir/new/* /home/alice/Maildir/cur/* /home/bob/Maildir/new/* /home/bob/Maildir/cur/*'" 2>/dev/null

report_results "Exercise 2"
