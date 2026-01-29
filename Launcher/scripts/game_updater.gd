extends Node

## Менеджер обновлений игры
## Проверяет и устанавливает обновления

signal update_available(version: String, changelog: String)
signal update_progress(progress: float)
signal update_complete
signal update_failed(error: String)

## URL для проверки обновлений
var update_url: String = "https://api.github.com/repos/isalimov590-ctrl/VoxelWorld/releases/latest"

## Текущая версия
var current_version: String = "0.1.0"

## Путь к игре
var game_path: String = "user://game/"

## HTTP клиент
var http_client: HTTPRequest


func _ready() -> void:
	# Создаем HTTP клиент
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	
	# Создаем директорию игры
	DirAccess.make_dir_recursive_absolute(game_path)


## Проверяет наличие обновлений
func check_for_updates() -> void:
	print("Checking for updates...")
	
	var headers = ["User-Agent: VoxelWorld-Launcher"]
	var error = http_client.request(update_url, headers)
	
	if error != OK:
		push_error("Failed to check for updates: " + str(error))
		update_failed.emit("Network error")
	else:
		http_client.set_meta("action", "check_update")


## Загружает обновление
func download_update(download_url: String) -> void:
	print("Downloading update from: ", download_url)
	
	var error = http_client.request(download_url)
	if error != OK:
		push_error("Failed to download update: " + str(error))
		update_failed.emit("Download error")
	else:
		http_client.set_meta("action", "download_update")


## Устанавливает обновление
func install_update(update_file: String) -> bool:
	print("Installing update from: ", update_file)
	
	# TODO: Распаковать обновление
	# TODO: Заменить файлы игры
	
	update_complete.emit()
	
	return true


## Запускает игру
func launch_game(args: PackedStringArray = []) -> bool:
	var executable_path = _get_game_executable()
	
	if executable_path.is_empty():
		push_error("Game executable not found")
		return false
	
	print("Launching game: ", executable_path)
	
	var pid = OS.create_process(executable_path, args)
	
	if pid == -1:
		push_error("Failed to launch game")
		return false
	
	return true


## Получает путь к исполняемому файлу игры
func _get_game_executable() -> String:
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			return game_path + "VoxelWorld.exe"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return game_path + "VoxelWorld.x86_64"
		"macOS":
			return game_path + "VoxelWorld.app/Contents/MacOS/VoxelWorld"
		_:
			return ""


## Проверяет установлена ли игра
func is_game_installed() -> bool:
	var executable = _get_game_executable()
	return FileAccess.file_exists(executable)


## Получает версию установленной игры
func get_installed_version() -> String:
	var version_file = game_path + "version.txt"
	
	if not FileAccess.file_exists(version_file):
		return "0.0.0"
	
	var file = FileAccess.open(version_file, FileAccess.READ)
	if not file:
		return "0.0.0"
	
	var version = file.get_line().strip_edges()
	file.close()
	
	return version


## Сравнивает версии
func compare_versions(version1: String, version2: String) -> int:
	var v1_parts = version1.split(".")
	var v2_parts = version2.split(".")
	
	for i in range(max(v1_parts.size(), v2_parts.size())):
		var v1_num = int(v1_parts[i]) if i < v1_parts.size() else 0
		var v2_num = int(v2_parts[i]) if i < v2_parts.size() else 0
		
		if v1_num > v2_num:
			return 1
		elif v1_num < v2_num:
			return -1
	
	return 0


## Обработчик завершения запроса
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var action = http_client.get_meta("action", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Request failed: " + str(result))
		update_failed.emit("Network error")
		return
	
	match action:
		"check_update":
			_handle_update_check(response_code, body)
		"download_update":
			_handle_update_download(response_code, body)


## Обрабатывает проверку обновлений
func _handle_update_check(response_code: int, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("Update check failed with code: " + str(response_code))
		update_failed.emit("Server error")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("Failed to parse update response")
		update_failed.emit("Invalid response")
		return
	
	var release_data = json.get_data()
	
	var latest_version = release_data.get("tag_name", "").trim_prefix("v")
	var changelog = release_data.get("body", "")
	
	var installed_version = get_installed_version()
	
	if compare_versions(latest_version, installed_version) > 0:
		print("Update available: ", latest_version)
		update_available.emit(latest_version, changelog)
	else:
		print("Game is up to date")


## Обрабатывает загрузку обновления
func _handle_update_download(response_code: int, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("Update download failed with code: " + str(response_code))
		update_failed.emit("Download error")
		return
	
	# Сохраняем обновление
	var update_file = "user://update.zip"
	var file = FileAccess.open(update_file, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		
		# Устанавливаем обновление
		install_update(update_file)
	else:
		push_error("Failed to save update file")
		update_failed.emit("Save error")
