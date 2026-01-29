extends CharacterBody3D
class_name Player

## Базовый класс игрока
## Управляет движением, взаимодействием с миром и инвентарем

## Скорость движения
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var sneak_speed: float = 2.5

## Параметры прыжка
@export var jump_velocity: float = 6.0
@export var gravity: float = 20.0

## Чувствительность мыши
@export var mouse_sensitivity: float = 0.002

## Дальность взаимодействия с блоками
@export var reach_distance: float = 5.0

## Компоненты
@onready var camera: Camera3D = $Camera3D
@onready var head: Node3D = $Head
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D

## Текущая скорость
var current_speed: float = walk_speed

## Инвентарь
var inventory: Array = []
var selected_slot: int = 0

## Ссылка на менеджер ландшафта
var terrain_manager: TerrainManager = null

## Флаги состояния
var is_sprinting: bool = false
var is_sneaking: bool = false

## Режим полета (для отладки)
var fly_mode: bool = false


func _ready() -> void:
	# Захватываем мышь
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Настраиваем raycast
	if raycast:
		raycast.target_position = Vector3(0, 0, -reach_distance)
		raycast.enabled = true
	
	# Инициализируем инвентарь
	_initialize_inventory()


func _input(event: InputEvent) -> void:
	# Управление камерой
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event)
	
	# Освобождение мыши
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Взаимодействие с блоками
	if event.is_action_pressed("break_block"):
		_break_block()
	
	if event.is_action_pressed("place_block"):
		_place_block()
	
	# Инвентарь
	if event.is_action_pressed("inventory"):
		_toggle_inventory()


func _physics_process(delta: float) -> void:
	# Применяем гравитацию
	if not is_on_floor() and not fly_mode:
		velocity.y -= gravity * delta
	
	# Прыжок
	if Input.is_action_just_pressed("jump") and (is_on_floor() or fly_mode):
		if fly_mode:
			velocity.y = jump_velocity
		elif is_on_floor():
			velocity.y = jump_velocity
	
	# Спуск в режиме полета
	if fly_mode and Input.is_action_pressed("sneak"):
		velocity.y = -jump_velocity
	
	# Спринт и крадение
	_handle_movement_modifiers()
	
	# Получаем направление движения
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Применяем движение
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	move_and_slide()


## Обрабатывает взгляд мышью
func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	# Поворот по горизонтали
	rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Поворот по вертикали (камера)
	if head:
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)


## Обрабатывает модификаторы движения
func _handle_movement_modifiers() -> void:
	is_sprinting = Input.is_action_pressed("sprint") and not is_sneaking
	is_sneaking = Input.is_action_pressed("sneak") and not is_sprinting
	
	if is_sprinting:
		current_speed = sprint_speed
	elif is_sneaking:
		current_speed = sneak_speed
	else:
		current_speed = walk_speed


## Ломает блок
func _break_block() -> void:
	if not raycast or not terrain_manager:
		return
	
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		# Вычисляем позицию блока
		var block_pos = (collision_point - normal * 0.5).floor()
		var block_world_pos = Vector3i(int(block_pos.x), int(block_pos.y), int(block_pos.z))
		
		# Получаем блок
		var block_id = terrain_manager.get_block_at_world(block_world_pos)
		if block_id != "" and block_id != "air":
			# Удаляем блок
			terrain_manager.set_block_at_world(block_world_pos, "air")
			
			# Добавляем в инвентарь
			_add_to_inventory(block_id, 1)
			
			print("Broke block: ", block_id, " at ", block_world_pos)


## Размещает блок
func _place_block() -> void:
	if not raycast or not terrain_manager:
		return
	
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		# Вычисляем позицию для размещения (с учетом нормали)
		var block_pos = (collision_point + normal * 0.5).floor()
		var block_world_pos = Vector3i(int(block_pos.x), int(block_pos.y), int(block_pos.z))
		
		# Проверяем что не размещаем в игроке
		var player_aabb = AABB(global_position - Vector3(0.4, 0, 0.4), Vector3(0.8, 1.8, 0.8))
		var block_aabb = AABB(Vector3(block_world_pos), Vector3.ONE)
		
		if not player_aabb.intersects(block_aabb):
			# Получаем блок из инвентаря
			var block_to_place = _get_selected_block()
			if block_to_place != "":
				terrain_manager.set_block_at_world(block_world_pos, block_to_place)
				_remove_from_inventory(block_to_place, 1)
				print("Placed block: ", block_to_place, " at ", block_world_pos)


## Инициализирует инвентарь
func _initialize_inventory() -> void:
	inventory.resize(36)  # 36 слотов
	for i in range(inventory.size()):
		inventory[i] = {"item": "", "count": 0}
	
	# Даем стартовые предметы
	_add_to_inventory("dirt", 64)
	_add_to_inventory("stone", 64)
	_add_to_inventory("wood", 64)


## Добавляет предмет в инвентарь
func _add_to_inventory(item_id: String, count: int) -> bool:
	# Ищем существующий стак
	for i in range(inventory.size()):
		if inventory[i]["item"] == item_id:
			inventory[i]["count"] += count
			return true
	
	# Ищем пустой слот
	for i in range(inventory.size()):
		if inventory[i]["item"] == "":
			inventory[i] = {"item": item_id, "count": count}
			return true
	
	return false  # Инвентарь полон


## Удаляет предмет из инвентаря
func _remove_from_inventory(item_id: String, count: int) -> bool:
	for i in range(inventory.size()):
		if inventory[i]["item"] == item_id:
			if inventory[i]["count"] >= count:
				inventory[i]["count"] -= count
				if inventory[i]["count"] <= 0:
					inventory[i] = {"item": "", "count": 0}
				return true
	return false


## Получает выбранный блок
func _get_selected_block() -> String:
	if selected_slot < inventory.size():
		var slot = inventory[selected_slot]
		if slot["count"] > 0:
			return slot["item"]
	return ""


## Переключает инвентарь
func _toggle_inventory() -> void:
	# TODO: Открыть UI инвентаря
	print("Inventory:")
	for i in range(inventory.size()):
		if inventory[i]["count"] > 0:
			print("  Slot ", i, ": ", inventory[i]["item"], " x", inventory[i]["count"])


## Устанавливает менеджер ландшафта
func set_terrain_manager(manager: TerrainManager) -> void:
	terrain_manager = manager


## Включает/выключает режим полета
func toggle_fly_mode() -> void:
	fly_mode = not fly_mode
	print("Fly mode: ", "ON" if fly_mode else "OFF")
