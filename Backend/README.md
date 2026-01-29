# VoxelWorld Backend

Backend сервер для VoxelWorld, построенный на FastAPI.

## Возможности

- **Аутентификация** - Регистрация, вход, JWT токены
- **Управление пользователями** - Профили, статистика, поиск
- **Система друзей** - Добавление друзей, запросы, управление
- **Достижения** - Система достижений и прогресса
- **API для игровых серверов** - Интеграция с игровыми серверами

## Установка

### Требования

- Python 3.11+
- PostgreSQL 14+
- Redis (опционально)

### Шаги установки

1. Установите зависимости:
```bash
pip install -r requirements.txt
```

2. Создайте базу данных PostgreSQL:
```bash
createdb voxelworld
```

3. Скопируйте `.env.example` в `.env` и настройте:
```bash
cp .env.example .env
```

4. Запустите сервер:
```bash
python main.py
```

Или с помощью uvicorn:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## API Документация

После запуска сервера документация доступна по адресам:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Эндпоинты

### Аутентификация

- `POST /auth/register` - Регистрация нового пользователя
- `POST /auth/login` - Вход в систему
- `POST /auth/refresh` - Обновление токена
- `POST /auth/verify` - Проверка токена

### Пользователи

- `GET /users/me` - Получить информацию о текущем пользователе
- `GET /users/{user_id}` - Получить информацию о пользователе
- `GET /users/username/{username}` - Найти пользователя по имени
- `PUT /users/me/profile` - Обновить профиль
- `PUT /users/me/stats` - Обновить статистику
- `GET /users/search/{query}` - Поиск пользователей

### Друзья

- `GET /friends/` - Получить список друзей
- `GET /friends/requests` - Получить входящие запросы
- `POST /friends/request` - Отправить запрос в друзья
- `POST /friends/accept/{friend_id}` - Принять запрос
- `DELETE /friends/{friend_id}` - Удалить друга

## Структура проекта

```
Backend/
├── main.py              # Главный файл приложения
├── config.py            # Конфигурация
├── database.py          # Подключение к БД
├── auth.py              # Утилиты аутентификации
├── models/              # Модели базы данных
│   ├── user.py
│   ├── friend.py
│   └── achievement.py
└── routes/              # API роутеры
    ├── auth.py
    ├── users.py
    └── friends.py
```

## Разработка

### Миграции базы данных

Для создания миграций используйте Alembic:

```bash
# Инициализация
alembic init alembic

# Создание миграции
alembic revision --autogenerate -m "Description"

# Применение миграций
alembic upgrade head
```

### Тестирование

```bash
pytest
```

## Production

Для production окружения:

1. Измените `DEBUG=False` в `.env`
2. Используйте надежный `SECRET_KEY`
3. Настройте PostgreSQL с SSL
4. Используйте reverse proxy (nginx)
5. Настройте HTTPS
6. Используйте gunicorn или uvicorn workers

Пример запуска с gunicorn:
```bash
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## Лицензия

MIT License
