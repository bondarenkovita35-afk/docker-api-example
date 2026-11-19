# CHECKLIST – готовность (уровень G)

Этот файл можно держать открытым во время записи (это разрешено — «enkel checklista»).

## A. До записи
- [ ] Принять приглашение UA Classroom, создать **team**, вписать пару в документ преподавателя
- [ ] Fork `UA-classroom/docker-api-example` в свой аккаунт, партнёр добавлен как collaborator
- [ ] Наши файлы отправлены в fork (`git push`), в GitHub НЕТ `.env`, `.pem`, `venv/`
- [ ] У обоих есть копия проекта на Windows (для `scp` и копирования конфигов)
- [ ] Discord webhook создан; партнёр в Discord-сервере
- [ ] Student B знает свой публичный IP
- [ ] Репетиция с нуля сделана, время: ____ мин. После неё всё удалено в AWS
- [ ] Камера у обоих, звук проверен, шрифт терминала крупный
- [ ] Посмотрено повторительное видео преподавателя

## B. Во время записи
**AWS / SSH**
- [ ] Ubuntu 24.04, t3.micro, key pair, SG: 22 (IP A, IP B), 80 (все), без 8000/5432
- [ ] Elastic IP привязан; показан Billing / Free Tier
- [ ] `icacls` на ключ, вход A (`ubuntu`) и B (`studentb`), `who` показывает обоих

**setup.sh**
- [ ] `scp setup.sh add_user.sh` → `sudo bash ~/setup.sh` → `SETUP KLAR!`
- [ ] Показаны: SSH-настройки, `fail2ban-client status sshd`, `ufw status`, aliases

**PostgreSQL / API**
- [ ] `CREATE USER fastapi_user`, `CREATE DATABASE fastapi_movies_db OWNER fastapi_user`
- [ ] `ss -tlnp | grep 5432` → только 127.0.0.1
- [ ] `git clone` в `/home/fastapi_service/fastapi_app`
- [ ] `.env` (600), venv, `pip install`, `python3 setup.py` один раз

**Supervisor / Nginx**
- [ ] `nano /etc/supervisor/conf.d/fastapi_app.conf` → `reread`, `update` → `RUNNING`
- [ ] `nano /etc/nginx/sites-available/fastapi_app` → `ln -s` → `nginx -t` → `reload`
- [ ] `http://<ELASTIC-IP>/docs` работает; `:8000` — timeout

**Backup / мониторинг**
- [ ] `backup.sh` в `/usr/local/bin`, ручной запуск OK, строка в `sudo crontab -e`
- [ ] Копия дампа скачана на Windows через `scp`; восстановление объяснено
- [ ] `monitor_system.sh` + `monitor.env` (600); Discord: тест, тревога, «Återställt»
- [ ] Строка `*/5` в crontab, запись от CRON в `/var/log/system_monitor.log`

**Демо**
- [ ] Swagger: GET /movies, POST /users, POST /reviews, 404 на /movie/999
- [ ] `psql SELECT` показывает данные; `smoke_test.sh` → `10 PASS, 0 FAIL`
- [ ] `sudo reboot` → `supervisorctl status` → RUNNING

## C. Безопасность (сказать)
- [ ] Открыты только 22 (наши IP) и 80; UFW + fail2ban
- [ ] SSH только по ключам, root не может войти
- [ ] API от `fastapi_service`, БД-пользователь не администратор
- [ ] Секреты только на сервере (`.env`, `monitor.env`), не в GitHub, не на экране
- [ ] HTTPS объяснён

## D. Каждый может объяснить
- [ ] Путь запроса: браузер → Security Group → UFW → Nginx :80 → Uvicorn 127.0.0.1:8000 → FastAPI → PostgreSQL
- [ ] Зачем process manager, reverse proxy, venv, `.env`, CRON, Elastic IP
- [ ] Права: 600, 700, 750; `sudo`, `sudo -u`, `sudo -iu`
- [ ] Чем наше решение отличается от инструкции преподавателя (таблица в GUIDE_RU)

## E. После записи
- [ ] Видео ≤ 60 мин, оба видны и слышны, текст читается, ссылка открывается без запроса доступа
- [ ] Instance terminated, Elastic IP released, SG и key pair удалены, webhook удалён
- [ ] Billing проверен через 1–2 дня
