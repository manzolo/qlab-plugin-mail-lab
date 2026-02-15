# mail-lab — Mail Server Lab (Postfix + Dovecot)

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots three virtual machines for practicing email server administration with Postfix (SMTP) and Dovecot (IMAP).

## Architecture

```
           Internal LAN (192.168.100.0/24)
┌──────────────────────────────────────────────────┐
│                                                  │
│  ┌──────────────────┐                            │
│  │ mail-lab-server  │                            │
│  │ 192.168.100.1    │                            │
│  │ Postfix + Dovecot│                            │
│  └────────┬─────────┘                            │
│           │                                      │
│     ┌─────┴─────┐                                │
│     │           │                                │
│  ┌──┴───────────┴──┐  ┌──────────────────┐       │
│  │ mail-lab-client1│  │ mail-lab-client2 │       │
│  │ 192.168.100.2   │  │ 192.168.100.3    │       │
│  │ alice (mutt)    │  │ bob (mutt)       │       │
│  └─────────────────┘  └──────────────────┘       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Mail Flow

```
alice@client1 → SMTP(25) → server → Maildir → IMAP(143) → bob@client2
bob@client2   → SMTP(25) → server → Maildir → IMAP(143) → alice@client1
```

## Objectives

- Configure and understand Postfix as an SMTP server
- Configure and understand Dovecot as an IMAP server
- Send and receive mail between two users
- Read and interpret mail server logs
- Use mutt as a terminal mail client

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu 22.04 cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` for all 3 VMs with mail packages and configs
3. **ISO generation**: Packs cloud-init files into ISOs (cidata)
4. **Overlay disks**: Creates COW disks for each VM (original stays untouched)
5. **QEMU boot**: Starts all 3 VMs with SSH access and a shared internal LAN

## Credentials

All VMs use the same SSH credentials:
- **Username:** `labuser`
- **Password:** `labpass`

Mail users:
- **alice** / `labpass` (on server and client1)
- **bob** / `labpass` (on server and client2)

## Network

| VM               | SSH (host) | Internal LAN IP  | Role          |
|------------------|------------|------------------|---------------|
| mail-lab-server  | dynamic    | 192.168.100.1    | Mail server   |
| mail-lab-client1 | dynamic    | 192.168.100.2    | Alice's client|
| mail-lab-client2 | dynamic    | 192.168.100.3    | Bob's client  |

> All host ports are dynamically allocated. Use `qlab ports` to see the actual mappings.

The VMs are connected by a direct internal LAN (`192.168.100.0/24`) via QEMU socket networking. Mail traffic flows over this LAN.

## Usage

```bash
# Install the plugin
qlab install mail-lab

# Run the lab (starts all 3 VMs)
qlab run mail-lab

# Wait ~90s for boot and package installation, then:

# Connect to the server
qlab shell mail-lab-server

# Connect as alice
qlab shell mail-lab-client1

# Connect as bob
qlab shell mail-lab-client2

# Stop all VMs
qlab stop mail-lab

# Stop a single VM
qlab stop mail-lab-server
qlab stop mail-lab-client1
qlab stop mail-lab-client2
```

## Exercises

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **Send mail (alice → bob)** | On client1: `sudo -u alice bash`, then `echo "Hi Bob!" \| mail -s "Hello" bob@mail.lab` |
| 2 | **Read mail (bob)** | On client2: `sudo -u bob bash`, then `mutt` — read alice's mail and reply |
| 3 | **Read reply (alice)** | On client1: `sudo -u alice bash`, then `mutt` — read bob's reply |
| 4 | **Check Postfix logs** | On server: `sudo tail -f /var/log/mail.log` |
| 5 | **Check Dovecot status** | On server: `systemctl status dovecot` and `sudo doveadm mailbox list -u alice` |
| 6 | **Test with telnet** | On client1/client2: `telnet mail.lab 25` (SMTP) or `telnet mail.lab 143` (IMAP) |
| 7 | **Add a new user** | On server: create user `charlie`, configure mail, test sending/receiving |

> **Important:** Mail commands (`mail`, `mutt`) must be run as the mail user (`alice` or `bob`), not as `labuser`. Switch user first with `sudo -u alice bash` or `sudo -u bob bash`.

## Managing VMs

```bash
# View boot logs
qlab log mail-lab-server
qlab log mail-lab-client1
qlab log mail-lab-client2

# Check running VMs
qlab status
```

## Resetting

To start fresh, stop and re-run:

```bash
qlab stop mail-lab
qlab run mail-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
