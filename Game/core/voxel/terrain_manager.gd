extends Node3D
class_name TerrainManager

## Менеджер ландшафта
## Управляет загрузкой, выгрузкой и обновлением чанков

## Размер чанка
const CHUNK_SIZE: int = 16

## Дистанция рендеринга в чанках
@export var render_distance: int = 8

## Дистанция выгрузки чанков
@export var unload_distance: int = 12

## Словарь активных чанков {Vector3i: Chunk}
var active_chunks: Dictionary = {}

## Очередь чанков на генерацию
var generation_queue: Array[Vector3i] = []

## Очередь чанков на обновление меша
var mesh_update_queue: Array[Vector3i] = []

## Ссылка на игрока (для определения позиции)
var player: Node3D = null

## Генератор мира
var world_generator: WorldGenerator = null

## Регистр блоков
var block_registry: Dictionary = {}

## Флаг многопоточной генерации
@export var use_threading: bool = true

## Поток для генерации
var generation_thread: Thread = null
var thread_running: bool = false

## Мьютекс для синхронизации
var mutex: Mutex = Mutex.new()

## Путь для сохранения чанков
var save_path: String = "user://worlds/default/"


func _ready() -> void:
	# Создаем директорию для сохранений
	DirAccess.make_dir_recursive_absolute(save_path)
	
	# Инициализируем регистр блоков
	_initialize_block_registry()
	
	# Создаем генератор мира
	world_generator = WorldGenerator.new(GameManager.world_info.get("seed", 0))
	
	# Запускаем поток генерации если нужно
	if use_threading:
		_start_generation_thread()


func _process(_delta: float) -> void:
	if player == null:
		return
	
	# Обновляем чанки вокруг игрока
	_update_chunks_around_player()
	
	# Обновляем меши чанков
	_process_mesh_updates()


func _exit_tree() -> void:
	# Останавливаем поток
	if use_threading and thread_running:
		thread_running = false
		if generation_thread != null:
			generation_thread.wait_to_finish()
	
	# Сохраняем все чанки
	save_all_chunks()


## Инициализирует регистр блоков
func _initialize_block_registry() -> void:
	# Базовые блоки
	register_block("air", {
		"name": "Air",
		"is_solid": false,
		"is_transparent": true,
		"is_walkthrough": true,
		"is_replaceable": true
	})
	
	register_block("stone", {
		"name": "Stone",
		"hardness": 1.5,
		"tool_type": "pickaxe",
		"tool_level": 0
	})
	
	register_block("dirt", {
		"name": "Dirt",
		"hardness": 0.5,
		"tool_type": "shovel"
	})
	
	register_block("grass", {
		"name": "Grass Block",
		"hardness": 0.6,
		"tool_type": "shovel",
		"drop_item": "dirt"
	})
	
	register_block("wood", {
		"name": "Wood",
		"hardness": 2.0,
		"tool_type": "axe"
	})
	
	register_block("leaves", {
		"name": "Leaves",
		"hardness": 0.2,
		"is_transparent": true
	})
	
	register_block("sand", {
		"name": "Sand",
		"hardness": 0.5,
		"tool_type": "shovel"
	})
	
	register_block("snow", {
		"name": "Snow",
		"hardness": 0.2,
		"tool_type": "shovel"
	})
	
	register_block("water", {
		"name": "Water",
		"hardness": 100.0,
		"is_transparent": true,
		"is_walkthrough": true
	})
	
	register_block("bedrock", {
		"name": "Bedrock",
		"hardness": -1.0
	})
	
	register_block("coal_ore", {
		"name": "Coal Ore",
		"hardness": 3.0,
		"tool_type": "pickaxe",
		"drop_item": "coal"
	})
	
	register_block("iron_ore", {
		"name": "Iron Ore",
		"hardness": 3.0,
		"tool_type": "pickaxe",
		"tool_level": 1
	})
	
	register_block("gold_ore", {
		"name": "Gold Ore",
		"hardness": 3.0,
		"tool_type": "pickaxe",
		"tool_level": 2
	})
	
	register_block("diamond_ore", {
		"name": "Diamond Ore",
		"hardness": 3.0,
		"tool_type": "pickaxe",
		"tool_level": 2,
		"drop_item": "diamond"
	})
	
	register_block("stone_bricks", {
		"name": "Stone Bricks",
		"hardness": 1.5,
		"tool_type": "pickaxe"
	})
	
	register_block("chest", {
		"name": "Chest",
		"hardness": 2.5,
		"tool_type": "axe"
	})
	
	register_block("torch", {
		"name": "Torch",
		"hardness": 0.0,
		"is_transparent": true,
		"light_level": 14
	})


## Регистрирует новый блок
func register_block(block_id: String, properties: Dictionary) -> void:
	var block = Block.new(block_id, properties.get("name", block_id))
	
	# Применяем свойства
	if properties.has("hardness"):
		block.hardness = properties["hardness"]
	if properties.has("blast_resistance"):
		block.blast_resistance = properties["blast_resistance"]
	if properties.has("is_solid"):
		block.is_solid = properties["is_solid"]
	if properties.has("is_transparent"):
		block.is_transparent = properties["is_transparent"]
	if properties.has("is_walkthrough"):
		block.is_walkthrough = properties["is_walkthrough"]
	if properties.has("light_level"):
		block.light_level = properties["light_level"]
	if properties.has("tool_type"):
		block.tool_type = properties["tool_type"]
	if properties.has("tool_level"):
		block.tool_level = properties["tool_level"]
	if properties.has("drop_item"):
		block.drop_item = properties["drop_item"]
	if properties.has("is_replaceable"):
		block.is_replaceable = properties["is_replaceable"]
	
	block_registry[block_id] = block


## Получает блок из регистра
func get_block_definition(block_id: String) -> Block:
	return block_registry.get(block_id, null)


## Обновляет чанки вокруг игрока
func _update_chunks_around_player() -> void:
	var player_chunk_pos = _world_to_chunk_position(player.global_position)
	
	# Загружаем чанки в радиусе рендеринга
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			for y in range(-2, 3):  # Ограниченная высота
				var chunk_pos = player_chunk_pos + Vector3i(x, y, z)
				
				# Проверяем дистанцию
				var distance = player_chunk_pos.distance_to(chunk_pos)
				if distance > render_distance:
					continue
				
				# Если чанк не загружен, добавляем в очередь
				if not active_chunks.has(chunk_pos):
					_request_chunk_generation(chunk_pos)
	
	# Выгружаем далекие чанки
	_unload_distant_chunks(player_chunk_pos)


## Запрашивает генерацию чанка
func _request_chunk_generation(chunk_pos: Vector3i) -> void:
	mutex.lock()
	if not generation_queue.has(chunk_pos):
		generation_queue.append(chunk_pos)
	mutex.unlock()


## Обрабатывает обновления мешей
func _process_mesh_updates() -> void:
	var updates_per_frame = 2  # Ограничиваем количество обновлений за кадр
	
	for i in range(min(updates_per_frame, mesh_update_queue.size())):
		var chunk_pos = mesh_update_queue.pop_front()
		if active_chunks.has(chunk_pos):
			var chunk = active_chunks[chunk_pos]
			chunk.generate_mesh()


## Запускает поток генерации
func _start_generation_thread() -> void:
	thread_running = true
	generation_thread = Thread.new()
	generation_thread.start(_generation_thread_function)


## Функция потока генерации
func _generation_thread_function() -> void:
	while thread_running:
		mutex.lock()
		var has_work = generation_queue.size() > 0
		mutex.unlock()
		
		if has_work:
			mutex.lock()
			var chunk_pos = generation_queue.pop_front()
			mutex.unlock()
			
			# Генерируем чанк
			_generate_chunk(chunk_pos)
		else:
			OS.delay_msec(100)  # Ждем если нет работы


## Генерирует чанк
func _generate_chunk(chunk_pos: Vector3i) -> void:
	# Проверяем есть ли сохраненный чанк
	var loaded_chunk = _load_chunk_from_disk(chunk_pos)
	if loaded_chunk != null:
		call_deferred("_add_chunk_to_scene", loaded_chunk)
		return
	
	# Создаем новый чанк
	var chunk = Chunk.new(chunk_pos)
	chunk.terrain_manager = self
	
	# Генерируем блоки
	if world_generator != null:
		world_generator.generate_chunk(chunk, chunk_pos)
	else:
		_generate_flat_chunk(chunk)
	
	chunk.is_generated = true
	
	# Добавляем в сцену через основной поток
	call_deferred("_add_chunk_to_scene", chunk)


## Добавляет чанк в сцену (вызывается в основном потоке)
func _add_chunk_to_scene(chunk: Chunk) -> void:
	if active_chunks.has(chunk.chunk_position):
		return
	
	active_chunks[chunk.chunk_position] = chunk
	add_child(chunk)
	
	# Устанавливаем позицию
	chunk.global_position = _chunk_to_world_position(chunk.chunk_position)
	
	# Добавляем в очередь обновления меша
	mesh_update_queue.append(chunk.chunk_position)


## Генерирует плоский чанк (для тестирования)
func _generate_flat_chunk(chunk: Chunk) -> void:
	var world_y = chunk.chunk_position.y * CHUNK_SIZE
	
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			# Генерируем простой плоский мир
			if world_y < 0:
				# Под землей - камень
				for y in range(CHUNK_SIZE):
					chunk.set_block(Vector3i(x, y, z), "stone")
			elif world_y == 0:
				# На уровне земли
				for y in range(CHUNK_SIZE):
					var block_y = world_y + y
					if block_y < 0:
						chunk.set_block(Vector3i(x, y, z), "stone")
					elif block_y == 0:
						chunk.set_block(Vector3i(x, y, z), "grass")
					elif block_y < 3:
						chunk.set_block(Vector3i(x, y, z), "dirt")


## Выгружает далекие чанки
func _unload_distant_chunks(player_chunk_pos: Vector3i) -> void:
	var chunks_to_unload: Array[Vector3i] = []
	
	for chunk_pos in active_chunks.keys():
		var distance = player_chunk_pos.distance_to(chunk_pos)
		if distance > unload_distance:
			chunks_to_unload.append(chunk_pos)
	
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)


## Выгружает чанк
func _unload_chunk(chunk_pos: Vector3i) -> void:
	if not active_chunks.has(chunk_pos):
		return
	
	var chunk = active_chunks[chunk_pos]
	
	# Сохраняем чанк
	_save_chunk_to_disk(chunk)
	
	# Удаляем из сцены
	chunk.cleanup()
	active_chunks.erase(chunk_pos)


## Конвертирует мировую позицию в позицию чанка
func _world_to_chunk_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / CHUNK_SIZE),
		floori(world_pos.y / CHUNK_SIZE),
		floori(world_pos.z / CHUNK_SIZE)
	)


## Конвертирует позицию чанка в мировую позицию
func _chunk_to_world_position(chunk_pos: Vector3i) -> Vector3:
	return Vector3(
		chunk_pos.x * CHUNK_SIZE,
		chunk_pos.y * CHUNK_SIZE,
		chunk_pos.z * CHUNK_SIZE
	)


## Сохраняет чанк на диск
func _save_chunk_to_disk(chunk: Chunk) -> void:
	var chunk_data = chunk.save_chunk_data()
	var file_path = save_path + "chunk_%d_%d_%d.json" % [
		chunk.chunk_position.x,
		chunk.chunk_position.y,
		chunk.chunk_position.z
	]
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chunk_data))
		file.close()


## Загружает чанк с диска
func _load_chunk_from_disk(chunk_pos: Vector3i) -> Chunk:
	var file_path = save_path + "chunk_%d_%d_%d.json" % [
		chunk_pos.x,
		chunk_pos.y,
		chunk_pos.z
	]
	
	if not FileAccess.file_exists(file_path):
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return null
	
	var chunk_data = json.get_data()
	var chunk = Chunk.new(chunk_pos)
	chunk.terrain_manager = self
	chunk.load_chunk_data(chunk_data)
	
	return chunk


## Сохраняет все активные чанки
func save_all_chunks() -> void:
	for chunk in active_chunks.values():
		_save_chunk_to_disk(chunk)


## Устанавливает блок в мировых координатах
func set_block_at_world(world_pos: Vector3i, block_id: String) -> void:
	var chunk_pos = _world_to_chunk_position(Vector3(world_pos))
	if not active_chunks.has(chunk_pos):
		return
	
	var chunk = active_chunks[chunk_pos]
	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)
	
	chunk.set_block(local_pos, block_id)
	
	# Добавляем в очередь обновления
	if not mesh_update_queue.has(chunk_pos):
		mesh_update_queue.append(chunk_pos)


## Получает блок в мировых координатах
func get_block_at_world(world_pos: Vector3i) -> String:
	var chunk_pos = _world_to_chunk_position(Vector3(world_pos))
	if not active_chunks.has(chunk_pos):
		return ""
	
	var chunk = active_chunks[chunk_pos]
	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)
	
	return chunk.get_block(local_pos)
