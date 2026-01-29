# VoxelWorld Dedicated Server

Выделенный сервер для VoxelWorld с поддержкой кроссплатформенного мультиплеера.

## Возможности

- **Кроссплатформенный мультиплеер** - Игроки с PC, Android и других платформ могут играть вместе
- **Управление игроками** - Kick, ban, whitelist, операторы
- **Автосохранение** - Автоматическое сохранение мира
- **Консольные команды** - Полное управление через консоль
- **Конфигурация** - Гибкая настройка через JSON файл

## Требования

- Godot Engine 4.6 (headless build для production)
- Linux/Windows/macOS
- Минимум 2GB RAM
- Открытый порт 7777 (или настроенный в конфигурации)

## Установка

### Linux

1. Установите Godot 4.6:
```bash
# Скачайте headless версию с официального сайта
wget https://downloads.tuxfamily.org/godotengine/4.6/Godot_v4.6-stable_linux.x86_64.zip
unzip Godot_v4.6-stable_linux.x86_64.zip
sudo mv Godot_v4.6-stable_linux.x86_64 /usr/local/bin/godot
```

2. Запустите сервер:
```bash
cd Game/server
./server_launcher.sh
```

### Windows

1. Установите Godot 4.6 и добавьте в PATH

2. Запустите сервер:
```cmd
cd Game\server
server_launcher.bat
```

### Docker

```bash
docker build -t voxelworld-server .
docker run -p 7777:7777 voxelworld-server
```

## Конфигурация

Конфигурация хранится в `user://server_config.json`:

```json
{
  "server_name": "VoxelWorld Server",
  "server_port": 7777,
  "max_players": 10,
  "password": "",
  "world_seed": 12345,
  "render_distance": 8,
  "game_mode": "survival",
  "difficulty": "normal",
  "pvp": true,
  "whitelist": false,
  "whitelist_users": [],
  "banned_users": [],
  "operators": []
}
```

### Параметры

- **server_name** - Название сервера
- **server_port** - Порт сервера (по умолчанию 7777)
- **max_players** - Максимальное количество игроков
- **password** - Пароль для подключения (пусто = без пароля)
- **world_seed** - Сид мира для генерации
- **render_distance** - Дистанция рендеринга в чанках
- **game_mode** - Режим игры (survival, creative, adventure)
- **difficulty** - Сложность (peaceful, easy, normal, hard)
- **pvp** - Включен ли PvP
- **whitelist** - Включен ли whitelist
- **whitelist_users** - Список пользователей в whitelist
- **banned_users** - Список забаненных пользователей
- **operators** - Список операторов

## Консольные команды

### Управление сервером

- `stop` - Остановить сервер
- `save` - Сохранить мир
- `help` - Показать справку

### Управление игроками

- `list` - Список подключенных игроков
- `kick <username>` - Кикнуть игрока
- `ban <username>` - Забанить игрока
- `unban <username>` - Разбанить игрока
- `op <username>` - Добавить оператора
- `deop <username>` - Убрать оператора

## Автозапуск

### Linux (systemd)

Создайте файл `/etc/systemd/system/voxelworld-server.service`:

```ini
[Unit]
Description=VoxelWorld Dedicated Server
After=network.target

[Service]
Type=simple
User=voxelworld
WorkingDirectory=/opt/voxelworld/Game/server
ExecStart=/opt/voxelworld/Game/server/server_launcher.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Затем:
```bash
sudo systemctl daemon-reload
sudo systemctl enable voxelworld-server
sudo systemctl start voxelworld-server
```

### Windows (Task Scheduler)

Создайте задачу в Task Scheduler для автозапуска при старте системы.

## Порты

По умолчанию сервер использует:
- **7777** - Игровой порт (TCP/UDP)

Убедитесь что порты открыты в файрволе:

```bash
# Linux (ufw)
sudo ufw allow 7777

# Linux (iptables)
sudo iptables -A INPUT -p tcp --dport 7777 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 7777 -j ACCEPT
```

## Производительность

### Рекомендуемые характеристики

- **CPU**: 2+ ядра
- **RAM**: 4GB+ (зависит от количества игроков)
- **Диск**: 10GB+ (для мира)
- **Сеть**: 10+ Mbps

### Оптимизация

1. Уменьшите `render_distance` в конфигурации
2. Ограничьте `max_players`
3. Используйте SSD для хранения мира
4. Используйте headless build Godot

## Бэкапы

Рекомендуется регулярно создавать бэкапы мира:

```bash
# Создать бэкап
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz ~/.local/share/godot/app_userdata/VoxelWorld/

# Восстановить бэкап
tar -xzf backup_20260130_120000.tar.gz -C ~/.local/share/godot/app_userdata/VoxelWorld/
```

## Мониторинг

Логи сервера выводятся в консоль. Для сохранения логов:

```bash
./server_launcher.sh 2>&1 | tee server.log
```

## Поддержка

Если у вас возникли проблемы:

1. Проверьте логи сервера
2. Убедитесь что порты открыты
3. Проверьте конфигурацию
4. Создайте issue на GitHub

## Лицензия

MIT License
