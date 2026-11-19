# Пошаговое руководство (на русском) — уровень G

Это руководство для подготовки и для самой видеозаписи. Основа — повторительная инструкция
преподавателя (`Repetition - Devops`) и его API `docker-api-example` (фильмы, пользователи, отзывы).
К ней добавлено всё, чего не хватает для G: SSH для двух компьютеров, Bash-скрипт через `scp`,
backup через CRON, мониторинг с Discord.

## Как читать команды

| Метка | Где это | Как выглядит приглашение |
|-------|---------|--------------------------|
| **Windows PowerShell** | ваш Windows-компьютер | `PS C:\Users\<ваше-имя>>` |
| **Linux Ubuntu на EC2** | сервер в AWS (по SSH) | `ubuntu@ip-172-31-…:~$` или `studentb@ip-…:~$` |
| **Ubuntu на EC2 как fastapi_service** | после `sudo -iu fastapi_service` | `fastapi_service@ip-…:~$` |
| **Ubuntu WSL** | Linux на вашем компьютере | `bonda@Vitaliia:~$` |

- Всё в `<...>` — **заменить своим значением вместе со скобками**. `<ELASTIC-IP>` — ваш Elastic IP, `<ditt-github-namn>` — логин GitHub.
- Строка «По пробелам» показывает пробелы. Слово ПРОБЕЛ печатать не нужно.
- В PowerShell пишите `curl.exe`, а не `curl`.
- **Правило преподавателя:** конфигурационные файлы создаём так: `cd` в папку → `sudo nano <файл>` → вставить текст → сохранить. Не одной «волшебной» командой.

## Имена в проекте (запомнить)

| Что | Имя / путь |
|-----|-----------|
| Пользователь, от которого работает API | `fastapi_service` |
| Папка проекта на сервере | `/home/fastapi_service/fastapi_app` |
| Папка API (Python) | `/home/fastapi_service/fastapi_app/api` |
| Файл с паролем БД | `/home/fastapi_service/fastapi_app/api/.env` (права 600) |
| База данных / пользователь БД | `fastapi_movies_db` / `fastapi_user` |
| Process manager | Supervisor, программа `fastapi_app` |
| Конфиг Supervisor | `/etc/supervisor/conf.d/fastapi_app.conf` |
| Конфиг Nginx | `/etc/nginx/sites-available/fastapi_app` |
| Скрипты для CRON | `/usr/local/bin/backup.sh`, `/usr/local/bin/monitor_system.sh` |
| Discord webhook | `/etc/fastapi_app/monitor.env` (права 600) |
| Backup | `/var/backups/fastapi_app/db` и `/logs` |
| Логи | `/var/log/fastapi_app/`, `/var/log/system_monitor.log`, `/var/log/fastapi_backup.log` |

## Чем мы отличаемся от инструкции преподавателя (и почему)

| Инструкция преподавателя | У нас | Почему (это можно сказать на видео) |
|--------------------------|-------|-------------------------------------|
| `t2.micro` | `t3.micro` | в Stockholm (eu-north-1) нет t2. t3.micro тоже Free tier |
| порт 8000 открыт для всех | порт 8000 **не открываем** | Uvicorn слушает только `127.0.0.1`. Снаружи — только через Nginx. Меньше открытых портов — меньше риск |
| `setup.sh` пишется через `nano` на сервере | `setup.sh` готов заранее, передаём `scp` | так требует задание G (п. 3) |
| SSH-защита вручную в `sshd_config` | `setup.sh` пишет файл в `/etc/ssh/sshd_config.d/` | основной файл не трогаем; настройку проверяем `sshd -t` перед применением |
| `ChallengeResponseAuthentication no` | `KbdInteractiveAuthentication no` | в Ubuntu 24.04 старое имя устарело |
| папка `/var/www/fastapi_app` | `/home/fastapi_service/fastapi_app` | задание G: «клонировать в home-папку пользователя» |
| БД-пользователь `postgres` | отдельный `fastapi_user` (владелец базы) | API не должен работать с правами администратора БД |
| `start.sh` каждый раз запускает `setup.py` | `setup.py` запускаем **один раз** вручную | мы проверили: при каждом запуске `setup.py` добавляет отзывы заново (дубликаты) |
| `--workers 2` | `--workers 1` | мы проверили: с 2 workers после падения главного процесса порт 8000 остаётся занят, и Supervisor не может перезапустить API. На 1 GB RAM 1 worker достаточно |
| мониторинг пишет только в лог | лог **+ Discord** + проверка SSH-атак | задание G (п. 6) |
| нет backup | `backup.sh` + CRON + копия на свой компьютер через `scp` | задание G (п. 5) |
| `git clone ... /var/www/fastapi_app .` | без точки в конце | с точкой будет ошибка `Too many arguments` |

---

## Шаг 0. Подготовка ДО видео

### 0.1 Fork репозитория преподавателя (в браузере)

1. Откройте https://github.com/UA-classroom/docker-api-example
2. Справа вверху **Fork** → Owner: ваш аккаунт → **Create fork**.
3. Получится `https://github.com/<ditt-github-namn>/docker-api-example` — **ваш** репозиторий.
4. Добавьте партнёра: в вашем fork → **Settings** → **Collaborators** → **Add people** → логин партнёра → роль **Write**. Партнёр принимает приглашение.

### 0.2 Отправить наш проект в ваш fork (Ubuntu WSL)

Проект уже лежит в `/home/bonda/docker-api-example`: это клон репозитория преподавателя плюс наши файлы (`deploy/`, `docs/` и т.д.).

**Команда 1.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
cd ~/docker-api-example
```

По пробелам:

```text
cd ПРОБЕЛ ~/docker-api-example
```

- **Что делает:** Переходим в папку проекта.
- **Ожидаемый результат:** `bonda@Vitaliia:~/docker-api-example$`


**Команда 2.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git status
```

По пробелам:

```text
git ПРОБЕЛ status
```

- **Что делает:** Показывает, что изменено и что добавлено по сравнению с репозиторием преподавателя.
- **Ожидаемый результат:** `modified: .env.example`, `.gitignore`, `api/requirements.txt`, `api/setup.py` и `Untracked files: deploy/ docs/ ...`. Нет `.env`, `venv/`, `.pem`.


**Команда 3.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git remote set-url origin https://github.com/<ditt-github-namn>/docker-api-example.git
```

По пробелам:

```text
git ПРОБЕЛ remote ПРОБЕЛ set-url ПРОБЕЛ origin ПРОБЕЛ https://github.com/<ditt-github-namn>/docker-api-example.git
```

- **Что делает:** Меняет адрес «origin»: теперь `git push` пойдёт в ВАШ fork, а не к преподавателю.
- **Ожидаемый результат:** Ничего не выводит. Проверка: `git remote -v`.


**Команда 4.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git config --global user.name "<Ditt Namn>"
```

По пробелам:

```text
git ПРОБЕЛ config ПРОБЕЛ --global ПРОБЕЛ user.name ПРОБЕЛ "<Ditt ПРОБЕЛ Namn>"
```

- **Что делает:** Ваше имя для коммитов (один раз на компьютер).
- **Ожидаемый результат:** Ничего не выводит.


**Команда 5.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git config --global user.email "<din-epost-från-github>"
```

По пробелам:

```text
git ПРОБЕЛ config ПРОБЕЛ --global ПРОБЕЛ user.email ПРОБЕЛ "<din-epost-från-github>"
```

- **Что делает:** Ваш e-mail для коммитов.
- **Ожидаемый результат:** Ничего не выводит.


**Команда 6.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git add .
```

По пробелам:

```text
git ПРОБЕЛ add ПРОБЕЛ .
```

- **Что делает:** Подготавливает все изменения к коммиту (кроме файлов из `.gitignore`).
- **Ожидаемый результат:** Ничего не выводит.


**Команда 7.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git commit -m "Lägg till deployment-skript och konfiguration"
```

По пробелам:

```text
git ПРОБЕЛ commit ПРОБЕЛ -m ПРОБЕЛ "Lägg ПРОБЕЛ till ПРОБЕЛ deployment-skript ПРОБЕЛ och ПРОБЕЛ konfiguration"
```

- **Что делает:** Сохраняет снимок изменений локально.
- **Ожидаемый результат:** `[main abc1234] Lägg till deployment-skript ...` и число файлов.


**Команда 8.** **Ubuntu WSL на вашем компьютере** — приглашение: `bonda@Vitaliia:~$`

```bash
git push origin main
```

По пробелам:

```text
git ПРОБЕЛ push ПРОБЕЛ origin ПРОБЕЛ main
```

- **Что делает:** Отправляет коммит в ваш fork на GitHub.
- **Ожидаемый результат:** Username = логин GitHub, Password = **Personal Access Token** (не пароль!). В конце `main -> main`.


### 0.3 Копия проекта в Windows (для `scp` и для копирования конфигов в nano)

**Команда 9.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
robocopy \\wsl.localhost\Ubuntu\home\bonda\docker-api-example $HOME\docker-api-example /E /XD venv .git
```

По пробелам:

```text
robocopy ПРОБЕЛ \\wsl.localhost\Ubuntu\home\bonda\docker-api-example ПРОБЕЛ $HOME\docker-api-example ПРОБЕЛ /E ПРОБЕЛ /XD ПРОБЕЛ venv ПРОБЕЛ .git
```

- **Что делает:** Копирует проект из WSL в `C:\Users\<имя>\docker-api-example` без `venv` и `.git`. Партнёр вместо этого делает `git clone` вашего fork у себя или скачивает ZIP с GitHub.
- **Ожидаемый результат:** Итоговая таблица robocopy, в строке `Files` число файлов, без `ERROR`.


Откройте эту папку в VS Code: оттуда вы будете **копировать** содержимое конфигов (`deploy/config/...`) и вставлять в `nano` на сервере.

### 0.4 Discord webhook

Discord → ваш сервер → **Server Settings** → **Integrations** → **Webhooks** → **New Webhook** →
выберите канал → **Copy Webhook URL**. Сохраните в надёжном месте. После экзамена webhook удалить.

### 0.5 Student B узнаёт свой публичный IP

**Команда 10.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
curl.exe -s https://checkip.amazonaws.com
```

По пробелам:

```text
curl.exe ПРОБЕЛ -s ПРОБЕЛ https://checkip.amazonaws.com
```

- **Что делает:** Показывает ваш публичный IP. Он нужен для правила SSH в Security Group.
- **Ожидаемый результат:** Один IP-адрес. Отправьте его Student A. В день записи проверьте снова: IP меняется при смене сети.


---

## Шаг 1. EC2 (Student A)

Понятия:
- **AMI** — шаблон диска с ОС: *Ubuntu Server 24.04 LTS*.
- **Instance type** — размер сервера: `t3.micro` = 2 vCPU, 1 GB RAM, Free tier.
- **Key pair** — SSH-ключи: публичный AWS кладёт на сервер, приватный `.pem` скачиваете вы (один раз!).
- **Security Group** — firewall AWS вокруг инстанса.
- **Elastic IP** — постоянный публичный IP (шаг 2).

AWS Console:
1. Регион **Europe (Stockholm) eu-north-1**.
2. **EC2 → Launch instances**, Name `fastapi-devops`.
3. AMI: **Ubuntu Server 24.04 LTS**, 64-bit (x86), метка *Free tier eligible*.
4. Instance type: **t3.micro**.
5. Key pair → **Create new key pair**: `devops-key`, **ED25519**, **.pem**.
6. Network settings → **Edit** → Create security group `fastapi-devops-sg`:
   - SSH, 22, **My IP** (IP Student A)
   - SSH, 22, Custom `<IP-Student-B>/32`
   - HTTP, 80, Anywhere-IPv4 `0.0.0.0/0`
   - 8000 и 5432 **не открываем**.
7. Storage 8 GiB gp3 → **Launch instance**. Ждём `Running` и `2/2 checks passed`.

## Шаг 2. Elastic IP и расходы (Student B)

1. **EC2 → Elastic IPs → Allocate Elastic IP address → Allocate**.
2. **Actions → Associate Elastic IP address** → instance `fastapi-devops` → **Associate**.
3. Записать IP — это `<ELASTIC-IP>`.
4. **Billing and Cost Management → Free Tier** и **Bills**: расходы около 0.
   Публичный IPv4 (и неиспользуемый Elastic IP) стоит ~0,005 USD/час, если не покрыт Free Tier → после экзамена **Release**.

---

## Шаг 3. SSH Student A

**Команда 11.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
New-Item -ItemType Directory -Force $HOME\.ssh
```

По пробелам:

```text
New-Item ПРОБЕЛ -ItemType ПРОБЕЛ Directory ПРОБЕЛ -Force ПРОБЕЛ $HOME\.ssh
```

- **Что делает:** Создаёт папку для ключей, если её нет.
- **Ожидаемый результат:** Строка с `.ssh`.


**Команда 12.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
Move-Item $HOME\Downloads\devops-key.pem $HOME\.ssh\
```

По пробелам:

```text
Move-Item ПРОБЕЛ $HOME\Downloads\devops-key.pem ПРОБЕЛ $HOME\.ssh\
```

- **Что делает:** Переносит приватный ключ из «Загрузок» в `.ssh`. Ключ никогда не кладём в репозиторий.
- **Ожидаемый результат:** Ничего не выводит.


**Команда 13.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
icacls $HOME\.ssh\devops-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

По пробелам:

```text
icacls ПРОБЕЛ $HOME\.ssh\devops-key.pem ПРОБЕЛ /inheritance:r ПРОБЕЛ /grant:r ПРОБЕЛ "$($env:USERNAME):(R)"
```

- **Что делает:** Права на файл в Windows: только вы можете его читать (аналог `chmod 400`). Иначе SSH скажет `UNPROTECTED PRIVATE KEY FILE`.
- **Ожидаемый результат:** `Successfully processed 1 files; Failed processing 0 files`.


**Команда 14.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
ssh -i $HOME\.ssh\devops-key.pem ubuntu@<ELASTIC-IP>
```

По пробелам:

```text
ssh ПРОБЕЛ -i ПРОБЕЛ $HOME\.ssh\devops-key.pem ПРОБЕЛ ubuntu@<ELASTIC-IP>
```

- **Что делает:** Подключение к серверу ключом `-i` как пользователь `ubuntu`.
- **Ожидаемый результат:** `yes` на вопрос о fingerprint → `ubuntu@ip-…:~$`.


## Шаг 4. SSH Student B (второй компьютер)

**Student B на своём компьютере:**

**Команда 15.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
ssh-keygen -t ed25519 -f $HOME\.ssh\devops_studentb -C "studentb"
```

По пробелам:

```text
ssh-keygen ПРОБЕЛ -t ПРОБЕЛ ed25519 ПРОБЕЛ -f ПРОБЕЛ $HOME\.ssh\devops_studentb ПРОБЕЛ -C ПРОБЕЛ "studentb"
```

- **Что делает:** Создаёт пару ключей Ed25519. Passphrase можно задать (безопаснее) или нажать Enter 2 раза.
- **Ожидаемый результат:** Файлы `devops_studentb` (приватный, никому) и `devops_studentb.pub` (публичный).


**Команда 16.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
Get-Content $HOME\.ssh\devops_studentb.pub
```

По пробелам:

```text
Get-Content ПРОБЕЛ $HOME\.ssh\devops_studentb.pub
```

- **Что делает:** Показывает публичный ключ — его отправляем Student A (это не секрет).
- **Ожидаемый результат:** Одна строка `ssh-ed25519 AAAA... studentb`.


**Student A передаёт скрипты** (новое окно PowerShell, из папки проекта):

**Команда 17.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
cd $HOME\docker-api-example\deploy\scripts
```

По пробелам:

```text
cd ПРОБЕЛ $HOME\docker-api-example\deploy\scripts
```

- **Что делает:** Переходим в папку со скриптами на Windows.
- **Ожидаемый результат:** `PS C:\Users\<имя>\docker-api-example\deploy\scripts>`


**Команда 18.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
scp -i $HOME\.ssh\devops-key.pem setup.sh add_user.sh ubuntu@<ELASTIC-IP>:~/
```

По пробелам:

```text
scp ПРОБЕЛ -i ПРОБЕЛ $HOME\.ssh\devops-key.pem ПРОБЕЛ setup.sh ПРОБЕЛ add_user.sh ПРОБЕЛ ubuntu@<ELASTIC-IP>:~/
```

- **Что делает:** `scp` копирует файлы через SSH в домашнюю папку `ubuntu` на сервере.
- **Ожидаемый результат:** Две строки `100%`.


**Student A на сервере:**

**Команда 19.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
nano ~/studentb.pub
```

По пробелам:

```text
nano ПРОБЕЛ ~/studentb.pub
```

- **Что делает:** Открывает редактор: вставить строку ключа Student B (правая кнопка мыши), Ctrl+O, Enter, Ctrl+X.
- **Ожидаемый результат:** `cat ~/studentb.pub` показывает одну строку `ssh-ed25519 ...`.


**Команда 20.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo bash ~/add_user.sh studentb ~/studentb.pub --sudo
```

По пробелам:

```text
sudo ПРОБЕЛ bash ПРОБЕЛ ~/add_user.sh ПРОБЕЛ studentb ПРОБЕЛ ~/studentb.pub ПРОБЕЛ --sudo
```

- **Что делает:** Создаёт пользователя `studentb`, `.ssh` (700), `authorized_keys` (600) с ключом, sudo через `/etc/sudoers.d/` (проверка `visudo -c`).
- **Ожидаемый результат:** `[OK] Användaren studentb skapad`, `[OK] Nyckeln tillagd`, `[OK] studentb har sudo`.


**Student B подключается:**

**Команда 21.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
ssh -i $HOME\.ssh\devops_studentb studentb@<ELASTIC-IP>
```

По пробелам:

```text
ssh ПРОБЕЛ -i ПРОБЕЛ $HOME\.ssh\devops_studentb ПРОБЕЛ studentb@<ELASTIC-IP>
```

- **Что делает:** Вход со своего компьютера своим ключом.
- **Ожидаемый результат:** `studentb@ip-…:~$`.


**Команда 22.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
who
```

По пробелам:

```text
who
```

- **Что делает:** Кто сейчас подключён.
- **Ожидаемый результат:** Две строки: `ubuntu` и `studentb` с разных IP — доступ двух студентов доказан.


---

## Шаг 5. setup.sh (Student A)

Что делает: обновляет систему; ставит Python, venv, pip, PostgreSQL, Supervisor, Nginx, Git, fail2ban,
logrotate, curl, jq, ufw; создаёт `fastapi_service` (API не работает от root); создаёт папки логов,
backup и секретов; aliases; SSH только по ключам; fail2ban; UFW (22 и 80); swap 1 GB; в конце проверка.
`set -Eeuo pipefail` — остановка при ошибке. Повторный запуск безопасен.

**Команда 23.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo bash ~/setup.sh
```

По пробелам:

```text
sudo ПРОБЕЛ bash ПРОБЕЛ ~/setup.sh
```

- **Что делает:** Запуск с правами root. 3–7 минут — в это время объясняйте скрипт.
- **Ожидаемый результат:** Зелёные `[OK]`, в конце `SETUP KLAR!`.


**Команда 24.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
cat /etc/ssh/sshd_config.d/10-devops-hardening.conf
```

По пробелам:

```text
cat ПРОБЕЛ /etc/ssh/sshd_config.d/10-devops-hardening.conf
```

- **Что делает:** Показывает SSH-настройки из скрипта (то, что у преподавателя делается вручную в `sshd_config`).
- **Ожидаемый результат:** `PasswordAuthentication no`, `PubkeyAuthentication yes`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`.


**Команда 25.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo fail2ban-client status sshd
```

По пробелам:

```text
sudo ПРОБЕЛ fail2ban-client ПРОБЕЛ status ПРОБЕЛ sshd
```

- **Что делает:** fail2ban следит за логом SSH и блокирует IP после многих неудачных попыток.
- **Ожидаемый результат:** `Status for the jail: sshd`, `Currently banned: 0`.


**Команда 26.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo ufw status
```

По пробелам:

```text
sudo ПРОБЕЛ ufw ПРОБЕЛ status
```

- **Что делает:** Firewall внутри Ubuntu.
- **Ожидаемый результат:** `Status: active`, `OpenSSH ALLOW`, `80/tcp ALLOW`.


**Команда 27.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
source /etc/profile.d/devops-aliases.sh
```

По пробелам:

```text
source ПРОБЕЛ /etc/profile.d/devops-aliases.sh
```

- **Что делает:** Загружает aliases в текущую сессию.
- **Ожидаемый результат:** Команда `alias` показывает список, например `alias apistatus=...`.


---

## Шаг 6. PostgreSQL (Student B)

**Команда 28.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
openssl rand -hex 16
```

По пробелам:

```text
openssl ПРОБЕЛ rand ПРОБЕЛ -hex ПРОБЕЛ 16
```

- **Что делает:** Генерирует случайный пароль (32 символа). Скопируйте его — нужен в SQL и в `.env`. Инстанс удаляется после экзамена, в GitHub пароль не попадает.
- **Ожидаемый результат:** Строка вида `3f9c...` (32 символа 0-9a-f).


**Команда 29.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo -u postgres psql
```

По пробелам:

```text
sudo ПРОБЕЛ -u ПРОБЕЛ postgres ПРОБЕЛ psql
```

- **Что делает:** Открывает консоль PostgreSQL как администратор `postgres` (вход без пароля через Linux-пользователя — peer authentication).
- **Ожидаемый результат:** Приглашение `postgres=#`.


В консоли `postgres=#` введите (вставьте свой пароль вместо `<пароль>`):

```sql
CREATE USER fastapi_user WITH PASSWORD '<пароль>';
CREATE DATABASE fastapi_movies_db OWNER fastapi_user;
\l
\q
```

- `CREATE USER` — отдельный пользователь БД для API.
- `CREATE DATABASE ... OWNER` — база, владелец которой `fastapi_user` (может создавать в ней таблицы).
- `\l` — список баз (видна `fastapi_movies_db | fastapi_user`). `\q` — выход.

**Команда 30.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo ss -tlnp | grep 5432
```

По пробелам:

```text
sudo ПРОБЕЛ ss ПРОБЕЛ -tlnp ПРОБЕЛ | ПРОБЕЛ grep ПРОБЕЛ 5432
```

- **Что делает:** На каком адресе слушает PostgreSQL.
- **Ожидаемый результат:** `127.0.0.1:5432` — только локально, не из интернета.


---

## Шаг 7. Клонировать API (Student B)

**Команда 31.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo -u fastapi_service git clone https://github.com/<ditt-github-namn>/docker-api-example.git /home/fastapi_service/fastapi_app
```

По пробелам:

```text
sudo ПРОБЕЛ -u ПРОБЕЛ fastapi_service ПРОБЕЛ git ПРОБЕЛ clone ПРОБЕЛ https://github.com/<ditt-github-namn>/docker-api-example.git ПРОБЕЛ /home/fastapi_service/fastapi_app
```

- **Что делает:** Клонирует ваш fork в домашнюю папку `fastapi_service`, от его имени (файлы принадлежат ему, а не root). Репозиторий публичный — пароль не нужен.
- **Ожидаемый результат:** `Cloning into '/home/fastapi_service/fastapi_app'...`.


## Шаг 8. .env, venv, таблицы (Student B)

**Команда 32.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo -iu fastapi_service
```

По пробелам:

```text
sudo ПРОБЕЛ -iu ПРОБЕЛ fastapi_service
```

- **Что делает:** Открывает терминал от имени `fastapi_service` (`-i` = как при входе, в его домашней папке). Так мы работаем с файлами API без root.
- **Ожидаемый результат:** Приглашение `fastapi_service@ip-…:~$`.


**Команда 33.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
cd fastapi_app/api
```

По пробелам:

```text
cd ПРОБЕЛ fastapi_app/api
```

- **Что делает:** Переходим в папку API.
- **Ожидаемый результат:** `fastapi_service@ip-…:~/fastapi_app/api$`. `ls` показывает `main.py setup.py db.py ...`.


**Команда 34.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
cp ../.env.example .env
```

По пробелам:

```text
cp ПРОБЕЛ ../.env.example ПРОБЕЛ .env
```

- **Что делает:** Копируем пример настроек в настоящий файл `.env` (он в `.gitignore`).
- **Ожидаемый результат:** Ничего не выводит.


**Команда 35.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
nano .env
```

По пробелам:

```text
nano ПРОБЕЛ .env
```

- **Что делает:** Открываем `.env` и меняем `PASSWORD=` на пароль из шага 6. Ctrl+O, Enter, Ctrl+X.
- **Ожидаемый результат:** Файл сохранён. На видео не задерживайтесь на строке с паролем.


**Команда 36.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
chmod 600 .env
```

По пробелам:

```text
chmod ПРОБЕЛ 600 ПРОБЕЛ .env
```

- **Что делает:** Права: читать и писать может только владелец (`fastapi_service`).
- **Ожидаемый результат:** `ls -l .env` → `-rw-------`.


**Команда 37.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
python3 -m venv venv
```

По пробелам:

```text
python3 ПРОБЕЛ -m ПРОБЕЛ venv ПРОБЕЛ venv
```

- **Что делает:** Создаёт виртуальное окружение — отдельные библиотеки только для этого проекта.
- **Ожидаемый результат:** Появилась папка `venv`.


**Команда 38.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
source venv/bin/activate
```

По пробелам:

```text
source ПРОБЕЛ venv/bin/activate
```

- **Что делает:** Включает venv.
- **Ожидаемый результат:** В начале строки `(venv)`.


**Команда 39.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
pip install -r requirements.txt
```

По пробелам:

```text
pip ПРОБЕЛ install ПРОБЕЛ -r ПРОБЕЛ requirements.txt
```

- **Что делает:** Устанавливает FastAPI, Uvicorn, psycopg2, python-dotenv.
- **Ожидаемый результат:** `Successfully installed fastapi-... psycopg2-binary-... uvicorn-...`. 1–2 минуты.


**Команда 40.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
python3 setup.py
```

По пробелам:

```text
python3 ПРОБЕЛ setup.py
```

- **Что делает:** Создаёт 5 таблиц (users, genres, movies, reviews, watchlist) и тестовые данные. Запускаем ОДИН раз.
- **Ожидаемый результат:** `Tables created successfully.` и `Sample data seeded successfully.`


**Команда 41.** **Linux Ubuntu на EC2 как fastapi_service** — приглашение: `fastapi_service@ip-…:~$`

```bash
exit
```

По пробелам:

```text
exit
```

- **Что делает:** Выходим из сессии `fastapi_service`, возвращаемся к своему пользователю.
- **Ожидаемый результат:** Приглашение снова `studentb@ip-…:~$`.


---

## Шаг 9. Supervisor — process manager (Student A)

**Зачем process manager:** если просто запустить `uvicorn` в терминале, API остановится при закрытии
SSH. Supervisor запускает API в фоне, перезапускает при падении (`autorestart`) и после перезагрузки
сервера (`autostart`). Аналог — systemd.

**Команда 42.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo cat /home/fastapi_service/fastapi_app/deploy/start.sh
```

По пробелам:

```text
sudo ПРОБЕЛ cat ПРОБЕЛ /home/fastapi_service/fastapi_app/deploy/start.sh
```

- **Что делает:** Показывает скрипт запуска из репозитория: активирует venv и запускает Uvicorn на `127.0.0.1:8000`.
- **Ожидаемый результат:** Строка `exec uvicorn main:app --host 127.0.0.1 --port 8000 --workers 1 --proxy-headers`.


**Команда 43.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
cd /etc/supervisor/conf.d
```

По пробелам:

```text
cd ПРОБЕЛ /etc/supervisor/conf.d
```

- **Что делает:** Папка, где Supervisor ищет конфигурации программ.
- **Ожидаемый результат:** `ubuntu@ip-…:/etc/supervisor/conf.d$`.


**Команда 44.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo nano fastapi_app.conf
```

По пробелам:

```text
sudo ПРОБЕЛ nano ПРОБЕЛ fastapi_app.conf
```

- **Что делает:** Создаём конфиг. Вставьте содержимое файла `deploy/config/fastapi_app.conf` (откройте его в VS Code на Windows и скопируйте). Ctrl+O, Enter, Ctrl+X.
- **Ожидаемый результат:** `cat fastapi_app.conf` показывает `[program:fastapi_app]`.


**Команда 45.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo supervisorctl reread
```

По пробелам:

```text
sudo ПРОБЕЛ supervisorctl ПРОБЕЛ reread
```

- **Что делает:** Supervisor перечитывает конфиги.
- **Ожидаемый результат:** `fastapi_app: available`.


**Команда 46.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo supervisorctl update
```

По пробелам:

```text
sudo ПРОБЕЛ supervisorctl ПРОБЕЛ update
```

- **Что делает:** Применяет изменения и запускает новую программу.
- **Ожидаемый результат:** `fastapi_app: added process group`.


**Команда 47.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo supervisorctl status fastapi_app
```

По пробелам:

```text
sudo ПРОБЕЛ supervisorctl ПРОБЕЛ status ПРОБЕЛ fastapi_app
```

- **Что делает:** Состояние API.
- **Ожидаемый результат:** `fastapi_app  RUNNING  pid 1234, uptime 0:00:05`.


**Команда 48.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
curl http://127.0.0.1:8000/status
```

По пробелам:

```text
curl ПРОБЕЛ http://127.0.0.1:8000/status
```

- **Что делает:** Проверка API на самом сервере (порт 8000 снаружи закрыт).
- **Ожидаемый результат:** `{"message":"OK"}`.


---

## Шаг 10. Nginx reverse proxy (Student B)

**Nginx vs Uvicorn:** Uvicorn запускает Python-код. Nginx принимает трафик из интернета на 80
(позже 443) и передаёт в Uvicorn. Один порт — одна программа, поэтому Nginx нужен, чтобы
распределять трафик между приложениями. Плюсы: быстрый (написан на C), логи, rate limiting, кэш, HTTPS.

**Команда 49.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo rm /etc/nginx/sites-enabled/default
```

По пробелам:

```text
sudo ПРОБЕЛ rm ПРОБЕЛ /etc/nginx/sites-enabled/default
```

- **Что делает:** Отключаем стандартную страницу «Welcome to nginx».
- **Ожидаемый результат:** Ничего не выводит.


**Команда 50.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
cd /etc/nginx/sites-available
```

По пробелам:

```text
cd ПРОБЕЛ /etc/nginx/sites-available
```

- **Что делает:** Папка, где хранятся конфиги сайтов.
- **Ожидаемый результат:** `studentb@ip-…:/etc/nginx/sites-available$`.


**Команда 51.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo nano fastapi_app
```

По пробелам:

```text
sudo ПРОБЕЛ nano ПРОБЕЛ fastapi_app
```

- **Что делает:** Создаём конфиг: вставить содержимое `deploy/config/nginx_fastapi_app`. Ctrl+O, Enter, Ctrl+X.
- **Ожидаемый результат:** Файл `fastapi_app` в папке.


**Команда 52.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo ln -s /etc/nginx/sites-available/fastapi_app /etc/nginx/sites-enabled/
```

По пробелам:

```text
sudo ПРОБЕЛ ln ПРОБЕЛ -s ПРОБЕЛ /etc/nginx/sites-available/fastapi_app ПРОБЕЛ /etc/nginx/sites-enabled/
```

- **Что делает:** Включаем сайт: символическая ссылка из `sites-enabled` на файл в `sites-available`.
- **Ожидаемый результат:** `ls -l /etc/nginx/sites-enabled/` показывает `fastapi_app -> /etc/nginx/sites-available/fastapi_app`.


**Команда 53.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo nginx -t
```

По пробелам:

```text
sudo ПРОБЕЛ nginx ПРОБЕЛ -t
```

- **Что делает:** Проверка синтаксиса. Всегда перед перезапуском.
- **Ожидаемый результат:** `syntax is ok` и `test is successful`.


**Команда 54.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo systemctl reload nginx
```

По пробелам:

```text
sudo ПРОБЕЛ systemctl ПРОБЕЛ reload ПРОБЕЛ nginx
```

- **Что делает:** Применяет новую конфигурацию без остановки Nginx.
- **Ожидаемый результат:** Ничего не выводит.


**Команда 55.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
curl.exe http://<ELASTIC-IP>/status
```

По пробелам:

```text
curl.exe ПРОБЕЛ http://<ELASTIC-IP>/status
```

- **Что делает:** Из Windows через интернет: порт 80 → Nginx → Uvicorn.
- **Ожидаемый результат:** `{"message":"OK"}`.


**Команда 56.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
curl.exe -m 5 http://<ELASTIC-IP>:8000/status
```

По пробелам:

```text
curl.exe ПРОБЕЛ -m ПРОБЕЛ 5 ПРОБЕЛ http://<ELASTIC-IP>:8000/status
```

- **Что делает:** Пытаемся обойти Nginx. Так быть НЕ должно.
- **Ожидаемый результат:** Timeout / `Failed to connect` — хорошо, порт 8000 закрыт.


Браузер: `http://<ELASTIC-IP>/docs` → Swagger UI.

---

## Шаг 11. Backup + CRON (Student A)

**Команда 57.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo cp /home/fastapi_service/fastapi_app/deploy/scripts/backup.sh /usr/local/bin/backup.sh
```

По пробелам:

```text
sudo ПРОБЕЛ cp ПРОБЕЛ /home/fastapi_service/fastapi_app/deploy/scripts/backup.sh ПРОБЕЛ /usr/local/bin/backup.sh
```

- **Что делает:** Копируем скрипт из репозитория в `/usr/local/bin` — место для своих программ. Владелец станет root: `fastapi_service` не сможет изменить скрипт, который выполняет root.
- **Ожидаемый результат:** Ничего не выводит.


**Команда 58.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo chmod 750 /usr/local/bin/backup.sh
```

По пробелам:

```text
sudo ПРОБЕЛ chmod ПРОБЕЛ 750 ПРОБЕЛ /usr/local/bin/backup.sh
```

- **Что делает:** 750 = root: читать/писать/выполнять, группа: читать/выполнять, остальные: ничего.
- **Ожидаемый результат:** `ls -l /usr/local/bin/backup.sh` → `-rwxr-x---`.


**Команда 59.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo /usr/local/bin/backup.sh
```

По пробелам:

```text
sudo ПРОБЕЛ /usr/local/bin/backup.sh
```

- **Что делает:** Ручной запуск: `pg_dump` базы + архив логов, проверка дампа, удаление копий старше 7 дней.
- **Ожидаемый результат:** `Databas OK: /var/backups/fastapi_app/db/fastapi_movies_db_ДАТА.dump`, `Loggar OK`, `Backup klar`.


**Команда 60.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo crontab -e
```

По пробелам:

```text
sudo ПРОБЕЛ crontab ПРОБЕЛ -e
```

- **Что делает:** Открывает расписание CRON пользователя root (первый раз — выбрать редактор `1` = nano). В конец добавить строку из `deploy/config/crontab.txt`: `0 2 * * * /usr/local/bin/backup.sh >> /var/log/fastapi_backup.log 2>&1`
- **Ожидаемый результат:** После сохранения: `crontab: installing new crontab`.


**Команда 61.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo crontab -l
```

По пробелам:

```text
sudo ПРОБЕЛ crontab ПРОБЕЛ -l
```

- **Что делает:** Показывает текущее расписание root.
- **Ожидаемый результат:** Строка с `backup.sh`. Формат: минута час день месяц день_недели команда → «каждый день в 02:00».


**Копия backup на свой компьютер** (backup на том же сервере — не оптимально):

**Команда 62.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo ls /var/backups/fastapi_app/db
```

По пробелам:

```text
sudo ПРОБЕЛ ls ПРОБЕЛ /var/backups/fastapi_app/db
```

- **Что делает:** Список дампов. Запомните имя файла.
- **Ожидаемый результат:** `fastapi_movies_db_2026-11-...dump`.


**Команда 63.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo install -m 600 -o ubuntu /var/backups/fastapi_app/db/<имя-файла>.dump ~/latest.dump
```

По пробелам:

```text
sudo ПРОБЕЛ install ПРОБЕЛ -m ПРОБЕЛ 600 ПРОБЕЛ -o ПРОБЕЛ ubuntu ПРОБЕЛ /var/backups/fastapi_app/db/<имя-файла>.dump ПРОБЕЛ ~/latest.dump
```

- **Что делает:** Копирует дамп в домашнюю папку `ubuntu` с владельцем `ubuntu` (иначе `scp` не сможет прочитать: файлы backup доступны только root).
- **Ожидаемый результат:** Ничего не выводит.


**Команда 64.** **Windows PowerShell** — приглашение выглядит так: `PS C:\Users\<ваше-имя>>`

```powershell
scp -i $HOME\.ssh\devops-key.pem ubuntu@<ELASTIC-IP>:~/latest.dump $HOME\Downloads\
```

По пробелам:

```text
scp ПРОБЕЛ -i ПРОБЕЛ $HOME\.ssh\devops-key.pem ПРОБЕЛ ubuntu@<ELASTIC-IP>:~/latest.dump ПРОБЕЛ $HOME\Downloads\
```

- **Что делает:** Скачивает файл с сервера на Windows.
- **Ожидаемый результат:** Строка `latest.dump 100%`.


**Команда 65.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
rm ~/latest.dump
```

По пробелам:

```text
rm ПРОБЕЛ ~/latest.dump
```

- **Что делает:** Удаляем временную копию на сервере.
- **Ожидаемый результат:** Ничего не выводит.


**Восстановление (объяснить):**
`sudo supervisorctl stop fastapi_app` →
`sudo cat <файл>.dump | sudo -u postgres pg_restore --clean --if-exists -d fastapi_movies_db` →
`sudo supervisorctl start fastapi_app`. (Проверено локально: данные и владелец таблиц восстанавливаются.)

---

## Шаг 12. Мониторинг + Discord (Student B)

`monitor_system.sh` проверяет: диск, CPU, RAM, `/status` через Nginx, `fastapi_app` в Supervisor,
nginx и postgresql, **неудачные SSH-входы за 5 минут** (≥5 → тревога). Пишет в
`/var/log/system_monitor.log` и шлёт в Discord. Одинаковая тревога — не чаще раза в час; когда
всё снова в порядке — сообщение «Återställt».

**Команда 66.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo cp /home/fastapi_service/fastapi_app/deploy/scripts/monitor_system.sh /usr/local/bin/monitor_system.sh
```

По пробелам:

```text
sudo ПРОБЕЛ cp ПРОБЕЛ /home/fastapi_service/fastapi_app/deploy/scripts/monitor_system.sh ПРОБЕЛ /usr/local/bin/monitor_system.sh
```

- **Что делает:** Копируем скрипт мониторинга в `/usr/local/bin` (владелец root).
- **Ожидаемый результат:** Ничего не выводит.


**Команда 67.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo chmod 750 /usr/local/bin/monitor_system.sh
```

По пробелам:

```text
sudo ПРОБЕЛ chmod ПРОБЕЛ 750 ПРОБЕЛ /usr/local/bin/monitor_system.sh
```

- **Что делает:** Делаем исполняемым только для root.
- **Ожидаемый результат:** `-rwxr-x---`.


**Команда 68.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo nano /etc/fastapi_app/monitor.env
```

По пробелам:

```text
sudo ПРОБЕЛ nano ПРОБЕЛ /etc/fastapi_app/monitor.env
```

- **Что делает:** Файл с секретом. Впишите строку `DISCORD_WEBHOOK_URL=<ваш-webhook>` (образец: `deploy/config/monitor.env.example`). URL — секрет: старайтесь не держать его на экране; после записи webhook удалить в Discord.
- **Ожидаемый результат:** Файл сохранён.


**Команда 69.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo chmod 600 /etc/fastapi_app/monitor.env
```

По пробелам:

```text
sudo ПРОБЕЛ chmod ПРОБЕЛ 600 ПРОБЕЛ /etc/fastapi_app/monitor.env
```

- **Что делает:** Только root может читать webhook.
- **Ожидаемый результат:** `sudo ls -l /etc/fastapi_app/` → `-rw------- root root monitor.env`.


**Команда 70.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo monitor_system.sh --test
```

По пробелам:

```text
sudo ПРОБЕЛ monitor_system.sh ПРОБЕЛ --test
```

- **Что делает:** Тестовое сообщение в Discord.
- **Ожидаемый результат:** `Testmeddelande skickat`. В Discord: «Testmeddelande från ip-…».


**Команда 71.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo DISK_THRESHOLD=0 monitor_system.sh --verbose
```

По пробелам:

```text
sudo ПРОБЕЛ DISK_THRESHOLD=0 ПРОБЕЛ monitor_system.sh ПРОБЕЛ --verbose
```

- **Что делает:** Временно порог диска = 0 %, чтобы вызвать тревогу без нагрузки. Файл настроек не меняется.
- **Ожидаемый результат:** `WARNING: Disk ...% >= 0%`, `Status: PROBLEM`. В Discord: «LARM på ip-…».


**Команда 72.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo monitor_system.sh --verbose
```

По пробелам:

```text
sudo ПРОБЕЛ monitor_system.sh ПРОБЕЛ --verbose
```

- **Что делает:** Обычная проверка.
- **Ожидаемый результат:** `OK: System healthy ...`, `Status: OK`. В Discord: «Återställt».


**Команда 73.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo crontab -e
```

По пробелам:

```text
sudo ПРОБЕЛ crontab ПРОБЕЛ -e
```

- **Что делает:** Добавить вторую строку из `deploy/config/crontab.txt`: `*/5 * * * * /usr/local/bin/monitor_system.sh`
- **Ожидаемый результат:** `crontab: installing new crontab`. `*/5` = каждые 5 минут.


**Команда 74.** **Linux Ubuntu на EC2, Student B** — приглашение: `studentb@ip-…:~$`

```bash
sudo tail -f /var/log/system_monitor.log
```

По пробелам:

```text
sudo ПРОБЕЛ tail ПРОБЕЛ -f ПРОБЕЛ /var/log/system_monitor.log
```

- **Что делает:** Следим за логом в реальном времени (Ctrl+C — выход). Через ≤5 минут появится запись от CRON.
- **Ожидаемый результат:** `[ДАТА] OK: System healthy (Disk ...%, CPU ...%, ...)`.


---

## Шаг 13. Демонстрация (оба)

Swagger `http://<ELASTIC-IP>/docs`:
1. **GET /movies** → 200, 8 фильмов.
2. **POST /users** → `{"username": "vitaliia"}` → 201, `User created successfully with id: 4`.
3. **POST /reviews** → `{"user_id": 4, "movie_id": 1, "rating": 5, "review_text": "Bra film!"}` → 201.
4. **GET /movie/999** → 404 `Movie not found`.

**Команда 75.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo -u postgres psql -d fastapi_movies_db -c "SELECT id, username FROM users;"
```

По пробелам:

```text
sudo ПРОБЕЛ -u ПРОБЕЛ postgres ПРОБЕЛ psql ПРОБЕЛ -d ПРОБЕЛ fastapi_movies_db ПРОБЕЛ -c ПРОБЕЛ "SELECT ПРОБЕЛ id, ПРОБЕЛ username ПРОБЕЛ FROM ПРОБЕЛ users;"
```

- **Что делает:** Данные из API действительно в PostgreSQL.
- **Ожидаемый результат:** Таблица с `alice`, `bob`, `charlie` и вашим пользователем.


**Команда 76.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo bash /home/fastapi_service/fastapi_app/deploy/scripts/smoke_test.sh
```

По пробелам:

```text
sudo ПРОБЕЛ bash ПРОБЕЛ /home/fastapi_service/fastapi_app/deploy/scripts/smoke_test.sh
```

- **Что делает:** Автопроверка всех эндпоинтов через Nginx.
- **Ожидаемый результат:** `Resultat: 10 PASS, 0 FAIL`.


**Команда 77.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo reboot
```

По пробелам:

```text
sudo ПРОБЕЛ reboot
```

- **Что делает:** Перезагрузка — проверка автозапуска. SSH отключится.
- **Ожидаемый результат:** Через ~1 минуту снова `ssh` (Elastic IP тот же).


**Команда 78.** **Linux Ubuntu на EC2 (через SSH)** — приглашение: `ubuntu@ip-…:~$`

```bash
sudo supervisorctl status fastapi_app
```

По пробелам:

```text
sudo ПРОБЕЛ supervisorctl ПРОБЕЛ status ПРОБЕЛ fastapi_app
```

- **Что делает:** После перезагрузки API должен работать сам (`autostart=true`).
- **Ожидаемый результат:** `RUNNING`. Затем `systemctl is-active nginx postgresql supervisor` → 3× `active`.


---

## HTTPS — что нужно понимать (для G объяснить, делать не обязательно)

- **HTTP** передаёт данные открытым текстом: пароль или токен может прочитать любой на пути (Wi-Fi, провайдер).
- **HTTPS** = HTTP + **TLS-шифрование**. Браузер и сервер договариваются о ключе; данные зашифрованы. Порт **443**.
- **Сертификат** доказывает, что сервер — действительно `example.se`. Выдаёт центр сертификации (например, бесплатный **Let's Encrypt**).
- Сертификат выдаётся на **домен**, поэтому для нормального HTTPS нужен свой домен (VG). На голый IP сертификат Let's Encrypt не выдаёт.
- Как делается (VG): купить домен → DNS-запись A на Elastic IP → `sudo apt install certbot python3-certbot-nginx` → `sudo certbot --nginx -d <домен>` → certbot сам меняет конфиг Nginx и открывает 443 (нужно правило 443 в Security Group).
- У нас HTTP на IP — для учебного прототипа это допустимо, но для production нужен HTTPS.

---

## Шаг 14. После записи: удалить ресурсы AWS

1. **Instances** → `fastapi-devops` → **Terminate (delete) instance**.
2. **Elastic IPs** → **Release Elastic IP addresses**.
3. **Volumes** — пусто (иначе Delete).
4. **Security Groups** → удалить `fastapi-devops-sg`.
5. **Key Pairs** → удалить `devops-key`; на Windows удалить `.pem` и `devops_studentb*`.
6. PowerShell: `ssh-keygen -R <ELASTIC-IP>`.
7. Discord → удалить webhook.
8. **Billing → Bills** через 1–2 дня: 0.
