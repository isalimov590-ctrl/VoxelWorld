extends Node3D

## Главная сцена игры
## Инициализирует все системы и связывает компоненты

@onready var terrain_manager: TerrainManager = $TerrainManager
@onready var player: Player = $Player


func _ready() -> void:
	# Связываем игрока с менеджером ландшафта
	player.set_terrain_manager(terrain_manager)
	terrain_manager.player = player
	
	# Запускаем игру
	GameManager.start_new_game("TestWorld", 12345)
	
	print("VoxelWorld started!")
	print("Controls:")
	print("  WASD - Move")
	print("  Space - Jump")
	print("  Shift - Sprint")
	print("  Ctrl - Sneak")
	print("  Left Click - Break Block")
	print("  Right Click - Place Block")
	print("  E - Inventory")
	print("  ESC - Toggle Mouse")
	print("  F3 - Toggle Fly Mode (Debug)")


func _input(event: InputEvent) -> void:
	# Отладочные команды
	if event.is_action_pressed("ui_page_up"):
		player.toggle_fly_mode()
	
	if event.is_action_pressed("ui_home"):
		# Сохранить игру
		GameManager.save_game()
		print("Game saved!")
