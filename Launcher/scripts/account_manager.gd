extends Node

## Менеджер аккаунтов
## Управляет аутентификацией и профилем пользователя

signal login_success(user_data: Dictionary)
signal login_failed(error: String)
signal logout_complete

## API URL
var api_url: String = "http://localhost:8000"

## Текущий пользователь
var current_user: Dictionary = {}
var access_token: String = ""
var refresh_token: String = ""

## Флаг авторизации
var is_logged_in: bool = false

## HTTP клиент
var http_client: HTTPRequest


func _ready() -> void:
	# Создаем HTTP клиент
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	
	# Загружаем сохраненную сессию
	_load_session()


## Регистрация нового пользователя
func register(username: String, email: String, password: String) -> void:
	var data = {
		"username": username,
		"email": email,
		"password": password
	}
	
	_make_request("/auth/register", data, "register")


## Вход в систему
func login(username: String, password: String) -> void:
	var data = {
		"username": username,
		"password": password
	}
	
	_make_request("/auth/login", data, "login")


## Выход из системы
func logout() -> void:
	current_user = {}
	access_token = ""
	refresh_token = ""
	is_logged_in = false
	
	# Удаляем сохраненную сессию
	_clear_session()
	
	logout_complete.emit()


## Обновление токена
func refresh_access_token() -> void:
	if refresh_token.is_empty():
		return
	
	var data = {
		"refresh_token": refresh_token
	}
	
	_make_request("/auth/refresh", data, "refresh")


## Проверка токена
func verify_token() -> void:
	if access_token.is_empty():
		return
	
	var data = {
		"token": access_token
	}
	
	_make_request("/auth/verify", data, "verify")


## Получение профиля пользователя
func get_user_profile() -> void:
	if access_token.is_empty():
		return
	
	_make_request_with_auth("/users/me", {}, "get_profile")


## Обновление профиля
func update_profile(display_name: String = "", avatar_url: String = "", skin_data: String = "") -> void:
	if access_token.is_empty():
		return
	
	var data = {}
	if not display_name.is_empty():
		data["display_name"] = display_name
	if not avatar_url.is_empty():
		data["avatar_url"] = avatar_url
	if not skin_data.is_empty():
		data["skin_data"] = skin_data
	
	_make_request_with_auth("/users/me/profile", data, "update_profile", HTTPClient.METHOD_PUT)


## Выполняет HTTP запрос
func _make_request(endpoint: String, data: Dictionary, request_type: String, method: int = HTTPClient.METHOD_POST) -> void:
	var url = api_url + endpoint
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(data)
	
	var error = http_client.request(url, headers, method, body)
	if error != OK:
		push_error("HTTP request failed: " + str(error))
		login_failed.emit("Connection error")
	else:
		# Сохраняем тип запроса
		http_client.set_meta("request_type", request_type)


## Выполняет HTTP запрос с авторизацией
func _make_request_with_auth(endpoint: String, data: Dictionary, request_type: String, method: int = HTTPClient.METHOD_GET) -> void:
	var url = api_url + endpoint
	
	# Добавляем токен в параметры
	if method == HTTPClient.METHOD_GET and not data.is_empty():
		url += "?"
		for key in data.keys():
			url += key + "=" + str(data[key]) + "&"
		url = url.trim_suffix("&")
	
	# Добавляем токен в query параметр
	if url.contains("?"):
		url += "&token=" + access_token
	else:
		url += "?token=" + access_token
	
	var headers = ["Content-Type: application/json"]
	var body = ""
	
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(data)
	
	var error = http_client.request(url, headers, method, body)
	if error != OK:
		push_error("HTTP request failed: " + str(error))
	else:
		http_client.set_meta("request_type", request_type)


## Обработчик завершения запроса
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_type = http_client.get_meta("request_type", "")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Request failed: " + str(result))
		login_failed.emit("Network error")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("Failed to parse response")
		login_failed.emit("Invalid response")
		return
	
	var response = json.get_data()
	
	# Обрабатываем ответ в зависимости от типа запроса
	match request_type:
		"register", "login", "refresh":
			_handle_auth_response(response, response_code)
		"verify":
			_handle_verify_response(response, response_code)
		"get_profile":
			_handle_profile_response(response, response_code)
		"update_profile":
			_handle_update_profile_response(response, response_code)


## Обрабатывает ответ аутентификации
func _handle_auth_response(response: Dictionary, response_code: int) -> void:
	if response_code == 200:
		access_token = response.get("access_token", "")
		refresh_token = response.get("refresh_token", "")
		current_user = response.get("user", {})
		is_logged_in = true
		
		# Сохраняем сессию
		_save_session()
		
		login_success.emit(current_user)
	else:
		var error_message = response.get("detail", "Login failed")
		login_failed.emit(error_message)


## Обрабатывает ответ проверки токена
func _handle_verify_response(response: Dictionary, response_code: int) -> void:
	if response_code == 200:
		is_logged_in = response.get("valid", false)
		if is_logged_in:
			current_user = response.get("user", {})
	else:
		is_logged_in = false
		_clear_session()


## Обрабатывает ответ профиля
func _handle_profile_response(response: Dictionary, response_code: int) -> void:
	if response_code == 200:
		current_user = response
	else:
		push_error("Failed to get profile")


## Обрабатывает ответ обновления профиля
func _handle_update_profile_response(response: Dictionary, response_code: int) -> void:
	if response_code == 200:
		current_user = response
		print("Profile updated successfully")
	else:
		push_error("Failed to update profile")


## Сохраняет сессию
func _save_session() -> void:
	var session_data = {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user": current_user
	}
	
	var file = FileAccess.open("user://session.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session_data))
		file.close()


## Загружает сессию
func _load_session() -> void:
	if not FileAccess.file_exists("user://session.json"):
		return
	
	var file = FileAccess.open("user://session.json", FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return
	
	var session_data = json.get_data()
	access_token = session_data.get("access_token", "")
	refresh_token = session_data.get("refresh_token", "")
	current_user = session_data.get("user", {})
	
	if not access_token.is_empty():
		# Проверяем токен
		verify_token()


## Очищает сессию
func _clear_session() -> void:
	if FileAccess.file_exists("user://session.json"):
		DirAccess.remove_absolute("user://session.json")


## Получает текущего пользователя
func get_current_user() -> Dictionary:
	return current_user


## Проверяет авторизацию
func check_logged_in() -> bool:
	return is_logged_in and not access_token.is_empty()
