extends Node

## Менеджер модов
## Управляет установкой, обновлением и удалением модов

signal mod_installed(mod_id: String)
signal mod_uninstalled(mod_id: String)
signal mod_enabled(mod_id: String)
signal mod_disabled(mod_id: String)
signal mods_list_updated

## Путь к директории модов
var mods_dir: String = "user://mods/"

## Список установленных модов
var installed_mods: Array = []

## Список активных модов
var enabled_mods: Array = []

## HTTP клиент для загрузки
var http_client: HTTPRequest


func _ready() -> void:
	# Создаем директорию модов
	DirAccess.make_dir_recursive_absolute(mods_dir)
	
	# Создаем HTTP клиент
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_download_completed)
	
	# Загружаем список модов
	_load_mods_list()


## Загружает список установленных модов
func _load_mods_list() -> void:
	installed_mods.clear()
	enabled_mods.clear()
	
	var dir = DirAccess.open(mods_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var mod_info = _load_mod_info(file_name)
			if mod_info:
				installed_mods.append(mod_info)
				
				# Проверяем включен ли мод
				if mod_info.get("enabled", false):
					enabled_mods.append(mod_info["id"])
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	mods_list_updated.emit()


## Загружает информацию о моде
func _load_mod_info(mod_id: String) -> Dictionary:
	var info_path = mods_dir + mod_id + "/mod.json"
	
	if not FileAccess.file_exists(info_path):
		return {}
	
	var file = FileAccess.open(info_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return {}
	
	return json.get_data()


## Сохраняет информацию о моде
func _save_mod_info(mod_id: String, mod_info: Dictionary) -> void:
	var info_path = mods_dir + mod_id + "/mod.json"
	
	var file = FileAccess.open(info_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(mod_info, "\t"))
		file.close()


## Устанавливает мод из файла
func install_mod_from_file(file_path: String) -> bool:
	# TODO: Распаковать архив мода
	# TODO: Проверить структуру мода
	# TODO: Скопировать в директорию модов
	
	print("Installing mod from: ", file_path)
	
	# Перезагружаем список
	_load_mods_list()
	
	return true


## Устанавливает мод по URL
func install_mod_from_url(url: String, mod_id: String) -> void:
	print("Downloading mod from: ", url)
	
	var error = http_client.request(url)
	if error != OK:
		push_error("Failed to download mod: " + str(error))
	else:
		http_client.set_meta("mod_id", mod_id)
		http_client.set_meta("action", "install")


## Удаляет мод
func uninstall_mod(mod_id: String) -> bool:
	var mod_path = mods_dir + mod_id + "/"
	
	if not DirAccess.dir_exists_absolute(mod_path):
		return false
	
	# Рекурсивно удаляем директорию
	_delete_directory_recursive(mod_path)
	
	# Перезагружаем список
	_load_mods_list()
	
	mod_uninstalled.emit(mod_id)
	
	return true


## Включает мод
func enable_mod(mod_id: String) -> bool:
	var mod_info = _get_mod_info(mod_id)
	if not mod_info:
		return false
	
	mod_info["enabled"] = true
	_save_mod_info(mod_id, mod_info)
	
	if not enabled_mods.has(mod_id):
		enabled_mods.append(mod_id)
	
	mod_enabled.emit(mod_id)
	
	return true


## Отключает мод
func disable_mod(mod_id: String) -> bool:
	var mod_info = _get_mod_info(mod_id)
	if not mod_info:
		return false
	
	mod_info["enabled"] = false
	_save_mod_info(mod_id, mod_info)
	
	enabled_mods.erase(mod_id)
	
	mod_disabled.emit(mod_id)
	
	return true


## Получает информацию о моде
func _get_mod_info(mod_id: String) -> Dictionary:
	for mod in installed_mods:
		if mod.get("id", "") == mod_id:
			return mod
	return {}


## Получает список установленных модов
func get_installed_mods() -> Array:
	return installed_mods


## Получает список включенных модов
func get_enabled_mods() -> Array:
	return enabled_mods


## Проверяет установлен ли мод
func is_mod_installed(mod_id: String) -> bool:
	for mod in installed_mods:
		if mod.get("id", "") == mod_id:
			return true
	return false


## Проверяет включен ли мод
func is_mod_enabled(mod_id: String) -> bool:
	return enabled_mods.has(mod_id)


## Обработчик завершения загрузки
func _on_download_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var mod_id = http_client.get_meta("mod_id", "")
	var action = http_client.get_meta("action", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Download failed: " + str(result))
		return
	
	if response_code != 200:
		push_error("Download failed with code: " + str(response_code))
		return
	
	match action:
		"install":
			_install_mod_from_data(mod_id, body)


## Устанавливает мод из данных
func _install_mod_from_data(mod_id: String, data: PackedByteArray) -> void:
	var mod_path = mods_dir + mod_id + "/"
	DirAccess.make_dir_recursive_absolute(mod_path)
	
	# Сохраняем архив
	var archive_path = mod_path + "mod.zip"
	var file = FileAccess.open(archive_path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()
	
	# TODO: Распаковать архив
	
	# Перезагружаем список
	_load_mods_list()
	
	mod_installed.emit(mod_id)


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
	DirAccess.remove_absolute(path)
	
	return true


## Копирует моды в игру
func copy_mods_to_game(game_path: String) -> bool:
	var game_mods_dir = game_path + "/mods/"
	DirAccess.make_dir_recursive_absolute(game_mods_dir)
	
	# Очищаем директорию
	_delete_directory_recursive(game_mods_dir)
	DirAccess.make_dir_recursive_absolute(game_mods_dir)
	
	# Копируем включенные моды
	for mod_id in enabled_mods:
		var source_path = mods_dir + mod_id + "/"
		var dest_path = game_mods_dir + mod_id + "/"
		
		_copy_directory_recursive(source_path, dest_path)
	
	return true


## Рекурсивно копирует директорию
func _copy_directory_recursive(source: String, dest: String) -> void:
	DirAccess.make_dir_recursive_absolute(dest)
	
	var dir = DirAccess.open(source)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var source_file = source + file_name
		var dest_file = dest + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_copy_directory_recursive(source_file + "/", dest_file + "/")
		else:
			DirAccess.copy_absolute(source_file, dest_file)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
