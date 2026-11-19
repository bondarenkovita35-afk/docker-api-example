# Репетиция: полный прогон на AWS EC2 с нуля

**Цель:** пройти весь путь как на видео, найти ошибки, замерить время.
Первый раз 60–90 минут — нормально. Стоимость около 0 при Free Tier, **если в конце всё удалить**.

Все команды с объяснениями — в [GUIDE_RU.md](GUIDE_RU.md). Здесь только порядок и окна.
Если репетируете одна, играйте обе роли: Student B — во втором окне PowerShell.

## Часть 0. Что открыть

| № | Окно | Зачем |
|---|------|-------|
| 1 | Браузер: AWS Console (регион Stockholm) | EC2, Elastic IP, Billing |
| 2 | Браузер: ваш fork на GitHub | проверить файлы |
| 3 | Discord | увидеть уведомления |
| 4 | VS Code с `C:\Users\bonda\docker-api-example` | копировать конфиги из `deploy/config/` в nano |
| 5 | PowerShell «A» | SSH как ubuntu |
| 6 | PowerShell «B» | SSH как studentb |
| 7 | Блокнот | Elastic IP, пароль БД (временно), время этапов |

## Часть 1. Подготовка (один раз)

1. Пароль sudo в WSL работает (`sudo -v`).
2. **Fork** `UA-classroom/docker-api-example` → ваш аккаунт (GUIDE шаг 0.1).
3. `git remote set-url`, `git add`, `git commit`, `git push` (GUIDE шаг 0.2). Нужен Personal Access Token.
4. `robocopy` проекта в Windows (GUIDE шаг 0.3).
5. Discord webhook (GUIDE шаг 0.4).

## Часть 2. Прогон — засекайте время

| Этап | Окно | Что | GUIDE | Готово, когда |
|------|------|-----|-------|---------------|
| 1 | AWS | EC2 t3.micro, Ubuntu 24.04, key pair, SG 22 + 80 | 1 | `2/2 checks passed` |
| 2 | AWS | Elastic IP + Billing | 2 | IP записан |
| 3 | PS «A» | `icacls`, `ssh` | 3 | `ubuntu@ip-…` |
| 4 | PS «B» + «A» | ключ B, `scp` скриптов, `add_user.sh`, вход B, `who` | 4 | `who` = 2 строки |
| 5 | PS «A» | `sudo bash ~/setup.sh` | 5 | `SETUP KLAR!` |
| 6 | PS «B» | `openssl rand`, `psql`: CREATE USER / DATABASE | 6 | `\l` показывает базу |
| 7–8 | PS «B» | `git clone`, `sudo -iu fastapi_service`, `.env`, venv, pip, `setup.py` | 7–8 | `Sample data seeded` |
| 9 | PS «A» | `nano` Supervisor-конфиг, `reread`, `update` | 9 | `RUNNING` |
| 10 | PS «B» | `nano` Nginx-конфиг, `ln -s`, `nginx -t`, reload | 10 | `/docs` в браузере |
| 11 | PS «A» | backup.sh, `crontab -e`, `scp` копии | 11 | файл в «Загрузках» |
| 12 | PS «B» | monitor_system.sh, `monitor.env`, тест, `crontab -e` | 12 | сообщения в Discord |
| 13 | оба | Swagger, `smoke_test.sh`, reboot | 13 | `10 PASS`, `RUNNING` после reboot |

Ошибка → скриншот или текст целиком → [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) → прислать мне.

## Часть 3. Результаты

| Этап | Мин | Проблемы |
|------|-----|----------|
| 1–2 AWS | | |
| 3–4 SSH | | |
| 5 setup.sh | | |
| 6–8 БД + API | | |
| 9 Supervisor | | |
| 10 Nginx | | |
| 11 Backup | | |
| 12 Monitor | | |
| 13 Демо | | |
| **Итого** | | |

## Часть 4. ОБЯЗАТЕЛЬНО удалить

GUIDE шаг 14: Terminate инстанс → Release Elastic IP → удалить SG, key pair, webhook →
`ssh-keygen -R <ELASTIC-IP>` → Billing через день. На видео всё создаётся заново.
