# TROUBLESHOOTING – common errors

Order: 1) read the whole message; 2) check logs; 3) fix; 4) repeat the step.

Logs: `sudo tail -n 30 /var/log/fastapi_app/error.log` (API), `sudo tail /var/log/nginx/fastapi_error.log`,
`sudo tail /var/log/system_monitor.log`, `sudo tail /var/log/fastapi_backup.log`.

## SSH
| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connection timed out` | no port 22 rule for your IP | SG → Inbound → SSH → My IP. IP: `curl.exe -s https://checkip.amazonaws.com` |
| `UNPROTECTED PRIVATE KEY FILE` | key permissions too open | `icacls $HOME\.ssh\devops-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"` |
| `Permission denied (publickey)` | wrong key/user | A: `ubuntu@` + `.pem`; B: `studentb@` + `devops_studentb` (not `.pub`) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | new server on the same IP | `ssh-keygen -R <ELASTIC-IP>` |
| banned by fail2ban | too many failed attempts | wait 10 min or from another account: `sudo fail2ban-client set sshd unbanip <IP>` |

## setup.sh
| Symptom | Cause | Fix |
|---------|-------|-----|
| `Could not get lock /var/lib/dpkg/lock` | automatic updates running | script waits up to 5 min; otherwise wait and rerun |
| `$'\r': command not found` | Windows line endings | `sed -i 's/\r$//' ~/setup.sh` |

## PostgreSQL / API
| Symptom | Cause | Fix |
|---------|-------|-----|
| `password authentication failed for user "fastapi_user"` | `.env` password ≠ database password | `sudo -u postgres psql -c "ALTER USER fastapi_user WITH PASSWORD '<password>';"` or fix `.env` |
| `database "fastapi_movies_db" does not exist` | typo or not created | `sudo -u postgres psql -c "\l"` |
| `permission denied for schema public` | database created without `OWNER fastapi_user` | `sudo -u postgres psql -c "ALTER DATABASE fastapi_movies_db OWNER TO fastapi_user;"` |
| `cd: /home/fastapi_service/...: Permission denied` | folder is 750 | `sudo -iu fastapi_service`, then `cd` |
| `error: externally-managed-environment` | `pip` outside venv | `source venv/bin/activate` |
| `Too many arguments` on `git clone` | trailing `.` (as in the teacher's guide) | `git clone <url> <folder>` without the dot |
| duplicate reviews | `setup.py` run several times | behaviour of `seed_data()`; run once |

## Supervisor
| Symptom | Cause | Fix |
|---------|-------|-----|
| `fastapi_app: ERROR (no such process)` | no `reread`/`update` | `sudo supervisorctl reread && sudo supervisorctl update` |
| `FATAL` / `BACKOFF` | API crashes on start | `sudo tail -n 30 /var/log/fastapi_app/error.log` |
| `Permission denied` on `start.sh` | not executable | `sudo chmod +x /home/fastapi_service/fastapi_app/deploy/start.sh` |
| `address already in use` | old process on port 8000 | `sudo ss -tlnp | grep 8000` → `sudo kill <pid>` → `sudo supervisorctl start fastapi_app` |

## Nginx
| Symptom | Cause | Fix |
|---------|-------|-----|
| `502 Bad Gateway` | API not running | `sudo supervisorctl status fastapi_app` |
| "Welcome to nginx!" | `default` not removed | `sudo rm /etc/nginx/sites-enabled/default && sudo systemctl reload nginx` |
| `nginx: [emerg] ...` | syntax error | `sudo nginx -t` shows file and line |
| `/docs` doesn't open | no port 80 rule, or browser switched to https | SG: HTTP 80; type `http://` |

## CRON / monitoring / backup
| Symptom | Cause | Fix |
|---------|-------|-----|
| CRON does nothing | error in crontab line | `sudo crontab -l`; logs: `sudo journalctl -u cron -n 30` |
| `ingen webhook konfigurerad` | empty `monitor.env` | `sudo nano /etc/fastapi_app/monitor.env` |
| `kunde inte skicka till Discord` | wrong webhook | create a new one, update `monitor.env` |
| alert not repeated | anti-spam (60 min) | expected; reset: `sudo rm /var/lib/fastapi_app_monitor.state` |
| `scp: ... Permission denied` downloading a backup | file owned by root | `sudo install -m 600 -o ubuntu <file> ~/latest.dump`, then `scp` |
| CRON time looks wrong | server uses UTC | `timedatectl`; 02:00 UTC = 03:00 Swedish winter time |

## AWS
| Symptom | Cause | Fix |
|---------|-------|-----|
| no t2.micro | Stockholm region | use `t3.micro` |
| Public IPv4 charges | Elastic IP not released | EC2 → Elastic IPs → Release |
| instance not visible | other region | select eu-north-1 / EC2 Global View |
