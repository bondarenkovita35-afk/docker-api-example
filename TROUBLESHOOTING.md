# TROUBLESHOOTING – частые ошибки

Порядок: 1) прочитать сообщение целиком; 2) логи; 3) исправить; 4) повторить шаг.

Логи: `sudo tail -n 30 /var/log/fastapi_app/error.log` (API), `sudo tail /var/log/nginx/fastapi_error.log`,
`sudo tail /var/log/system_monitor.log`, `sudo tail /var/log/fastapi_backup.log`.

## SSH
| Симптом | Причина | Решение |
|---------|---------|---------|
| `Connection timed out` | нет правила 22 для вашего IP | SG → Inbound → SSH → My IP. IP: `curl.exe -s https://checkip.amazonaws.com` |
| `UNPROTECTED PRIVATE KEY FILE` | широкие права на `.pem` | `icacls $HOME\.ssh\devops-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"` |
| `Permission denied (publickey)` | не тот ключ/пользователь | A: `ubuntu@` + `.pem`; B: `studentb@` + `devops_studentb` (без `.pub`) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | новый сервер на том же IP | `ssh-keygen -R <ELASTIC-IP>` |
| Вас заблокировал fail2ban | много неудачных попыток | подождать 10 мин или с другого аккаунта: `sudo fail2ban-client set sshd unbanip <IP>` |

## setup.sh
| Симптом | Причина | Решение |
|---------|---------|---------|
| `Could not get lock /var/lib/dpkg/lock` | работают автообновления | скрипт ждёт до 5 мин; иначе подождать и повторить |
| `$'\r': command not found` | Windows-окончания строк | `sed -i 's/\r$//' ~/setup.sh` |

## PostgreSQL / API
| Симптом | Причина | Решение |
|---------|---------|---------|
| `password authentication failed for user "fastapi_user"` | пароль в `.env` ≠ пароль в БД | `sudo -u postgres psql -c "ALTER USER fastapi_user WITH PASSWORD '<пароль>';"` или исправить `.env` |
| `database "fastapi_movies_db" does not exist` | опечатка или не создана | `sudo -u postgres psql -c "\l"` |
| `permission denied for schema public` | база создана без `OWNER fastapi_user` | `sudo -u postgres psql -c "ALTER DATABASE fastapi_movies_db OWNER TO fastapi_user;"` |
| `cd: /home/fastapi_service/...: Permission denied` | папка 750, вы не fastapi_service | `sudo -iu fastapi_service`, потом `cd` |
| `error: externally-managed-environment` | `pip` вне venv | `source venv/bin/activate` |
| `Too many arguments` при `git clone` | лишняя `.` в конце (как в инструкции преподавателя) | `git clone <url> <папка>` без точки |
| дубликаты отзывов | `setup.py` запускали несколько раз | это поведение `seed_data()`; запускать один раз |

## Supervisor
| Симптом | Причина | Решение |
|---------|---------|---------|
| `fastapi_app: ERROR (no such process)` | не сделали `reread`/`update` | `sudo supervisorctl reread && sudo supervisorctl update` |
| `FATAL` / `BACKOFF` | API падает при старте | `sudo tail -n 30 /var/log/fastapi_app/error.log` |
| `Permission denied` на `start.sh` | нет права выполнения | `sudo chmod +x /home/fastapi_service/fastapi_app/deploy/start.sh` |
| `address already in use` | порт 8000 занят старым процессом | `sudo ss -tlnp | grep 8000` → `sudo kill <pid>` → `sudo supervisorctl start fastapi_app` |

## Nginx
| Симптом | Причина | Решение |
|---------|---------|---------|
| `502 Bad Gateway` | API не работает | `sudo supervisorctl status fastapi_app` |
| «Welcome to nginx!» | не удалён `default` | `sudo rm /etc/nginx/sites-enabled/default && sudo systemctl reload nginx` |
| `nginx: [emerg] ...` | синтаксис | `sudo nginx -t` показывает файл и строку |
| `/docs` не открывается | нет правила 80 или браузер перешёл на https | SG: HTTP 80; писать `http://` |

## CRON / мониторинг / backup
| Симптом | Причина | Решение |
|---------|---------|---------|
| CRON ничего не делает | ошибка в строке crontab | `sudo crontab -l`; логи: `sudo journalctl -u cron -n 30` |
| `ingen webhook konfigurerad` | пустой `monitor.env` | `sudo nano /etc/fastapi_app/monitor.env` |
| `kunde inte skicka till Discord` | неверный webhook | создать новый, обновить `monitor.env` |
| тревога не повторяется | защита от спама (60 мин) | нормально; сброс: `sudo rm /var/lib/fastapi_app_monitor.state` |
| `scp: ... Permission denied` при скачивании backup | файл принадлежит root | `sudo install -m 600 -o ubuntu <файл> ~/latest.dump`, потом `scp` |
| время CRON «не то» | сервер в UTC | `timedatectl`; 02:00 UTC = 03:00 по Швеции зимой |

## AWS
| Симптом | Причина | Решение |
|---------|---------|---------|
| нет t2.micro | регион Stockholm | `t3.micro` |
| расходы за Public IPv4 | Elastic IP не освобождён | EC2 → Elastic IPs → Release |
| не видно инстанса | другой регион | выбрать eu-north-1 / EC2 Global View |
