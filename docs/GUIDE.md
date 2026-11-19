# Step-by-step deployment guide (G level)

Based on the teacher's `Repetition - Devops` exercise and the API in `UA-classroom/docker-api-example`
(movies, users, reviews), extended with everything the G requirements ask for: SSH access from two
computers, a Bash setup script copied with `scp`, CRON backups and monitoring with Discord alerts.

## How to read the commands

| Label | Where | Prompt looks like |
|-------|-------|-------------------|
| **PowerShell** | your Windows computer | `PS C:\Users\<name>>` |
| **EC2** | the AWS server over SSH | `ubuntu@ip-…:~$` or `studentb@ip-…:~$` |
| **EC2 as fastapi_service** | after `sudo -iu fastapi_service` | `fastapi_service@ip-…:~$` |
| **WSL** | Linux on your own computer | `<user>@<computer>:~$` |

- Replace everything in `<...>` with your own value, including the brackets.
- In PowerShell, use `curl.exe`, not `curl`.
- Teacher's rule: config files are created by `cd` into the folder, `sudo nano <file>`, paste, save — not with a one-line command that writes the file.

## Names used in the project

| What | Name / path |
|------|-------------|
| User that runs the API | `fastapi_service` |
| Project folder on the server | `/home/fastapi_service/fastapi_app` |
| API folder | `/home/fastapi_service/fastapi_app/api` |
| Database password file | `/home/fastapi_service/fastapi_app/api/.env` (mode 600) |
| Database / database user | `fastapi_movies_db` / `fastapi_user` |
| Process manager | Supervisor, program `fastapi_app` |
| Supervisor config | `/etc/supervisor/conf.d/fastapi_app.conf` |
| Nginx config | `/etc/nginx/sites-available/fastapi_app` |
| CRON scripts | `/usr/local/bin/backup.sh`, `/usr/local/bin/monitor_system.sh` |
| Discord webhook | `/etc/fastapi_app/monitor.env` (mode 600) |
| Backups | `/var/backups/fastapi_app/db` and `/logs` |
| Logs | `/var/log/fastapi_app/`, `/var/log/system_monitor.log`, `/var/log/fastapi_backup.log` |

## Differences from the teacher's guide (and why)

| Teacher's guide | Here | Why |
|-----------------|------|-----|
| `t2.micro` | `t3.micro` | t2 is not available in Stockholm (eu-north-1); t3.micro is also free tier |
| port 8000 open to everyone | port 8000 **not** opened | Uvicorn listens on `127.0.0.1` only; all traffic goes through Nginx |
| `setup.sh` written with `nano` on the server | `setup.sh` prepared and copied with `scp` | G requirement 3 |
| SSH hardening edited in `sshd_config` | `setup.sh` writes a file in `/etc/ssh/sshd_config.d/` | main file untouched; validated with `sshd -t` before reload |
| `ChallengeResponseAuthentication no` | `KbdInteractiveAuthentication no` | the old name is deprecated on Ubuntu 24.04 |
| `/var/www/fastapi_app` | `/home/fastapi_service/fastapi_app` | G requirement 4: clone into a user's home folder |
| database user `postgres` | separate `fastapi_user` (database owner) | the API should not have database admin rights |
| `start.sh` runs `setup.py` on every start | `setup.py` is run **once** by hand | tested: every run inserts the sample reviews again (duplicates) |
| `--workers 2` | `--workers 1` | tested: with 2 workers, a crash of the master left port 8000 busy and Supervisor could not restart the API; 1 GB RAM is enough for 1 worker |
| monitoring only writes a log | log **+ Discord** + SSH failure check | G requirement 6 |
| no backup | `backup.sh` + CRON + copy to own computer with `scp` | G requirement 5 |
| `git clone ... /var/www/fastapi_app .` | no trailing dot | with the dot git fails with `Too many arguments` |

---

## Step 0. Before the recording

### 0.1 Repository

The project is in a public fork: https://github.com/bondarenkovita35-afk/docker-api-example
A public repository can be cloned over HTTPS without keys or tokens. It contains no secrets.

### 0.2 Local copy on Windows (for `scp` and for copying configs into nano)

**PowerShell**
```powershell
git clone https://github.com/bondarenkovita35-afk/docker-api-example.git $HOME\docker-api-example
```
Open the folder in VS Code; you will copy the contents of `deploy/config/...` from there into `nano` on the server.

### 0.3 Discord webhook

Discord → your server → **Server Settings** → **Integrations** → **Webhooks** → **New Webhook** →
choose a channel → **Copy Webhook URL**. Keep it private. Delete the webhook after the exam.

### 0.4 Student B's public IP

**PowerShell**
```powershell
curl.exe -s https://checkip.amazonaws.com
```
Send the IP to Student A for the Security Group rule. Check again on recording day (it changes with the network).

---

## Step 1. EC2 (Student A)

Concepts:
- **AMI** — disk image with the operating system: *Ubuntu Server 24.04 LTS*.
- **Instance type** — server size: `t3.micro` = 2 vCPU, 1 GB RAM, free tier.
- **Key pair** — SSH keys: AWS puts the public key on the server, you download the private `.pem` (only once).
- **Security Group** — AWS firewall around the instance.
- **Elastic IP** — a fixed public IP (step 2).

AWS Console:
1. Region **Europe (Stockholm) eu-north-1**.
2. **EC2 → Launch instances**, name `fastapi-devops`.
3. AMI: **Ubuntu Server 24.04 LTS**, 64-bit (x86), *Free tier eligible*.
4. Instance type: **t3.micro**.
5. Key pair → **Create new key pair**: `devops-key`, **ED25519**, **.pem**.
6. Network settings → **Edit** → create security group `fastapi-devops-sg`:
   - SSH, 22, **My IP** (Student A)
   - SSH, 22, Custom `<IP-Student-B>/32`
   - HTTP, 80, Anywhere-IPv4 `0.0.0.0/0`
   - do **not** open 8000 or 5432.
7. Storage 8 GiB gp3 → **Launch instance**. Wait for `Running` and `2/2 checks passed`.

## Step 2. Elastic IP and costs

1. **EC2 → Elastic IPs → Allocate Elastic IP address → Allocate**.
2. **Actions → Associate Elastic IP address** → instance `fastapi-devops` → **Associate**.
3. Note the address — this is `<ELASTIC-IP>`.
4. **Billing and Cost Management → Free Tier** and **Bills**: costs close to 0.
   Public IPv4 addresses (including unused Elastic IPs) cost about 0.005 USD/hour if not covered by the free tier — release after the exam.

---

## Step 3. SSH for Student A

**PowerShell**
```powershell
New-Item -ItemType Directory -Force $HOME\.ssh
Move-Item $HOME\Downloads\devops-key.pem $HOME\.ssh\
icacls $HOME\.ssh\devops-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
ssh -i $HOME\.ssh\devops-key.pem ubuntu@<ELASTIC-IP>
```
- `icacls` makes the key readable only by you (like `chmod 400`); otherwise SSH refuses it with `UNPROTECTED PRIVATE KEY FILE`.
- Answer `yes` to the fingerprint question. Expected prompt: `ubuntu@ip-…:~$`.

## Step 4. SSH for Student B (second computer)

**PowerShell, Student B**
```powershell
ssh-keygen -t ed25519 -f $HOME\.ssh\devops_studentb -C "studentb"
Get-Content $HOME\.ssh\devops_studentb.pub
```
Send only the public key (one line starting with `ssh-ed25519`) to Student A. The private key never leaves B's computer.

**PowerShell, Student A** — copy the scripts to the server:
```powershell
cd $HOME\docker-api-example\deploy\scripts
scp -i $HOME\.ssh\devops-key.pem setup.sh add_user.sh ubuntu@<ELASTIC-IP>:~/
```

**EC2, Student A**
```bash
nano ~/studentb.pub          # paste B's key, Ctrl+O, Enter, Ctrl+X
sudo bash ~/add_user.sh studentb ~/studentb.pub --sudo
```
`add_user.sh` creates the user, `.ssh` (700) and `authorized_keys` (600), and gives sudo via `/etc/sudoers.d/` (validated with `visudo -c`).

**PowerShell, Student B**
```powershell
ssh -i $HOME\.ssh\devops_studentb studentb@<ELASTIC-IP>
```

**EC2**
```bash
who
```
Expected: two lines, `ubuntu` and `studentb`, from different IPs.

---

## Step 5. setup.sh (Student A)

What it does: updates the system; installs Python, venv, pip, PostgreSQL, Supervisor, Nginx, Git,
fail2ban, logrotate, curl, jq, ufw; creates `fastapi_service`; creates log/backup/secret folders;
installs aliases; SSH keys only; fail2ban; UFW (22 and 80); 1 GB swap; verifies everything at the end.
`set -Eeuo pipefail` stops on the first error. Safe to run again.

**EC2**
```bash
sudo bash ~/setup.sh
cat /etc/ssh/sshd_config.d/10-devops-hardening.conf
sudo fail2ban-client status sshd
sudo ufw status
source /etc/profile.d/devops-aliases.sh
```
Expected: `SETUP KLAR!`, the SSH settings, `Currently banned: 0`, `Status: active` with OpenSSH and 80/tcp.

---

## Step 6. PostgreSQL (Student B)

**EC2**
```bash
openssl rand -hex 16        # random password, copy it
sudo -u postgres psql       # admin console (peer authentication)
```
In `postgres=#`:
```sql
CREATE USER fastapi_user WITH PASSWORD '<password>';
CREATE DATABASE fastapi_movies_db OWNER fastapi_user;
\l
\q
```
```bash
sudo ss -tlnp | grep 5432
```
Expected: `127.0.0.1:5432` — PostgreSQL is reachable only from the server itself.

## Step 7. Clone the API (Student B)

**EC2**
```bash
sudo -u fastapi_service git clone https://github.com/bondarenkovita35-afk/docker-api-example.git /home/fastapi_service/fastapi_app
```
Cloned as `fastapi_service`, so the files belong to that user and not to root.

## Step 8. .env, venv, tables (Student B)

**EC2**
```bash
sudo -iu fastapi_service    # shell as fastapi_service
```
**EC2 as fastapi_service**
```bash
cd fastapi_app/api
cp ../.env.example .env
nano .env                   # set PASSWORD= to the password from step 6
chmod 600 .env
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 setup.py            # creates 5 tables + sample data, run ONCE
exit
```
Expected: `Tables created successfully.` and `Sample data seeded successfully.`

---

## Step 9. Supervisor — process manager (Student A)

Why a process manager: a plain `uvicorn` in the terminal stops when SSH closes. Supervisor runs the API
in the background, restarts it if it crashes (`autorestart`) and after a reboot (`autostart`).

**EC2**
```bash
sudo cat /home/fastapi_service/fastapi_app/deploy/start.sh
cd /etc/supervisor/conf.d
sudo nano fastapi_app.conf          # paste deploy/config/fastapi_app.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl status fastapi_app
curl http://127.0.0.1:8000/status
```
Expected: `fastapi_app: available`, `added process group`, `RUNNING`, `{"message":"OK"}`.

## Step 10. Nginx reverse proxy (Student B)

Uvicorn runs the Python code. Nginx receives internet traffic on port 80 (later 443) and forwards it to
Uvicorn. Only one program can use a port, so Nginx routes traffic to the right application. It is fast
(written in C), logs every request and can add rate limiting, caching and HTTPS.

**EC2**
```bash
sudo rm /etc/nginx/sites-enabled/default
cd /etc/nginx/sites-available
sudo nano fastapi_app               # paste deploy/config/nginx_fastapi_app
sudo ln -s /etc/nginx/sites-available/fastapi_app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```
**PowerShell**
```powershell
curl.exe http://<ELASTIC-IP>/status
curl.exe -m 5 http://<ELASTIC-IP>:8000/status
```
Expected: `{"message":"OK"}` on port 80, and a timeout on port 8000 (closed — good).
Browser: `http://<ELASTIC-IP>/docs` → Swagger UI.

---

## Step 11. Backup + CRON (Student A)

**EC2**
```bash
sudo cp /home/fastapi_service/fastapi_app/deploy/scripts/backup.sh /usr/local/bin/backup.sh
sudo chmod 750 /usr/local/bin/backup.sh
sudo /usr/local/bin/backup.sh
sudo crontab -e
```
Add the line from `deploy/config/crontab.txt`:
```
0 2 * * * /usr/local/bin/backup.sh >> /var/log/fastapi_backup.log 2>&1
```
The script is owned by root in `/usr/local/bin`, so `fastapi_service` cannot change a script that root runs.
Format: minute hour day month weekday command → every day at 02:00 (UTC).

**Copy a backup to your own computer** (a backup on the same server is not enough):
```bash
sudo ls /var/backups/fastapi_app/db
sudo install -m 600 -o ubuntu /var/backups/fastapi_app/db/<file>.dump ~/latest.dump
```
**PowerShell**
```powershell
scp -i $HOME\.ssh\devops-key.pem ubuntu@<ELASTIC-IP>:~/latest.dump $HOME\Downloads\
```
**EC2**
```bash
rm ~/latest.dump
```

**Restore (explain):**
`sudo supervisorctl stop fastapi_app` →
`sudo cat <file>.dump | sudo -u postgres pg_restore --clean --if-exists -d fastapi_movies_db` →
`sudo supervisorctl start fastapi_app`.

---

## Step 12. Monitoring + Discord (Student B)

`monitor_system.sh` checks disk, CPU, RAM, `/status` through Nginx, `fastapi_app` in Supervisor, nginx
and postgresql, and **failed SSH logins in the last 5 minutes** (5 or more → alert). It writes to
`/var/log/system_monitor.log` and sends Discord messages. The same alert is repeated at most once an
hour; when everything is fine again it sends "Återställt".

**EC2**
```bash
sudo cp /home/fastapi_service/fastapi_app/deploy/scripts/monitor_system.sh /usr/local/bin/monitor_system.sh
sudo chmod 750 /usr/local/bin/monitor_system.sh
sudo nano /etc/fastapi_app/monitor.env        # DISCORD_WEBHOOK_URL=<your webhook>
sudo chmod 600 /etc/fastapi_app/monitor.env
sudo monitor_system.sh --test
sudo DISK_THRESHOLD=0 monitor_system.sh --verbose
sudo monitor_system.sh --verbose
sudo crontab -e                                # add: */5 * * * * /usr/local/bin/monitor_system.sh
sudo tail -f /var/log/system_monitor.log
```
Expected in Discord: test message, an alert (disk ≥ 0 %), then "Återställt".
Do not keep the webhook URL on screen; delete the webhook after recording.

---

## Step 13. Demo (both)

Swagger at `http://<ELASTIC-IP>/docs`:
1. **GET /movies** → 200, 8 movies.
2. **POST /users** → `{"username": "vitaliia"}` → 201.
3. **POST /reviews** → `{"user_id": 4, "movie_id": 1, "rating": 5, "review_text": "Bra film!"}` → 201.
4. **GET /movie/999** → 404 `Movie not found`.

**EC2**
```bash
sudo -u postgres psql -d fastapi_movies_db -c "SELECT id, username FROM users;"
sudo bash /home/fastapi_service/fastapi_app/deploy/scripts/smoke_test.sh
sudo reboot
```
After about a minute, reconnect (same Elastic IP):
```bash
sudo supervisorctl status fastapi_app
systemctl is-active nginx postgresql supervisor
```
Expected: `10 PASS, 0 FAIL`; after reboot `RUNNING` and three times `active`.

---

## HTTPS — what to understand (explain for G, implement for VG)

- **HTTP** sends data in plain text; anyone on the path can read it.
- **HTTPS** = HTTP + **TLS encryption**, port **443**.
- A **certificate** proves the server is really `example.se`; issued by a certificate authority such as **Let's Encrypt**.
- Certificates are issued for a **domain**, so proper HTTPS needs your own domain (VG).
- How (VG): buy a domain → DNS A record to the Elastic IP → `sudo apt install certbot python3-certbot-nginx` → `sudo certbot --nginx -d <domain>` → open 443 in the Security Group.

---

## Step 14. After recording: delete AWS resources

1. **Instances** → **Terminate (delete) instance**.
2. **Elastic IPs** → **Release Elastic IP addresses**.
3. **Volumes** and **Snapshots** — empty.
4. **Security Groups** → delete `fastapi-devops-sg`.
5. **Key Pairs** → delete `devops-key`; delete the `.pem` and `devops_studentb*` files on Windows.
6. PowerShell: `ssh-keygen -R <ELASTIC-IP>`.
7. Discord → delete the webhook.
8. **Billing → Bills** after 1–2 days: 0.
