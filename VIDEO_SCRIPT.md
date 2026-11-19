# VIDEO_SCRIPT – план видео (максимум 60 минут, уровень G)

Команды — в [docs/GUIDE_RU.md](docs/GUIDE_RU.md) (номер шага указан). Здесь: кто, когда, что сказать.

**Требования преподавателя к видео:**
- **Оба видны на камере**, экран хорошо читается (крупный шрифт терминала).
- Оба говорят и показывают понимание. Оценка индивидуальная.
- Каждый работает **на своём компьютере**.
- **Не читать готовый текст.** Можно держать перед глазами только чек-лист ([CHECKLIST.md](CHECKLIST.md)). Фразы ниже — для тренировки, на видео говорите своими словами.
- Многое делать руками: `cd`, `ls`, `nano`. Копировать можно только готовое содержимое конфигов и скриптов.
- Не показывать: `.pem`, пароль в `.env`, webhook-URL, пароль AWS.

## Тайминг (51 минута по плану + 9 минут запас)

| Время | Мин | Кто | Этап | Шаг GUIDE |
|-------|-----|-----|------|-----------|
| 00:00–01:30 | 1,5 | A + B | Приветствие, архитектура | — |
| 01:30–08:00 | 6,5 | **A** | EC2, AMI, t3.micro, key pair, Security Group | 1 |
| 08:00–10:00 | 2 | **B** | Elastic IP, расходы | 2 |
| 10:00–16:00 | 6 | **A → B** | SSH A, ключ B, `scp` скриптов, `add_user.sh`, вход B, `who` | 3–4 |
| 16:00–22:00 | 6 | **A** | `setup.sh` (объяснять во время работы), SSH-защита, fail2ban, UFW | 5 |
| 22:00–25:00 | 3 | **B** | PostgreSQL вручную в `psql` | 6 |
| 25:00–30:00 | 5 | **B** | `git clone`, `.env`, venv, `pip install`, `setup.py` | 7–8 |
| 30:00–34:00 | 4 | **A** | Supervisor: `start.sh`, `nano` конфиг, `reread/update/status` | 9 |
| 34:00–38:00 | 4 | **B** | Nginx: `nano`, `ln -s`, `nginx -t`, `/docs`, 8000 закрыт | 10 |
| 38:00–42:00 | 4 | **A** | Backup: скрипт, `crontab -e`, `scp` копии на Windows, восстановление | 11 |
| 42:00–46:00 | 4 | **B** | Мониторинг: скрипт, webhook, Discord-тест, тревога, `crontab -e` | 12 |
| 46:00–49:30 | 3,5 | **A + B** | Демо Swagger, `psql`, smoke test, reboot | 13 |
| 49:30–51:00 | 1,5 | **A + B** | Итог: безопасность, HTTPS, удаление ресурсов | HTTPS, 14 |
| 51:00–60:00 | 9 | — | **Запас** | TROUBLESHOOTING |

Если опаздываете > 5 мин: восстановление из backup только объяснить, reboot — в конце.

---

## Фразы для тренировки (svenska → русский)

### Приветствие (A + B)
| Svenska | Русский |
|---------|---------|
| Hej! Vi heter `<namn>` och `<namn>`. | Привет! Нас зовут … и … |
| Vi ska bygga en enkel produktionsmiljö för en API på AWS. | Мы построим простую production-среду для API в AWS. |
| API:t är skrivet med FastAPI och använder PostgreSQL. | API написан на FastAPI и использует PostgreSQL. |
| Supervisor håller API:t igång, och Nginx tar emot trafiken. | Supervisor держит API запущенным, а Nginx принимает трафик. |

### Шаг 1 — EC2 (A)
| Svenska | Русский |
|---------|---------|
| Nu skapar jag en ny EC2-instans från början. | Сейчас я создаю новый EC2-инстанс с нуля. |
| AMI är en mall för operativsystemet. Jag väljer Ubuntu 24.04 LTS. | AMI — шаблон ОС. Я выбираю Ubuntu 24.04 LTS. |
| t3.micro ingår i free tier. t2.micro finns inte i Stockholm. | t3.micro входит во free tier. t2.micro в Стокгольме нет. |
| Security Group är en brandvägg i AWS. Port 22 bara från våra IP, port 80 för alla. | Security Group — firewall AWS. Порт 22 только с наших IP, порт 80 для всех. |
| Vi öppnar inte port 8000. API:t ska bara nås via Nginx. | Порт 8000 не открываем. API доступен только через Nginx. |

### Шаг 2 — Elastic IP (B)
| Svenska | Русский |
|---------|---------|
| En Elastic IP är en fast adress. Den ändras inte när servern startas om. | Elastic IP — постоянный адрес. Он не меняется при перезагрузке. |
| Här kontrollerar jag kostnaderna i Billing. | Здесь я проверяю расходы в Billing. |

### Шаги 3–4 — SSH (A, B)
| Svenska | Русский |
|---------|---------|
| **A:** Jag sätter rättigheter så att bara jag kan läsa nyckeln. | Ставлю права, чтобы только я мог(ла) читать ключ. |
| **B:** Jag skapar en egen nyckel på min dator och skickar bara den publika nyckeln. | Я создаю свой ключ и отправляю только публичный. |
| **A:** Med scp kopierar jag skripten till servern. | Через scp я копирую скрипты на сервер. |
| **B:** Nu är jag inloggad från min egen dator. who visar oss båda. | Я вошёл(ла) со своего компьютера. who показывает нас обоих. |

### Шаг 5 — setup.sh (A)
| Svenska | Русский |
|---------|---------|
| Skriptet installerar paketen och skapar användaren fastapi_service. | Скрипт ставит пакеты и создаёт пользователя fastapi_service. |
| API:t körs inte som root. Om någon hackar API:t får den bara rättigheterna för fastapi_service. | API работает не от root. При взломе — только права fastapi_service. |
| Inloggning med lösenord är avstängd. Bara SSH-nycklar fungerar. | Вход по паролю отключён. Работают только SSH-ключи. |
| fail2ban blockerar IP-adresser som försöker gissa sig in. | fail2ban блокирует IP, которые пытаются подобрать вход. |
| Skriptet kan köras flera gånger med samma resultat. | Скрипт можно запускать много раз с тем же результатом. |

### Шаги 6–8 — PostgreSQL, git, .env (B)
| Svenska | Русский |
|---------|---------|
| Jag skapar en egen databasanvändare, inte postgres, för att API:t inte ska vara admin. | Создаю отдельного пользователя БД, не postgres, чтобы API не был админом. |
| PostgreSQL lyssnar bara på localhost. | PostgreSQL слушает только localhost. |
| Jag klonar repot till hemkatalogen för fastapi_service. | Клонирую репозиторий в домашний каталог fastapi_service. |
| Lösenordet ligger i .env med rättigheter 600. .env finns i .gitignore. | Пароль в .env с правами 600. .env в .gitignore. |
| En virtuell miljö håller projektets paket separat. | Виртуальное окружение изолирует пакеты проекта. |
| setup.py skapar tabellerna och testdata. Vi kör den bara en gång. | setup.py создаёт таблицы и тестовые данные. Запускаем один раз. |

### Шаг 9 — Supervisor (A)
| Svenska | Русский |
|---------|---------|
| Supervisor är en process manager. Den startar API:t i bakgrunden och startar om det om det kraschar. | Supervisor — менеджер процессов. Запускает API в фоне и перезапускает при падении. |
| Uvicorn lyssnar bara på 127.0.0.1, så den går inte att nå från internet. | Uvicorn слушает только 127.0.0.1, из интернета недоступен. |
| Status är RUNNING. | Статус RUNNING. |

### Шаг 10 — Nginx (B)
| Svenska | Русский |
|---------|---------|
| Nginx är en reverse proxy. Den tar emot trafik på port 80 och skickar den till Uvicorn. | Nginx — обратный прокси: принимает трафик на 80 и передаёт в Uvicorn. |
| Bara ett program kan använda en port. Nginx kan skicka trafik till flera appar. | Порт может занять только одна программа. Nginx распределяет трафик между приложениями. |
| nginx -t testar konfigurationen innan vi laddar om. | nginx -t проверяет конфигурацию перед перезагрузкой. |

### Шаг 11 — Backup (A)
| Svenska | Русский |
|---------|---------|
| backup.sh gör en pg_dump av databasen och packar loggarna. | backup.sh делает pg_dump базы и архивирует логи. |
| CRON kör den varje natt klockan två. | CRON запускает его каждую ночь в два часа. |
| Backup på samma server är inte optimalt, därför kopierar jag den till min dator med scp. | Копия на том же сервере — не оптимально, поэтому копирую её к себе через scp. |

### Шаг 12 — Мониторинг (B)
| Svenska | Русский |
|---------|---------|
| Skriptet kontrollerar disk, CPU, minne, API:t och misslyckade SSH-inloggningar. | Скрипт проверяет диск, CPU, память, API и неудачные SSH-входы. |
| Vid problem skickas ett meddelande till Discord via en webhook. | При проблеме — сообщение в Discord через webhook. |
| Webhooken är hemlig och ligger i en fil som bara root kan läsa. | Webhook секретный, в файле, который читает только root. |

### Итог
| Svenska | Русский |
|---------|---------|
| Vi har bara port 22 och 80 öppna. | Открыты только порты 22 и 80. |
| HTTPS krypterar trafiken. För det behövs en domän och ett certifikat, till exempel från Let's Encrypt. | HTTPS шифрует трафик. Нужны домен и сертификат, например Let's Encrypt. |
| Efter inspelningen terminerar vi instansen och släpper Elastic IP. | После записи удаляем инстанс и освобождаем Elastic IP. |

---

## Вопросы преподавателя (короткие ответы)

| Fråga | Svar (svenska) | Перевод |
|-------|----------------|---------|
| Varför behöver man en process manager? | Den håller API:t igång i bakgrunden, startar om vid krasch och efter omstart. | Держит API в фоне, перезапускает при падении и после перезагрузки. |
| Vad är skillnaden mellan Nginx och Uvicorn? | Uvicorn kör Python-koden. Nginx tar emot trafiken och skickar den vidare. | Uvicorn выполняет код. Nginx принимает трафик и передаёт дальше. |
| Vad är HTTPS? | HTTP med TLS-kryptering. Ett certifikat visar att servern är äkta. | HTTP с шифрованием TLS. Сертификат подтверждает подлинность сервера. |
| Varför inte port 8000 öppen? | Då kan man gå förbi Nginx. Färre öppna portar är säkrare. | Можно обойти Nginx. Меньше открытых портов — безопаснее. |
| Varför egen databasanvändare? | API:t ska inte ha admin-rättigheter i databasen. | У API не должно быть прав администратора БД. |
| Vad gör chmod 600? | Bara ägaren kan läsa och skriva filen. | Только владелец читает и пишет файл. |
| Vad betyder `*/5 * * * *`? | Var femte minut. | Каждые пять минут. |
| Hur återställer man databasen? | Med pg_restore från dump-filen. | Через pg_restore из dump-файла. |
| Vad gör fail2ban? | Blockerar IP-adresser efter för många misslyckade inloggningar. | Блокирует IP после многих неудачных входов. |
| Vad är en Elastic IP? | En fast publik IP-adress. | Постоянный публичный IP. |
| Varför sudo -iu fastapi_service? | Så att filerna skapas av rätt användare och inte av root. | Чтобы файлы создавал нужный пользователь, а не root. |
| Vad är skillnaden mellan sites-available och sites-enabled? | I available finns alla konfigurationer. Länken i enabled gör att Nginx använder den. | В available все конфиги; ссылка в enabled включает конфиг. |
| Varför workers 1? | Servern har 1 GB RAM, och med flera workers kunde Supervisor inte starta om API:t efter en krasch. | 1 GB RAM; с несколькими workers Supervisor не мог перезапустить API после падения. |

Не знаете ответа: *"Det vet jag inte säkert, men jag tror att …"*.
Ошибка на видео: *"Här fick vi ett fel. Jag läser felmeddelandet och felsöker."*
