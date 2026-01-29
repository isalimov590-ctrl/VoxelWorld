extends Node
class_name WorldGenerator

## Генератор мира
## Отвечает за процедурную генерацию ландшафта, биомов и структур

## Сид мира
var world_seed: int = 0

## Шум для высоты ландшафта
var height_noise: FastNoiseLite

## Шум для биомов
var biome_noise: FastNoiseLite

## Шум для пещер
var cave_noise: FastNoiseLite

## Шум для деталей
var detail_noise: FastNoiseLite

## Параметры генерации
@export var base_height: int = 64
@export var height_variation: int = 32
@export var water_level: int = 60

## Биомы
var biomes: Dictionary = {}

## Структуры
var structures: Array = []


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		world_seed = randi()
	else:
		world_seed = seed_value
	
	_initialize_noise()
	_initialize_biomes()


## Инициализирует генераторы шума
func _initialize_noise() -> void:
	# Шум для высоты
	height_noise = FastNoiseLite.new()
	height_noise.seed = world_seed
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.005
	height_noise.fractal_octaves = 4
	height_noise.fractal_gain = 0.5
	height_noise.fractal_lacunarity = 2.0
	
	# Шум для биомов
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = world_seed + 1000
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.002
	biome_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	biome_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# Шум для пещер
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = world_seed + 2000
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.03
	cave_noise.fractal_octaves = 2
	
	# Шум для деталей (руда, растительность)
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = world_seed + 3000
	detail_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail_noise.frequency = 0.1


## Инициализирует биомы
func _initialize_biomes() -> void:
	biomes = {
		"plains": {
			"name": "Plains",
			"height_offset": 0,
			"height_scale": 1.0,
			"surface_block": "grass",
			"subsurface_block": "dirt",
			"stone_depth": 4,
			"tree_chance": 0.01,
			"grass_chance": 0.3
		},
		"forest": {
			"name": "Forest",
			"height_offset": 2,
			"height_scale": 1.2,
			"surface_block": "grass",
			"subsurface_block": "dirt",
			"stone_depth": 4,
			"tree_chance": 0.1,
			"grass_chance": 0.5
		},
		"desert": {
			"name": "Desert",
			"height_offset": -5,
			"height_scale": 0.8,
			"surface_block": "sand",
			"subsurface_block": "sand",
			"stone_depth": 8,
			"tree_chance": 0.0,
			"grass_chance": 0.0
		},
		"mountains": {
			"name": "Mountains",
			"height_offset": 20,
			"height_scale": 2.0,
			"surface_block": "stone",
			"subsurface_block": "stone",
			"stone_depth": 0,
			"tree_chance": 0.0,
			"grass_chance": 0.1
		},
		"tundra": {
			"name": "Tundra",
			"height_offset": 0,
			"height_scale": 0.9,
			"surface_block": "snow",
			"subsurface_block": "dirt",
			"stone_depth": 4,
			"tree_chance": 0.02,
			"grass_chance": 0.1
		}
	}


## Генерирует чанк
func generate_chunk(chunk: Chunk, chunk_pos: Vector3i) -> void:
	var chunk_size = Chunk.CHUNK_SIZE
	var world_offset = Vector3i(
		chunk_pos.x * chunk_size,
		chunk_pos.y * chunk_size,
		chunk_pos.z * chunk_size
	)
	
	# Генерируем блоки
	for x in range(chunk_size):
		for z in range(chunk_size):
			var world_x = world_offset.x + x
			var world_z = world_offset.z + z
			
			# Определяем биом
			var biome = _get_biome_at(world_x, world_z)
			
			# Получаем высоту ландшафта
			var terrain_height = _get_terrain_height(world_x, world_z, biome)
			
			# Генерируем колонну блоков
			for y in range(chunk_size):
				var world_y = world_offset.y + y
				
				var block_id = _get_block_at(world_x, world_y, world_z, terrain_height, biome)
				
				if block_id != "" and block_id != "air":
					chunk.set_block(Vector3i(x, y, z), block_id)


## Получает биом в позиции
func _get_biome_at(x: int, z: int) -> Dictionary:
	var biome_value = biome_noise.get_noise_2d(x, z)
	
	# Определяем биом по значению шума
	if biome_value < -0.5:
		return biomes["desert"]
	elif biome_value < -0.2:
		return biomes["plains"]
	elif biome_value < 0.2:
		return biomes["forest"]
	elif biome_value < 0.5:
		return biomes["tundra"]
	else:
		return biomes["mountains"]


## Получает высоту ландшафта
func _get_terrain_height(x: int, z: int, biome: Dictionary) -> int:
	var noise_value = height_noise.get_noise_2d(x, z)
	
	# Нормализуем от -1..1 к 0..1
	noise_value = (noise_value + 1.0) * 0.5
	
	# Применяем параметры биома
	var height = base_height + biome["height_offset"]
	height += int(noise_value * height_variation * biome["height_scale"])
	
	return height


## Получает блок в позиции
func _get_block_at(x: int, y: int, z: int, terrain_height: int, biome: Dictionary) -> String:
	# Воздух выше ландшафта
	if y > terrain_height:
		# Вода на уровне моря
		if y <= water_level:
			return "water"
		return "air"
	
	# Проверяем пещеры
	if _is_cave(x, y, z):
		return "air"
	
	# Коренная порода внизу
	if y <= 0:
		return "bedrock"
	
	# Камень глубоко под землей
	if y < terrain_height - biome["stone_depth"]:
		# Руды
		var ore = _get_ore_at(x, y, z)
		if ore != "":
			return ore
		return "stone"
	
	# Подповерхностный блок
	if y < terrain_height:
		return biome["subsurface_block"]
	
	# Поверхностный блок
	return biome["surface_block"]


## Проверяет является ли позиция пещерой
func _is_cave(x: int, y: int, z: int) -> bool:
	# Пещеры только ниже определенного уровня
	if y > base_height - 10:
		return false
	
	var cave_value = cave_noise.get_noise_3d(x, y, z)
	
	# Создаем пещеры где шум в определенном диапазоне
	return cave_value > 0.6 or cave_value < -0.6


## Получает руду в позиции
func _get_ore_at(x: int, y: int, z: int) -> String:
	var ore_value = detail_noise.get_noise_3d(x, y, z)
	
	# Угольная руда (часто, на любой высоте)
	if ore_value > 0.85 and y < base_height:
		return "coal_ore"
	
	# Железная руда (средне, до высоты 64)
	if ore_value > 0.9 and y < 64:
		return "iron_ore"
	
	# Золотая руда (редко, до высоты 32)
	if ore_value > 0.93 and y < 32:
		return "gold_ore"
	
	# Алмазная руда (очень редко, до высоты 16)
	if ore_value > 0.96 and y < 16:
		return "diamond_ore"
	
	return ""


## Генерирует дерево в позиции
func generate_tree(terrain_manager, pos: Vector3i, tree_type: String = "oak") -> void:
	match tree_type:
		"oak":
			_generate_oak_tree(terrain_manager, pos)
		"pine":
			_generate_pine_tree(terrain_manager, pos)
		_:
			_generate_oak_tree(terrain_manager, pos)


## Генерирует дубовое дерево
func _generate_oak_tree(terrain_manager, pos: Vector3i) -> void:
	var trunk_height = randi_range(4, 6)
	
	# Ствол
	for y in range(trunk_height):
		terrain_manager.set_block_at_world(pos + Vector3i(0, y, 0), "wood")
	
	# Крона
	var crown_y = pos.y + trunk_height
	for x in range(-2, 3):
		for z in range(-2, 3):
			for y in range(3):
				# Пропускаем углы на нижнем уровне
				if y == 0 and abs(x) == 2 and abs(z) == 2:
					continue
				
				# Меньше листьев на верхнем уровне
				if y == 2 and (abs(x) > 1 or abs(z) > 1):
					continue
				
				var leaf_pos = pos + Vector3i(x, crown_y + y, z)
				# Не заменяем ствол
				if x == 0 and z == 0 and y < 2:
					continue
				
				terrain_manager.set_block_at_world(leaf_pos, "leaves")


## Генерирует сосну
func _generate_pine_tree(terrain_manager, pos: Vector3i) -> void:
	var trunk_height = randi_range(6, 9)
	
	# Ствол
	for y in range(trunk_height):
		terrain_manager.set_block_at_world(pos + Vector3i(0, y, 0), "wood")
	
	# Коническая крона
	var crown_y = pos.y + trunk_height - 4
	for level in range(5):
		var radius = 2 - int(level * 0.4)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if abs(x) + abs(z) <= radius:
					var leaf_pos = pos + Vector3i(x, crown_y + level, z)
					if x == 0 and z == 0:
						continue
					terrain_manager.set_block_at_world(leaf_pos, "leaves")


## Проверяет можно ли разместить структуру
func can_place_structure(terrain_manager, pos: Vector3i, size: Vector3i) -> bool:
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				var check_pos = pos + Vector3i(x, y, z)
				var block = terrain_manager.get_block_at_world(check_pos)
				if block != "air" and block != "":
					return false
	return true


## Генерирует данж в позиции
func generate_dungeon(terrain_manager, pos: Vector3i) -> void:
	# Простой данж - комната с коридорами
	var room_size = Vector3i(7, 4, 7)
	
	# Очищаем пространство
	for x in range(room_size.x):
		for y in range(room_size.y):
			for z in range(room_size.z):
				var block_pos = pos + Vector3i(x, y, z)
				
				# Стены
				if x == 0 or x == room_size.x - 1 or z == 0 or z == room_size.z - 1:
					if y > 0:
						terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Пол
				elif y == 0:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Потолок
				elif y == room_size.y - 1:
					terrain_manager.set_block_at_world(block_pos, "stone_bricks")
				# Воздух внутри
				else:
					terrain_manager.set_block_at_world(block_pos, "air")
	
	# Сундук с добычей в центре
	var chest_pos = pos + Vector3i(room_size.x / 2, 1, room_size.z / 2)
	terrain_manager.set_block_at_world(chest_pos, "chest")
	
	# Факелы
	terrain_manager.set_block_at_world(pos + Vector3i(1, 1, 1), "torch")
	terrain_manager.set_block_at_world(pos + Vector3i(room_size.x - 2, 1, 1), "torch")
	terrain_manager.set_block_at_world(pos + Vector3i(1, 1, room_size.z - 2), "torch")
	terrain_manager.set_block_at_world(pos + Vector3i(room_size.x - 2, 1, room_size.z - 2), "torch")
