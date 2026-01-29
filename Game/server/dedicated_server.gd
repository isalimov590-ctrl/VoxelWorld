extends Node

## Выделенный сервер
## Запускает игровой сервер без графики

## Параметры сервера
var server_name: String = "VoxelWorld Server"
var server_port: int = 7777
var max_players: int = 10
var server_password: String = ""

## Ссылки на компоненты
var terrain_manager: TerrainManager
var network_manager

## Конфигурация
var config: Dictionary = {}


func _ready() -> void:
	# Загружаем конфигурацию
	_load_config()
	
	# Применяем параметры из конфигурации
	_apply_config()
	
	# Запускаем сервер
	_start_server()


## Загружает конфигурацию сервера
func _load_config() -> void:
	var config_path = "user://server_config.json"
	
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				config = json.get_data()
				print("Server config loaded")
			else:
				push_error("Failed to parse server config")
	else:
		# Создаем конфигурацию по умолчанию
		config = {
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
		_save_config()


## Сохраняет конфигурацию
func _save_config() -> void:
	var config_path = "user://server_config.json"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		print("Server config saved")


## Применяет конфигурацию
func _apply_config() -> void:
	server_name = config.get("server_name", "VoxelWorld Server")
	server_port = config.get("server_port", 7777)
	max_players = config.get("max_players", 10)
	server_password = config.get("password", "")
	
	# Применяем настройки мира
	if GameManager:
		GameManager.world_info["seed"] = config.get("world_seed", 12345)
		GameManager.world_info["game_mode"] = config.get("game_mode", "survival")
		GameManager.world_info["difficulty"] = config.get("difficulty", "normal")


## Запускает сервер
func _start_server() -> void:
	print("Starting dedicated server...")
	print("Server name: ", server_name)
	print("Port: ", server_port)
	print("Max players: ", max_players)
	
	# Получаем NetworkManager
	network_manager = get_node("/root/NetworkManager")
	if not network_manager:
		push_error("NetworkManager not found")
		get_tree().quit()
		return
	
	# Создаем сервер
	var success = network_manager.create_server(server_port, max_players)
	if not success:
		push_error("Failed to start server")
		get_tree().quit()
		return
	
	# Подключаем сигналы
	network_manager.player_connected.connect(_on_player_connected)
	network_manager.player_disconnected.connect(_on_player_disconnected)
	
	print("Server started successfully!")
	print("Waiting for players...")


## Обработчик подключения игрока
func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	print("Player connected: ", player_info.get("username", "Unknown"), " (ID: ", peer_id, ")")
	
	# Проверяем whitelist
	if config.get("whitelist", false):
		var whitelist = config.get("whitelist_users", [])
		if not player_info.get("username", "") in whitelist:
			print("Player not in whitelist, kicking...")
			network_manager.peer.disconnect_peer(peer_id)
			return
	
	# Проверяем ban
	var banned = config.get("banned_users", [])
	if player_info.get("username", "") in banned:
		print("Player is banned, kicking...")
		network_manager.peer.disconnect_peer(peer_id)
		return
	
	# Создаем игрока в мире
	_spawn_player(peer_id, player_info)


## Обработчик отключения игрока
func _on_player_disconnected(peer_id: int) -> void:
	print("Player disconnected: ID ", peer_id)


## Создает игрока в мире
func _spawn_player(peer_id: int, player_info: Dictionary) -> void:
	# TODO: Создать игрока в сцене
	print("Spawning player: ", player_info.get("username", "Unknown"))


## Обрабатывает команды консоли
func _process_command(command: String) -> void:
	var parts = command.split(" ", false)
	if parts.is_empty():
		return
	
	var cmd = parts[0].to_lower()
	
	match cmd:
		"stop":
			_stop_server()
		"list":
			_list_players()
		"kick":
			if parts.size() > 1:
				_kick_player(parts[1])
		"ban":
			if parts.size() > 1:
				_ban_player(parts[1])
		"unban":
			if parts.size() > 1:
				_unban_player(parts[1])
		"op":
			if parts.size() > 1:
				_add_operator(parts[1])
		"deop":
			if parts.size() > 1:
				_remove_operator(parts[1])
		"save":
			_save_world()
		"help":
			_show_help()
		_:
			print("Unknown command: ", cmd)


## Останавливает сервер
func _stop_server() -> void:
	print("Stopping server...")
	
	# Сохраняем мир
	_save_world()
	
	# Отключаем всех игроков
	if network_manager:
		network_manager.disconnect_from_network()
	
	# Выходим
	get_tree().quit()


## Показывает список игроков
func _list_players() -> void:
	print("Connected players:")
	var players = network_manager.connected_players
	for peer_id in players.keys():
		var info = players[peer_id]
		print("  - ", info.get("username", "Unknown"), " (ID: ", peer_id, ")")


## Кикает игрока
func _kick_player(username: String) -> void:
	var players = network_manager.connected_players
	for peer_id in players.keys():
		var info = players[peer_id]
		if info.get("username", "") == username:
			print("Kicking player: ", username)
			network_manager.peer.disconnect_peer(peer_id)
			return
	print("Player not found: ", username)


## Банит игрока
func _ban_player(username: String) -> void:
	var banned = config.get("banned_users", [])
	if not username in banned:
		banned.append(username)
		config["banned_users"] = banned
		_save_config()
		print("Banned player: ", username)
		
		# Кикаем если онлайн
		_kick_player(username)
	else:
		print("Player already banned: ", username)


## Разбанивает игрока
func _unban_player(username: String) -> void:
	var banned = config.get("banned_users", [])
	if username in banned:
		banned.erase(username)
		config["banned_users"] = banned
		_save_config()
		print("Unbanned player: ", username)
	else:
		print("Player not banned: ", username)


## Добавляет оператора
func _add_operator(username: String) -> void:
	var operators = config.get("operators", [])
	if not username in operators:
		operators.append(username)
		config["operators"] = operators
		_save_config()
		print("Added operator: ", username)
	else:
		print("Player already operator: ", username)


## Удаляет оператора
func _remove_operator(username: String) -> void:
	var operators = config.get("operators", [])
	if username in operators:
		operators.erase(username)
		config["operators"] = operators
		_save_config()
		print("Removed operator: ", username)
	else:
		print("Player not operator: ", username)


## Сохраняет мир
func _save_world() -> void:
	print("Saving world...")
	if GameManager:
		GameManager.save_game()
	print("World saved")


## Показывает помощь
func _show_help() -> void:
	print("Available commands:")
	print("  stop - Stop the server")
	print("  list - List connected players")
	print("  kick <username> - Kick a player")
	print("  ban <username> - Ban a player")
	print("  unban <username> - Unban a player")
	print("  op <username> - Add operator")
	print("  deop <username> - Remove operator")
	print("  save - Save the world")
	print("  help - Show this help")
