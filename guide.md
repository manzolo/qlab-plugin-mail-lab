# Mail Lab — Step-by-Step Guide

This guide walks you through sending and receiving email between two users, inspecting mail server logs, and interacting directly with SMTP and IMAP protocols via netcat.

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
alice (server) → SMTP(25) → Postfix → Maildir → IMAP(143) → bob (server/mutt)
bob (server)   → SMTP(25) → Postfix → Maildir → IMAP(143) → alice (server/mutt)
```

> **Important:** Mail commands (`mail`, `mutt`) must be run on the **server VM** as the mail user (`alice` or `bob`), not as `labuser`. Always switch user first with `sudo -u alice bash` or `sudo -u bob bash`.

---

## Exercise 1: Send and Receive Mail

### 1.1 Send mail from alice to bob

On **mail-lab-server**, send a message as alice:

```bash
sudo -u alice bash -c 'echo "Hi Bob! This is my first email." | mail -s "Hello from Alice" bob@mail.lab'
```

### 1.2 Read mail as bob with mutt

On **mail-lab-server**, switch to bob and open mutt:

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

On **mail-lab-server** (as alice):

```bash
sudo -u alice bash
mutt
```

You should see bob's reply in your inbox.

---

## Exercise 2: Interact with SMTP via Netcat

Netcat (`nc`) lets you speak the SMTP protocol directly, exactly like a mail client does behind the scenes.

### 2.1 Test the SMTP banner

On **mail-lab-server**:

```bash
echo 'QUIT' | nc -w5 localhost 25
```

You should see a greeting like:

```
220 mail.lab ESMTP mail.lab
221 2.0.0 Bye
```

### 2.2 Send an email manually via SMTP

On **mail-lab-server**, pipe the SMTP conversation to netcat. The `sleep` commands give the server time to process each command:

```bash
{ echo 'EHLO testclient'; sleep 1; echo 'MAIL FROM:<alice@mail.lab>'; sleep 1; echo 'RCPT TO:<bob@mail.lab>'; sleep 1; echo 'DATA'; sleep 1; echo 'Subject: SMTP Test'; echo ''; echo 'Sent via raw SMTP'; echo '.'; sleep 1; echo 'QUIT'; } | nc -w15 localhost 25
```

> **Note:** The message body ends with a single dot (`.`) on a line by itself. This tells the server the message is complete.

Expected responses:

| Command | Response | Meaning |
|---------|----------|---------|
| `EHLO testclient` | `250-mail.lab` | Server identifies itself, lists capabilities |
| `MAIL FROM:<alice@mail.lab>` | `250 2.1.0 Ok` | Sender accepted |
| `RCPT TO:<bob@mail.lab>` | `250 2.1.5 Ok` | Recipient accepted |
| `DATA` | `354 End data with <CR><LF>.<CR><LF>` | Ready to receive message body |
| `.` | `250 2.0.0 Ok: queued as XXXXX` | Message accepted and queued |
| `QUIT` | `221 2.0.0 Bye` | Connection closed |

### 2.3 Verify the message arrived

On **mail-lab-server**, check bob's Maildir:

```bash
sudo bash -c 'cat /home/bob/Maildir/new/*'
```

You should see the "SMTP Test" message in the output.

### 2.4 Explore SMTP commands

Try these additional SMTP commands via netcat:

```bash
{ echo 'EHLO testclient'; sleep 1; echo 'VRFY alice'; sleep 1; echo 'VRFY bob'; sleep 1; echo 'VRFY nonexistent'; sleep 1; echo 'NOOP'; sleep 1; echo 'RSET'; sleep 1; echo 'QUIT'; } | nc -w15 localhost 25
```

---

## Exercise 3: Interact with IMAP via Netcat

IMAP is the protocol used by mutt (and Thunderbird, Outlook, etc.) to read email. You can speak it directly with netcat.

### 3.1 Connect to the IMAP server

On **mail-lab-server**:

```bash
echo 'a0 LOGOUT' | nc -w5 localhost 143
```

You should see:

```
* OK [CAPABILITY ...] Dovecot ready.
* BYE Logging out
a0 OK Logout completed.
```

### 3.2 Login and list mailboxes

Each IMAP command must start with a **tag** (any identifier, like `a1`, `a2`, etc.):

```bash
{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 LIST "" "*"'; sleep 1; echo 'a3 LOGOUT'; } | nc -w5 localhost 143
```

Expected output:

```
a1 OK [CAPABILITY ...] Logged in
* LIST (\HasNoChildren) "." "INBOX"
a2 OK List completed
```

### 3.3 Select inbox and read messages

```bash
{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 SELECT INBOX'; sleep 1; echo 'a3 LOGOUT'; } | nc -w5 localhost 143
```

The server will reply with mailbox status (number of messages, flags, etc.):

```
* 2 EXISTS              <-- number of messages
* 0 RECENT
* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
...
a2 OK [READ-WRITE] Select completed.
```

### 3.4 Fetch a message

To read message #1:

```bash
{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 SELECT INBOX'; sleep 1; echo 'a3 FETCH 1 (BODY[HEADER.FIELDS (FROM SUBJECT DATE)])'; sleep 1; echo 'a4 FETCH 1 BODY[TEXT]'; sleep 1; echo 'a5 LOGOUT'; } | nc -w5 localhost 143
```

`a3` shows headers (From, Subject, Date), `a4` shows the message body.

### 3.5 Search for messages

```bash
{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 SELECT INBOX'; sleep 1; echo 'a3 SEARCH ALL'; sleep 1; echo 'a4 SEARCH FROM "alice"'; sleep 1; echo 'a5 SEARCH SUBJECT "Hello"'; sleep 1; echo 'a6 LOGOUT'; } | nc -w5 localhost 143
```

### 3.6 Logout

```bash
{ echo 'a1 LOGIN bob labpass'; sleep 1; echo 'a2 LOGOUT'; } | nc -w5 localhost 143
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

Now send a message from the server (in another terminal) — you'll see Postfix logging each step:

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
sudo bash -c 'cat /home/alice/Maildir/new/*'
```

> **Maildir format** stores each message as a separate file. New messages go to `new/`, and after reading they move to `cur/`. This is different from the older `mbox` format which stores all messages in a single file.

---

## Exercise 6: Add a New User

### 6.1 Create user on the server

On **mail-lab-server**:

```bash
# Create the user
sudo useradd -m -s /bin/bash charlie
echo 'charlie:labpass' | sudo chpasswd

# Create Maildir
sudo mkdir -p /home/charlie/Maildir/new /home/charlie/Maildir/cur /home/charlie/Maildir/tmp
sudo chown -R charlie:charlie /home/charlie/Maildir
```

### 6.2 Test sending mail to the new user

On **mail-lab-server**, send mail as alice:

```bash
sudo -u alice bash -c 'echo "Welcome Charlie!" | mail -s "Hello Charlie" charlie@mail.lab'
```

### 6.3 Read mail as charlie (on the server)

```bash
sudo bash -c 'cat /home/charlie/Maildir/new/*'
```

---

## Troubleshooting

### nc: "Connection refused" on port 25 or 143

- Cloud-init may still be running: `cloud-init status --wait`
- Check that Postfix/Dovecot are running on the server: `systemctl status postfix dovecot`
- Verify Postfix is listening: `echo 'QUIT' | nc -w5 localhost 25`

### mail command: "send-mail: Cannot open mail:25"

- Make sure Postfix is running: `systemctl status postfix`
- Verify Postfix is listening: `echo 'QUIT' | nc -w5 localhost 25`

### mutt: "/var/mail/labuser: No such file or directory"

You are running mutt as `labuser` instead of the mail user. Switch user first on the server:

```bash
sudo -u alice bash   # to use alice's mailbox
sudo -u bob bash     # to use bob's mailbox
mutt
```

### mutt: "Login failed" or IMAP connection error

- Make sure the server has finished booting (Dovecot must be running)
- Verify credentials: user `alice`/`bob`, password `labpass`
- Test IMAP manually: `{ echo 'a1 LOGIN alice labpass'; sleep 1; echo 'a2 LOGOUT'; } | nc -w5 localhost 143`

### Messages not arriving

1. Check the mail queue on the server: `sudo postqueue -p`
2. Check the logs: `sudo tail -20 /var/log/mail.log`
3. Verify the recipient user exists: `id bob` on the server
4. Check Maildir on the server: `sudo ls /home/bob/Maildir/new/`

### General: packages not installed

If commands like `mutt` or `nc` are not found, cloud-init may still be running:

```bash
cloud-init status --wait
```
