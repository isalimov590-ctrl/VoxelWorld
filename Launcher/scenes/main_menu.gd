extends Control

## Главное меню лаунчера

@onready var username_input = $VBoxContainer/LoginPanel/LoginVBox/UsernameInput
@onready var password_input = $VBoxContainer/LoginPanel/LoginVBox/PasswordInput
@onready var login_button = $VBoxContainer/LoginPanel/LoginVBox/ButtonsHBox/LoginButton
@onready var register_button = $VBoxContainer/LoginPanel/LoginVBox/ButtonsHBox/RegisterButton
@onready var play_button = $VBoxContainer/PlayButton
@onready var status_label = $StatusLabel
@onready var login_panel = $VBoxContainer/LoginPanel


func _ready() -> void:
	# Подключаем сигналы менеджеров
	AccountManager.login_success.connect(_on_login_success)
	AccountManager.login_failed.connect(_on_login_failed)
	
	GameUpdater.update_available.connect(_on_update_available)
	
	# Проверяем авторизацию
	if AccountManager.check_logged_in():
		_on_login_success(AccountManager.get_current_user())
	
	# Проверяем обновления
	GameUpdater.check_for_updates()


func _on_login_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		status_label.text = "Please enter username and password"
		return
	
	status_label.text = "Logging in..."
	login_button.disabled = true
	register_button.disabled = true
	
	AccountManager.login(username, password)


func _on_register_pressed() -> void:
	# TODO: Открыть окно регистрации
	status_label.text = "Registration not implemented yet"


func _on_login_success(user_data: Dictionary) -> void:
	status_label.text = "Logged in as " + user_data.get("username", "Unknown")
	
	login_panel.visible = false
	play_button.disabled = false
	
	login_button.disabled = false
	register_button.disabled = false


func _on_login_failed(error: String) -> void:
	status_label.text = "Login failed: " + error
	
	login_button.disabled = false
	register_button.disabled = false


func _on_play_pressed() -> void:
	if not GameUpdater.is_game_installed():
		status_label.text = "Game not installed. Downloading..."
		# TODO: Скачать игру
		return
	
	# Копируем моды в игру
	var game_path = GameUpdater.game_path
	ModManager.copy_mods_to_game(game_path)
	
	# Запускаем игру
	status_label.text = "Launching game..."
	
	var success = GameUpdater.launch_game()
	if success:
		# Закрываем лаунчер
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
	else:
		status_label.text = "Failed to launch game"


func _on_mods_pressed() -> void:
	# TODO: Открыть окно модов
	status_label.text = "Mods manager not implemented yet"


func _on_settings_pressed() -> void:
	# TODO: Открыть окно настроек
	status_label.text = "Settings not implemented yet"


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_update_available(version: String, changelog: String) -> void:
	status_label.text = "Update available: v" + version
	# TODO: Показать окно обновления
