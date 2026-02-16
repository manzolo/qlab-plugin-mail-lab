# Mail Lab — Step-by-Step Guide

This guide walks you through sending and receiving email between two users, inspecting mail server logs, and interacting directly with SMTP and IMAP protocols via telnet.

## Prerequisites

Start the lab and wait for all VMs to finish booting (~90 seconds):

```bash
qlab run mail-lab
```

Open **three terminals** and connect to each VM:

```bash
# Terminal 1 — Mail Server
qlab shell mail-lab-server

# Terminal 2 — Alice (client1)
qlab shell mail-lab-client1

# Terminal 3 — Bob (client2)
qlab shell mail-lab-client2
```

On each VM, make sure cloud-init has finished:

```bash
cloud-init status --wait
```

## Network Topology

```
        Host Machine
       ┌────────────┐
       │  SSH :auto │──────► mail-lab-server
       │  SSH :auto │──────► mail-lab-client1
       │  SSH :auto │──────► mail-lab-client2
       └────────────┘

   Internal LAN (192.168.100.0/24)
  ┌──────────────────────────────────────────┐
  │                                          │
  │  ┌──────────────┐                        │
  │  │ mail-server  │                        │
  │  │ 192.168.100.1│                        │
  │  │ SMTP:25      │                        │
  │  │ IMAP:143     │                        │
  │  └──────┬───────┘                        │
  │         │                                │
  │    ┌────┴─────────────────┐              │
  │    │                      │              │
  │  ┌─┴───────────┐   ┌──────┴───────┐      │
  │  │ client1     │   │ client2      │      │
  │  │ 192.168.    │   │ 192.168.     │      │
  │  │   100.2     │   │   100.3      │      │
  │  │ alice       │   │ bob          │      │ 
  │  └─────────────┘   └──────────────┘      │
  └──────────────────────────────────────────┘
```

Mail flow:

```
alice@client1 → SMTP(25) → server → Maildir → IMAP(143) → bob@client2
bob@client2   → SMTP(25) → server → Maildir → IMAP(143) → alice@client1
```

> **Important:** Mail commands (`mail`, `mutt`) must be run as the mail user (`alice` or `bob`), not as `labuser`. Always switch user first with `sudo -u alice bash` or `sudo -u bob bash`.

---

## Exercise 1: Send and Receive Mail

### 1.1 Send mail from alice to bob

On **mail-lab-client1**, switch to alice and send a message:

```bash
sudo -u alice bash
echo "Hi Bob! This is my first email." | mail -s "Hello from Alice" bob@mail.lab
```

### 1.2 Read mail as bob with mutt

On **mail-lab-client2**, switch to bob and open mutt:

```bash
sudo -u bob bash
mutt
```

You should see alice's message in the inbox. Use:
- **Enter** to open a message
- **r** to reply
- **q** to quit mutt

### 1.3 Reply from bob to alice

While reading alice's message in mutt, press **r** to reply. Type your reply, save and send (`y` to confirm).

### 1.4 Read the reply as alice

On **mail-lab-client1** (still as alice):

```bash
mutt
```

You should see bob's reply in your inbox.

---

## Exercise 2: Interact with SMTP via Telnet

Telnet lets you speak the SMTP protocol directly, exactly like a mail client does behind the scenes.

### 2.1 Connect to the SMTP server

On **mail-lab-client1** or **mail-lab-client2**:

```bash
telnet mail.lab 25
```

You should see a greeting like:

```
220 mail.lab ESMTP mail.lab
```

### 2.2 Send an email manually via SMTP

Type each command below, pressing **Enter** after each line. The server will respond with status codes (250, 354, etc.):

```
EHLO client1
MAIL FROM:<alice@mail.lab>
RCPT TO:<bob@mail.lab>
DATA
Subject: Manual SMTP test

This email was sent by typing SMTP commands manually!
It is a great way to understand how email works.
.
QUIT
```

> **Note:** The message body ends with a single dot (`.`) on a line by itself. This tells the server the message is complete.

Expected responses:

| Command | Response | Meaning |
|---------|----------|---------|
| `EHLO client1` | `250-mail.lab` | Server identifies itself, lists capabilities |
| `MAIL FROM:<alice@mail.lab>` | `250 2.1.0 Ok` | Sender accepted |
| `RCPT TO:<bob@mail.lab>` | `250 2.1.5 Ok` | Recipient accepted |
| `DATA` | `354 End data with <CR><LF>.<CR><LF>` | Ready to receive message body |
| `.` | `250 2.0.0 Ok: queued as XXXXX` | Message accepted and queued |
| `QUIT` | `221 2.0.0 Bye` | Connection closed |

### 2.3 Verify the message arrived

On **mail-lab-client2** as bob:

```bash
sudo -u bob bash
mutt
```

You should see the "Manual SMTP test" message in bob's inbox.

### 2.4 Explore SMTP commands

Try these additional SMTP commands after `EHLO`:

```
VRFY alice           # Verify if a user exists
VRFY bob             # Verify another user
VRFY nonexistent     # See what happens with unknown users
NOOP                 # No operation (server replies 250 Ok)
RSET                 # Reset the session (cancel current transaction)
QUIT                 # Close the connection
```

---

## Exercise 3: Interact with IMAP via Telnet

IMAP is the protocol used by mutt (and Thunderbird, Outlook, etc.) to read email. You can speak it directly with telnet.

### 3.1 Connect to the IMAP server

On any client VM:

```bash
telnet mail.lab 143
```

You should see:

```
* OK [CAPABILITY ...] Dovecot ready.
```

### 3.2 Login and list mailboxes

Each IMAP command must start with a **tag** (any identifier, like `a1`, `a2`, etc.):

```
a1 LOGIN bob labpass
a2 LIST "" "*"
```

Expected output:

```
a1 OK [CAPABILITY ...] Logged in
* LIST (\HasNoChildren) "." "INBOX"
a2 OK List completed
```

### 3.3 Select inbox and read messages

```
a3 SELECT INBOX
```

The server will reply with mailbox status (number of messages, flags, etc.):

```
* 2 EXISTS              <-- number of messages
* 0 RECENT
* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
...
a3 OK [READ-WRITE] Select completed.
```

### 3.4 Fetch a message

To read message #1:

```
a4 FETCH 1 (BODY[HEADER.FIELDS (FROM SUBJECT DATE)])
a5 FETCH 1 BODY[TEXT]
```

`a4` shows headers (From, Subject, Date), `a5` shows the message body.

### 3.5 Search for messages

```
a6 SEARCH ALL
a7 SEARCH FROM "alice"
a8 SEARCH SUBJECT "Hello"
```

### 3.6 Logout

```
a9 LOGOUT
```

### IMAP command reference

| Command | Description |
|---------|-------------|
| `LOGIN user pass` | Authenticate |
| `LIST "" "*"` | List all mailboxes |
| `SELECT INBOX` | Open a mailbox |
| `FETCH n BODY[]` | Fetch full message n |
| `FETCH n (FLAGS)` | Fetch message flags |
| `SEARCH ALL` | List all message numbers |
| `SEARCH FROM "x"` | Search by sender |
| `STORE n +FLAGS \Deleted` | Mark message for deletion |
| `EXPUNGE` | Permanently delete marked messages |
| `LOGOUT` | Close connection |

---

## Exercise 4: Check Server Logs

### 4.1 Follow mail logs in real time

On **mail-lab-server**:

```bash
sudo tail -f /var/log/mail.log
```

Now send a message from a client — you'll see Postfix logging each step:

```
postfix/smtpd[...]: connect from unknown[192.168.100.2]
postfix/smtpd[...]: XXXXX: client=unknown[192.168.100.2]
postfix/cleanup[...]: XXXXX: message-id=<...>
postfix/qmgr[...]: XXXXX: from=<alice@mail.lab>, size=..., nrcpt=1
postfix/local[...]: XXXXX: to=<bob@mail.lab>, relay=local, ... status=sent
postfix/qmgr[...]: XXXXX: removed
```

### 4.2 Check the mail queue

```bash
# Show pending messages
sudo postqueue -p

# Flush (retry delivery of) all queued messages
sudo postqueue -f
```

### 4.3 Check service status

```bash
# Postfix
systemctl status postfix

# Dovecot
systemctl status dovecot
```

### 4.4 List user mailboxes via Dovecot

```bash
sudo doveadm mailbox list -u alice
sudo doveadm mailbox list -u bob
```

---

## Exercise 5: Inspect Postfix Configuration

### 5.1 View the active configuration

On **mail-lab-server**:

```bash
# Show all non-default Postfix settings
postconf -n
```

Key settings to understand:

| Setting | Value | Meaning |
|---------|-------|---------|
| `myhostname` | `mail.lab` | Server's hostname in SMTP banners |
| `mydomain` | `mail.lab` | Domain for mail delivery |
| `mydestination` | `mail.lab, localhost...` | Domains this server accepts mail for |
| `mynetworks` | `127.0.0.0/8, 192.168.100.0/24` | IPs allowed to relay mail |
| `home_mailbox` | `Maildir/` | Deliver to `~/Maildir/` (Maildir format) |
| `inet_interfaces` | `all` | Listen on all interfaces |

### 5.2 Inspect Maildir on the server

```bash
# See alice's mailbox structure
sudo ls -la /home/alice/Maildir/
sudo ls -la /home/alice/Maildir/new/    # new (unread) messages
sudo ls -la /home/alice/Maildir/cur/    # read messages

# Read a raw message file
sudo cat /home/alice/Maildir/new/*
```

> **Maildir format** stores each message as a separate file. New messages go to `new/`, and after reading they move to `cur/`. This is different from the older `mbox` format which stores all messages in a single file.

---

## Exercise 6: Add a New User

### 6.1 Create user on the server

On **mail-lab-server**:

```bash
# Create the user
sudo useradd -m -s /bin/bash charlie
sudo echo "charlie:labpass" | sudo chpasswd

# Create Maildir
sudo mkdir -p /home/charlie/Maildir/{new,cur,tmp}
sudo chown -R charlie:charlie /home/charlie/Maildir
```

### 6.2 Test sending mail to the new user

From any client:

```bash
echo "Welcome Charlie!" | mail -s "Hello" charlie@mail.lab
```

### 6.3 Read mail as charlie (on the server)

```bash
sudo -u charlie bash
cat ~/Maildir/new/*
```

---

## Troubleshooting

### telnet: "Connection refused" on port 25 or 143

- Cloud-init may still be running: `cloud-init status --wait`
- Check that Postfix/Dovecot are running on the server: `systemctl status postfix dovecot`
- Verify network connectivity: `ping mail.lab`

### mail command: "send-mail: Cannot open mail:25"

- Make sure `/etc/hosts` has the entry `192.168.100.1 mail.lab`
- Check from the client: `ping mail.lab`
- Verify Postfix is listening: `telnet mail.lab 25`

### mutt: "/var/mail/labuser: No such file or directory"

You are running mutt as `labuser` instead of the mail user. Switch user first:

```bash
sudo -u alice bash   # on client1
sudo -u bob bash     # on client2
mutt
```

### mutt: "Login failed" or IMAP connection error

- Make sure the server has finished booting (Dovecot must be running)
- Verify credentials: user `alice`/`bob`, password `labpass`
- Test IMAP manually: `telnet mail.lab 143`, then `a1 LOGIN alice labpass`

### Messages not arriving

1. Check the mail queue on the server: `sudo postqueue -p`
2. Check the logs: `sudo tail -20 /var/log/mail.log`
3. Verify the recipient user exists: `id bob` on the server
4. Check Maildir: `sudo ls /home/bob/Maildir/new/`

### General: packages not installed

If commands like `mutt` or `telnet` are not found, cloud-init may still be running:

```bash
cloud-init status --wait
```
