# mail-lab — Postfix & Dovecot Mail Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Walkthrough](https://img.shields.io/badge/walkthrough-EN%20%26%20IT-informational)](docs/walkthrough-en.pdf)

A three-VM [QLab](https://github.com/manzolo/qlab) lab — a Postfix + Dovecot server and two
client machines, one per user — for learning mail from the wire up: hand SMTP a message,
pull it back over IMAP, and watch both in the server's log.

## Quick start

```bash
qlab install mail-lab
qlab run mail-lab              # boots 3 VMs (~120s)
qlab shell mail-lab-server     # Postfix (SMTP) + Dovecot (IMAP)
qlab shell mail-lab-client1    # alice's machine
qlab shell mail-lab-client2    # bob's machine
qlab test mail-lab             # run the automated checks
qlab stop mail-lab
```

By hand: `telnet 192.168.100.1 25` to submit, `telnet 192.168.100.1 143` to read. With a
client: `sudo -u alice bash`, then `mutt`.

## What's inside

| # | Exercise | What you do |
|---|----------|-------------|
| 1 | Send mail | alice → bob over SMTP |
| 2 | Read mail | bob reads and replies in mutt |
| 3 | Read the reply | alice reads bob's reply |
| 4 | Postfix logs | follow a message through `/var/log/mail.log` |
| 5 | Dovecot status | `doveadm` and the Maildir |
| 6 | SMTP/IMAP by telnet | run both protocols by hand |
| 7 | Add a user | a new mail user is just `adduser` |

## Network

Private LAN `192.168.100.0/24`, isolated between the three VMs.

| VM | Address | Role |
|----|---------|------|
| `mail-lab-server` | `192.168.100.1` | Postfix (SMTP) + Dovecot (IMAP) |
| `mail-lab-client1` | `192.168.100.2` | alice (mutt) |
| `mail-lab-client2` | `192.168.100.3` | bob (mutt) |

Accounts: `labuser` / `labpass` · mail users `alice`, `bob` / `labpass`. SSH forwarded — see `qlab ports`.

## Learn more

- 📖 **[Step-by-step guide](guide.md)** — every exercise with full commands, including SMTP/IMAP over telnet
- 📄 **Illustrated walkthrough** — a real run, captured live: **[English](docs/walkthrough-en.pdf)** · **[Italiano](docs/walkthrough-it.pdf)**
- 🧩 **[QLab](https://github.com/manzolo/qlab)** — the plugin runner: how install, overlays and cloud-init work
