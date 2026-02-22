#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — Postfix Configuration${RESET}"; echo ""

# 5.1 postconf shows non-default settings
postconf=$(ssh_server "postconf -n 2>/dev/null" || echo "")
assert_contains "postconf -n works" "$postconf" "myhostname"

# 5.2 myhostname is mail.lab
assert_contains "myhostname = mail.lab" "$postconf" "myhostname.*mail.lab"

# 5.3 mydomain is mail.lab
assert_contains "mydomain = mail.lab" "$postconf" "mydomain.*mail.lab"

# 5.4 home_mailbox is Maildir/
assert_contains "home_mailbox = Maildir/" "$postconf" "home_mailbox.*Maildir"

# 5.5 mynetworks includes LAN
assert_contains "mynetworks includes 192.168.100.0/24" "$postconf" "mynetworks.*192.168.100"

# 5.6 inet_interfaces = all
assert_contains "inet_interfaces = all" "$postconf" "inet_interfaces.*all"

# 5.7 Maildir structure has correct subdirs
maildir_ls=$(ssh_server "sudo ls /home/alice/Maildir/ 2>/dev/null" || echo "")
assert_contains "Maildir has new/" "$maildir_ls" "new"
assert_contains "Maildir has cur/" "$maildir_ls" "cur"
assert_contains "Maildir has tmp/" "$maildir_ls" "tmp"

report_results "Exercise 5"
