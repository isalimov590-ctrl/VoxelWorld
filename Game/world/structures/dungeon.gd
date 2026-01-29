extends Node
class_name DungeonGenerator

## Генератор данжей
## Создает процедурные лабиринты с комнатами, коридорами и добычей

## Типы комнат
enum RoomType {
	ENTRANCE,
	CORRIDOR,
	SMALL_ROOM,
	LARGE_ROOM,
	TREASURE_ROOM,
	BOSS_ROOM
}

## Направления
enum Direction {
	NORTH,
	SOUTH,
	EAST,
	WEST
}

## Класс комнаты
class Room:
	var position: Vector3i
	var size: Vector3i
	var type: RoomType
	var connections: Array[Direction] = []
	
	func _init(pos: Vector3i, room_size: Vector3i, room_type: RoomType) -> void:
		position = pos
		size = room_size
		type = room_type

## Параметры генерации
var dungeon_seed: int = 0
var rng: RandomNumberGenerator

## Комнаты данжа
var rooms: Array[Room] = []

## Минимальное и максимальное количество комнат
@export var min_rooms: int = 5
@export var max_rooms: int = 15

## Размеры комнат
var room_sizes: Dictionary = {
	RoomType.ENTRANCE: Vector3i(5, 4, 5),
	RoomType.CORRIDOR: Vector3i(3, 3, 7),
	RoomType.SMALL_ROOM: Vector3i(5, 4, 5),
	RoomType.LARGE_ROOM: Vector3i(9, 5, 9),
	RoomType.TREASURE_ROOM: Vector3i(7, 5, 7),
	RoomType.BOSS_ROOM: Vector3i(11, 6, 11)
}


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		dungeon_seed = randi()
	else:
		dungeon_seed = seed_value
	
	rng = RandomNumberGenerator.new()
	rng.seed = dungeon_seed


## Генерирует данж
func generate(terrain_manager, start_pos: Vector3i) -> bool:
	rooms.clear()
	
	# Определяем количество комнат
	var room_count = rng.randi_range(min_rooms, max_rooms)
	
	# Создаем входную комнату
	var entrance = Room.new(start_pos, room_sizes[RoomType.ENTRANCE], RoomType.ENTRANCE)
	rooms.append(entrance)
	
	# Генерируем остальные комнаты
	var attempts = 0
	var max_attempts = room_count * 10
	
	while rooms.size() < room_count and attempts < max_attempts:
		attempts += 1
		
		# Выбираем случайную существующую комнату
		var base_room = rooms[rng.randi_range(0, rooms.size() - 1)]
		
		# Выбираем направление
		var direction = rng.randi_range(0, 3) as Direction
		
		# Определяем тип новой комнаты
		var room_type = _choose_room_type(rooms.size(), room_count)
		
		# Пытаемся разместить комнату
		var new_room = _try_place_room(base_room, direction, room_type)
		if new_room:
			rooms.append(new_room)
			base_room.connections.append(direction)
	
	# Строим комнаты в мире
	for room in rooms:
		_build_room(terrain_manager, room)
	
	# Строим коридоры
	_build_corridors(terrain_manager)
	
	# Добавляем содержимое
	_populate_rooms(terrain_manager)
	
	return true


## Выбирает тип комнаты
func _choose_room_type(current_count: int, total_count: int) -> RoomType:
	# Последняя комната - босс
	if current_count == total_count - 1:
		return RoomType.BOSS_ROOM
	
	# Предпоследняя - сокровищница
	if current_count == total_count - 2:
		return RoomType.TREASURE_ROOM
	
	# Случайный выбор
	var roll = rng.randf()
	if roll < 0.3:
		return RoomType.CORRIDOR
	elif roll < 0.7:
		return RoomType.SMALL_ROOM
	else:
		return RoomType.LARGE_ROOM


## Пытается разместить комнату
func _try_place_room(base_room: Room, direction: Direction, room_type: RoomType) -> Room:
	var new_size = room_sizes[room_type]
	var new_pos = _calculate_room_position(base_room, direction, new_size)
	
	# Проверяем пересечения с существующими комнатами
	for room in rooms:
		if _rooms_overlap(new_pos, new_size, room.position, room.size):
			return null
	
	return Room.new(new_pos, new_size, room_type)


## Вычисляет позицию новой комнаты
func _calculate_room_position(base_room: Room, direction: Direction, new_size: Vector3i) -> Vector3i:
	var pos = base_room.position
	var base_size = base_room.size
	
	match direction:
		Direction.NORTH:
			return pos + Vector3i(0, 0, -new_size.z - 1)
		Direction.SOUTH:
			return pos + Vector3i(0, 0, base_size.z + 1)
		Direction.EAST:
			return pos + Vector3i(base_size.x + 1, 0, 0)
		Direction.WEST:
			return pos + Vector3i(-new_size.x - 1, 0, 0)
	
	return pos


## Проверяет пересечение комнат
func _rooms_overlap(pos1: Vector3i, size1: Vector3i, pos2: Vector3i, size2: Vector3i) -> bool:
	# Добавляем отступ
	var padding = 2
	
	return not (pos1.x + size1.x + padding < pos2.x or
				pos1.x > pos2.x + size2.x + padding or
				pos1.z + size1.z + padding < pos2.z or
				pos1.z > pos2.z + size2.z + padding)


## Строит комнату
func _build_room(terrain_manager, room: Room) -> void:
	var pos = room.position
	var size = room.size
	
	# Пол, стены и потолок
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var block_pos = pos + Vector3i(x, y, z)
				
				# Пол
				if y == 0:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Потолок
				elif y == size.y - 1:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Стены
				elif x == 0 or x == size.x - 1 or z == 0 or z == size.z - 1:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Воздух внутри
				else:
					terrain_manager.set_block_at_world(block_pos, "air")


## Строит коридоры между комнатами
func _build_corridors(terrain_manager) -> void:
	for i in range(rooms.size() - 1):
		var room1 = rooms[i]
		var room2 = rooms[i + 1]
		
		_build_corridor(terrain_manager, room1, room2)


## Строит коридор между двумя комнатами
func _build_corridor(terrain_manager, room1: Room, room2: Room) -> void:
	var start = room1.position + Vector3i(room1.size.x / 2, 1, room1.size.z / 2)
	var end = room2.position + Vector3i(room2.size.x / 2, 1, room2.size.z / 2)
	
	# Сначала идем по X
	var current = start
	while current.x != end.x:
		_build_corridor_segment(terrain_manager, current)
		current.x += 1 if current.x < end.x else -1
	
	# Потом по Z
	while current.z != end.z:
		_build_corridor_segment(terrain_manager, current)
		current.z += 1 if current.z < end.z else -1
	
	# Наконец по Y
	while current.y != end.y:
		_build_corridor_segment(terrain_manager, current)
		current.y += 1 if current.y < end.y else -1


## Строит сегмент коридора
func _build_corridor_segment(terrain_manager, pos: Vector3i) -> void:
	# 3x3 коридор
	for x in range(-1, 2):
		for y in range(3):
			for z in range(-1, 2):
				var block_pos = pos + Vector3i(x, y, z)
				
				# Пол
				if y == 0:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Потолок
				elif y == 2:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Стены по краям
				elif (x == -1 or x == 1) and (z == -1 or z == 1):
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Воздух
				else:
					terrain_manager.set_block_at_world(block_pos, "air")


## Заполняет комнаты содержимым
func _populate_rooms(terrain_manager) -> void:
	for room in rooms:
		match room.type:
			RoomType.ENTRANCE:
				_populate_entrance(terrain_manager, room)
			RoomType.TREASURE_ROOM:
				_populate_treasure_room(terrain_manager, room)
			RoomType.BOSS_ROOM:
				_populate_boss_room(terrain_manager, room)
			_:
				_populate_generic_room(terrain_manager, room)


## Заполняет входную комнату
func _populate_entrance(terrain_manager, room: Room) -> void:
	var center = room.position + Vector3i(room.size.x / 2, 1, room.size.z / 2)
	
	# Факелы по углам
	terrain_manager.set_block_at_world(room.position + Vector3i(1, 1, 1), "torch")
	terrain_manager.set_block_at_world(room.position + Vector3i(room.size.x - 2, 1, 1), "torch")
	terrain_manager.set_block_at_world(room.position + Vector3i(1, 1, room.size.z - 2), "torch")
	terrain_manager.set_block_at_world(room.position + Vector3i(room.size.x - 2, 1, room.size.z - 2), "torch")


## Заполняет комнату с сокровищами
func _populate_treasure_room(terrain_manager, room: Room) -> void:
	var center = room.position + Vector3i(room.size.x / 2, 1, room.size.z / 2)
	
	# Сундуки с добычей
	terrain_manager.set_block_at_world(center, "chest")
	terrain_manager.set_block_at_world(center + Vector3i(-2, 0, 0), "chest")
	terrain_manager.set_block_at_world(center + Vector3i(2, 0, 0), "chest")
	
	# Факелы
	for i in range(4):
		var angle = i * PI / 2
		var offset = Vector3i(int(cos(angle) * 3), 1, int(sin(angle) * 3))
		terrain_manager.set_block_at_world(center + offset, "torch")


## Заполняет комнату босса
func _populate_boss_room(terrain_manager, room: Room) -> void:
	var center = room.position + Vector3i(room.size.x / 2, 1, room.size.z / 2)
	
	# Пьедестал для босса
	for x in range(-1, 2):
		for z in range(-1, 2):
			terrain_manager.set_block_at_world(center + Vector3i(x, 0, z), "stone_bricks")
	
	# Факелы по периметру
	for i in range(8):
		var angle = i * PI / 4
		var offset = Vector3i(int(cos(angle) * 4), 1, int(sin(angle) * 4))
		terrain_manager.set_block_at_world(center + offset, "torch")


## Заполняет обычную комнату
func _populate_generic_room(terrain_manager, room: Room) -> void:
	# Случайные факелы
	var torch_count = rng.randi_range(2, 4)
	for i in range(torch_count):
		var x = rng.randi_range(1, room.size.x - 2)
		var z = rng.randi_range(1, room.size.z - 2)
		var pos = room.position + Vector3i(x, 1, z)
		
		# Проверяем что это стена
		if x == 1 or x == room.size.x - 2 or z == 1 or z == room.size.z - 2:
			terrain_manager.set_block_at_world(pos, "torch")
