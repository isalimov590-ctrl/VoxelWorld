extends Node

## Менеджер сети
## Управляет подключением к серверу и синхронизацией

## Сигналы
signal connected_to_server
signal connection_failed
signal disconnected_from_server
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_started
signal server_stopped

## Режим работы
enum NetworkMode {
	OFFLINE,
	CLIENT,
	SERVER
}

var current_mode: NetworkMode = NetworkMode.OFFLINE

## Параметры подключения
var server_address: String = "127.0.0.1"
var server_port: int = 7777
var max_players: int = 10

## Информация о игроке
var local_player_info: Dictionary = {
	"username": "Player",
	"skin": "",
	"peer_id": 0
}

## Словарь подключенных игроков {peer_id: player_info}
var connected_players: Dictionary = {}

## Peer для сетевого подключения
var peer: ENetMultiplayerPeer = null


func _ready() -> void:
	# Подключаем сигналы мультиплеера
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Создает сервер
func create_server(port: int = 7777, max_clients: int = 10) -> bool:
	if current_mode != NetworkMode.OFFLINE:
		push_error("Already connected")
		return false
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_clients)
	
	if error != OK:
		push_error("Failed to create server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = peer
	current_mode = NetworkMode.SERVER
	server_port = port
	max_players = max_clients
	
	# Добавляем себя в список игроков
	local_player_info["peer_id"] = 1
	connected_players[1] = local_player_info
	
	server_started.emit()
	print("Server started on port ", port)
	
	return true


## Подключается к серверу
func join_server(address: String, port: int = 7777) -> bool:
	if current_mode != NetworkMode.OFFLINE:
		push_error("Already connected")
		return false
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	
	if error != OK:
		push_error("Failed to connect to server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = peer
	current_mode = NetworkMode.CLIENT
	server_address = address
	server_port = port
	
	print("Connecting to server ", address, ":", port)
	
	return true


## Отключается от сервера/останавливает сервер
func disconnect_from_network() -> void:
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	
	if current_mode == NetworkMode.SERVER:
		server_stopped.emit()
	elif current_mode == NetworkMode.CLIENT:
		disconnected_from_server.emit()
	
	current_mode = NetworkMode.OFFLINE
	connected_players.clear()
	
	print("Disconnected from network")


## Отправляет информацию о игроке серверу
@rpc("any_peer", "reliable")
func register_player(player_info: Dictionary) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	if current_mode == NetworkMode.SERVER:
		# Сервер получил информацию о игроке
		player_info["peer_id"] = peer_id
		connected_players[peer_id] = player_info
		
		print("Player registered: ", player_info["username"], " (", peer_id, ")")
		
		# Отправляем клиенту список всех игроков
		rpc_id(peer_id, "receive_player_list", connected_players)
		
		# Уведомляем всех остальных о новом игроке
		for other_peer_id in connected_players.keys():
			if other_peer_id != peer_id and other_peer_id != 1:
				rpc_id(other_peer_id, "player_joined", player_info)
		
		player_connected.emit(peer_id, player_info)


## Получает список игроков от сервера
@rpc("authority", "reliable")
func receive_player_list(players: Dictionary) -> void:
	connected_players = players
	local_player_info["peer_id"] = multiplayer.get_unique_id()
	
	print("Received player list: ", players.size(), " players")
	
	# Уведомляем о подключении каждого игрока
	for peer_id in players.keys():
		if peer_id != local_player_info["peer_id"]:
			player_connected.emit(peer_id, players[peer_id])


## Уведомление о присоединении игрока
@rpc("authority", "reliable")
func player_joined(player_info: Dictionary) -> void:
	var peer_id = player_info["peer_id"]
	connected_players[peer_id] = player_info
	
	print("Player joined: ", player_info["username"], " (", peer_id, ")")
	player_connected.emit(peer_id, player_info)


## Синхронизирует позицию игрока
@rpc("any_peer", "unreliable")
func sync_player_position(position: Vector3, rotation: Vector3) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Обновляем позицию игрока в сцене
	var player_node = get_node_or_null("/root/Main/Players/" + str(peer_id))
	if player_node:
		player_node.global_position = position
		player_node.rotation = rotation


## Синхронизирует действие с блоком
@rpc("any_peer", "reliable")
func sync_block_action(action: String, position: Vector3i, block_id: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Применяем действие на сервере
	if current_mode == NetworkMode.SERVER:
		var terrain_manager = get_node_or_null("/root/Main/TerrainManager")
		if terrain_manager:
			match action:
				"place":
					terrain_manager.set_block_at_world(position, block_id)
				"break":
					terrain_manager.set_block_at_world(position, "air")
		
		# Транслируем всем клиентам
		for other_peer_id in connected_players.keys():
			if other_peer_id != peer_id and other_peer_id != 1:
				rpc_id(other_peer_id, "apply_block_action", action, position, block_id)
	
	# Клиент применяет действие
	elif current_mode == NetworkMode.CLIENT:
		apply_block_action(action, position, block_id)


## Применяет действие с блоком
@rpc("authority", "reliable")
func apply_block_action(action: String, position: Vector3i, block_id: String) -> void:
	var terrain_manager = get_node_or_null("/root/Main/TerrainManager")
	if terrain_manager:
		match action:
			"place":
				terrain_manager.set_block_at_world(position, block_id)
			"break":
				terrain_manager.set_block_at_world(position, "air")


## Отправляет сообщение в чат
@rpc("any_peer", "reliable")
func send_chat_message(message: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	var player_info = connected_players.get(peer_id, {"username": "Unknown"})
	
	var chat_message = {
		"peer_id": peer_id,
		"username": player_info["username"],
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Транслируем всем
	if current_mode == NetworkMode.SERVER:
		for other_peer_id in connected_players.keys():
			rpc_id(other_peer_id, "receive_chat_message", chat_message)
	
	receive_chat_message(chat_message)


## Получает сообщение чата
@rpc("authority", "reliable")
func receive_chat_message(chat_message: Dictionary) -> void:
	print("[CHAT] ", chat_message["username"], ": ", chat_message["message"])
	# TODO: Отобразить в UI чата


## Обработчики сигналов мультиплеера
func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	
	if connected_players.has(peer_id):
		var player_info = connected_players[peer_id]
		connected_players.erase(peer_id)
		player_disconnected.emit(peer_id)
		
		# Удаляем игрока из сцены
		var player_node = get_node_or_null("/root/Main/Players/" + str(peer_id))
		if player_node:
			player_node.queue_free()


func _on_connected_to_server() -> void:
	print("Successfully connected to server")
	connected_to_server.emit()
	
	# Отправляем информацию о себе серверу
	local_player_info["peer_id"] = multiplayer.get_unique_id()
	rpc_id(1, "register_player", local_player_info)


func _on_connection_failed() -> void:
	print("Connection to server failed")
	connection_failed.emit()
	
	current_mode = NetworkMode.OFFLINE
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	print("Disconnected from server")
	disconnected_from_server.emit()
	
	current_mode = NetworkMode.OFFLINE
	connected_players.clear()
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null


## Получает информацию о игроке
func get_player_info(peer_id: int) -> Dictionary:
	return connected_players.get(peer_id, {})


## Получает локального игрока
func get_local_player_info() -> Dictionary:
	return local_player_info


## Устанавливает информацию о локальном игроке
func set_local_player_info(info: Dictionary) -> void:
	local_player_info = info


## Проверяет является ли текущий режим сервером
func is_server() -> bool:
	return current_mode == NetworkMode.SERVER


## Проверяет является ли текущий режим клиентом
func is_client() -> bool:
	return current_mode == NetworkMode.CLIENT


## Проверяет подключен ли к сети
func is_online() -> bool:
	return current_mode != NetworkMode.OFFLINE
