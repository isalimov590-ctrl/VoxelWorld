extends Node

## Главный менеджер игры
## Управляет глобальным состоянием игры, настройками и системами

## Сигналы
signal game_started
signal game_paused
signal game_resumed
signal game_saved
signal game_loaded

## Состояние игры
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	LOADING
}

var current_state: GameState = GameState.MENU

## Настройки игры
var settings: Dictionary = {
	"render_distance": 8,
	"fov": 90,
	"mouse_sensitivity": 0.002,
	"master_volume": 1.0,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"vsync": true,
	"max_fps": 60
}

## Информация о мире
var world_info: Dictionary = {
	"name": "New World",
	"seed": 0,
	"game_mode": "survival",  # survival, creative, adventure
	"difficulty": "normal",   # peaceful, easy, normal, hard
	"time": 0,
	"day": 0
}

## Статистика игрока
var player_stats: Dictionary = {
	"playtime": 0.0,
	"blocks_broken": 0,
	"blocks_placed": 0,
	"distance_walked": 0.0,
	"jumps": 0,
	"deaths": 0
}

## Путь к настройкам
const SETTINGS_PATH: String = "user://settings.json"
const WORLDS_PATH: String = "user://worlds/"


func _ready() -> void:
	# Загружаем настройки
	load_settings()
	
	# Применяем настройки
	apply_settings()
	
	# Создаем директории
	DirAccess.make_dir_recursive_absolute(WORLDS_PATH)


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		# Обновляем время игры
		player_stats["playtime"] += delta
		world_info["time"] += delta


## Начинает новую игру
func start_new_game(world_name: String, seed_value: int = 0) -> void:
	world_info["name"] = world_name
	world_info["seed"] = seed_value if seed_value != 0 else randi()
	world_info["time"] = 0
	world_info["day"] = 0
	
	# Сбрасываем статистику
	player_stats = {
		"playtime": 0.0,
		"blocks_broken": 0,
		"blocks_placed": 0,
		"distance_walked": 0.0,
		"jumps": 0,
		"deaths": 0
	}
	
	current_state = GameState.PLAYING
	game_started.emit()


## Загружает игру
func load_game(world_name: String) -> bool:
	var save_path = WORLDS_PATH + world_name + "/world.json"
	
	if not FileAccess.file_exists(save_path):
		push_error("Save file not found: " + save_path)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file")
		return false
	
	var save_data = json.get_data()
	
	# Загружаем данные
	world_info = save_data.get("world_info", world_info)
	player_stats = save_data.get("player_stats", player_stats)
	
	current_state = GameState.PLAYING
	game_loaded.emit()
	
	return true


## Сохраняет игру
func save_game() -> bool:
	var save_dir = WORLDS_PATH + world_info["name"] + "/"
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_data = {
		"world_info": world_info,
		"player_stats": player_stats,
		"version": "0.1.0",
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(save_dir + "world.json", FileAccess.WRITE)
	if not file:
		push_error("Failed to create save file")
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	game_saved.emit()
	print("Game saved successfully")
	
	return true


## Ставит игру на паузу
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit()


## Возобновляет игру
func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_resumed.emit()


## Загружает настройки
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		# Сохраняем настройки по умолчанию
		save_settings()
		return
	
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		var loaded_settings = json.get_data()
		# Обновляем настройки
		for key in loaded_settings:
			if settings.has(key):
				settings[key] = loaded_settings[key]


## Сохраняет настройки
func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to save settings")
		return
	
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()


## Применяет настройки
func apply_settings() -> void:
	# Полноэкранный режим
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# VSync
	if settings["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Максимальный FPS
	Engine.max_fps = settings["max_fps"]
	
	# Громкость
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 
		linear_to_db(settings["master_volume"]))


## Изменяет настройку
func set_setting(key: String, value) -> void:
	if settings.has(key):
		settings[key] = value
		save_settings()
		apply_settings()


## Получает настройку
func get_setting(key: String, default_value = null):
	return settings.get(key, default_value)


## Обновляет статистику
func update_stat(stat_name: String, value: float) -> void:
	if player_stats.has(stat_name):
		player_stats[stat_name] += value


## Получает список миров
func get_world_list() -> Array:
	var worlds: Array = []
	var dir = DirAccess.open(WORLDS_PATH)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				var world_data = _load_world_info(file_name)
				if world_data:
					worlds.append(world_data)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	return worlds


## Загружает информацию о мире
func _load_world_info(world_name: String) -> Dictionary:
	var save_path = WORLDS_PATH + world_name + "/world.json"
	
	if not FileAccess.file_exists(save_path):
		return {}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return {}
	
	var save_data = json.get_data()
	return save_data.get("world_info", {})


## Удаляет мир
func delete_world(world_name: String) -> bool:
	var world_path = WORLDS_PATH + world_name + "/"
	
	# Рекурсивно удаляем директорию
	return _delete_directory_recursive(world_path)


## Рекурсивно удаляет директорию
func _delete_directory_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if not dir:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_delete_directory_recursive(path + file_name + "/")
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	dir.remove(path)
	
	return true


## Выходит из игры
func quit_game() -> void:
	# Сохраняем перед выходом
	if current_state == GameState.PLAYING or current_state == GameState.PAUSED:
		save_game()
	
	get_tree().quit()
