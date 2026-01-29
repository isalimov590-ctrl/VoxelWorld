extends Node3D
class_name Chunk

## Класс для управления чанком (16x16x16 блоков)
## Отвечает за хранение, генерацию и рендеринг блоков

## Размер чанка по каждой оси
const CHUNK_SIZE: int = 16

## Позиция чанка в мировых координатах чанков
var chunk_position: Vector3i = Vector3i.ZERO

## 3D массив блоков [x][y][z]
var blocks: Array = []

## Меш чанка
var mesh_instance: MeshInstance3D

## Коллизия чанка
var collision_shape: CollisionShape3D
var static_body: StaticBody3D

## Флаг необходимости обновления меша
var needs_mesh_update: bool = true

## Флаг генерации
var is_generated: bool = false

## Флаг загрузки
var is_loaded: bool = false

## Ссылка на менеджер ландшафта
var terrain_manager = null


func _init(pos: Vector3i = Vector3i.ZERO) -> void:
	chunk_position = pos
	name = "Chunk_%d_%d_%d" % [pos.x, pos.y, pos.z]
	_initialize_blocks()


func _ready() -> void:
	_setup_mesh()
	_setup_collision()


## Инициализирует массив блоков
func _initialize_blocks() -> void:
	blocks = []
	for x in range(CHUNK_SIZE):
		blocks.append([])
		for y in range(CHUNK_SIZE):
			blocks[x].append([])
			for z in range(CHUNK_SIZE):
				blocks[x][y].append(null)  # null = воздух


## Настраивает меш инстанс
func _setup_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance"
	add_child(mesh_instance)


## Настраивает коллизию
func _setup_collision() -> void:
	static_body = StaticBody3D.new()
	static_body.name = "StaticBody"
	static_body.collision_layer = 1  # World layer
	static_body.collision_mask = 2   # Player layer
	add_child(static_body)
	
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	static_body.add_child(collision_shape)


## Устанавливает блок в локальных координатах чанка
func set_block(local_pos: Vector3i, block_id: String) -> void:
	if not _is_valid_local_position(local_pos):
		return
	
	blocks[local_pos.x][local_pos.y][local_pos.z] = block_id
	needs_mesh_update = true


## Получает блок по локальным координатам
func get_block(local_pos: Vector3i) -> String:
	if not _is_valid_local_position(local_pos):
		return ""
	
	var block = blocks[local_pos.x][local_pos.y][local_pos.z]
	return block if block != null else ""


## Проверяет валидность локальной позиции
func _is_valid_local_position(pos: Vector3i) -> bool:
	return (pos.x >= 0 and pos.x < CHUNK_SIZE and
			pos.y >= 0 and pos.y < CHUNK_SIZE and
			pos.z >= 0 and pos.z < CHUNK_SIZE)


## Генерирует меш чанка
func generate_mesh() -> void:
	if not needs_mesh_update:
		return
	
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Проходим по всем блокам
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block_id = blocks[x][y][z]
				if block_id == null or block_id == "":
					continue
				
				var local_pos = Vector3i(x, y, z)
				_add_block_faces(surface_tool, local_pos, block_id)
	
	# Создаем меш
	var array_mesh = surface_tool.commit()
	mesh_instance.mesh = array_mesh
	
	# Обновляем коллизию
	_update_collision(array_mesh)
	
	needs_mesh_update = false


## Добавляет грани блока в меш
func _add_block_faces(surface_tool: SurfaceTool, local_pos: Vector3i, block_id: String) -> void:
	var world_pos = Vector3(local_pos.x, local_pos.y, local_pos.z)
	
	# Проверяем каждую грань
	# Верх (+Y)
	if _should_render_face(local_pos + Vector3i.UP):
		_add_face(surface_tool, world_pos, Vector3.UP, block_id)
	
	# Низ (-Y)
	if _should_render_face(local_pos + Vector3i.DOWN):
		_add_face(surface_tool, world_pos, Vector3.DOWN, block_id)
	
	# Право (+X)
	if _should_render_face(local_pos + Vector3i.RIGHT):
		_add_face(surface_tool, world_pos, Vector3.RIGHT, block_id)
	
	# Лево (-X)
	if _should_render_face(local_pos + Vector3i.LEFT):
		_add_face(surface_tool, world_pos, Vector3.LEFT, block_id)
	
	# Вперед (+Z)
	if _should_render_face(local_pos + Vector3i.FORWARD):
		_add_face(surface_tool, world_pos, Vector3.FORWARD, block_id)
	
	# Назад (-Z)
	if _should_render_face(local_pos + Vector3i.BACK):
		_add_face(surface_tool, world_pos, Vector3.BACK, block_id)


## Проверяет нужно ли рендерить грань
func _should_render_face(neighbor_pos: Vector3i) -> bool:
	# Если сосед вне чанка, проверяем соседний чанк
	if not _is_valid_local_position(neighbor_pos):
		return true  # Упрощенно - рендерим грань
	
	# Если соседний блок пустой или прозрачный - рендерим
	var neighbor_block = get_block(neighbor_pos)
	return neighbor_block == "" or neighbor_block == null


## Добавляет одну грань блока
func _add_face(surface_tool: SurfaceTool, pos: Vector3, normal: Vector3, block_id: String) -> void:
	var vertices: Array = []
	var uvs: Array = []
	
	# Определяем вершины в зависимости от направления
	match normal:
		Vector3.UP:
			vertices = [
				pos + Vector3(0, 1, 0),
				pos + Vector3(1, 1, 0),
				pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 1)
			]
		Vector3.DOWN:
			vertices = [
				pos + Vector3(0, 0, 1),
				pos + Vector3(1, 0, 1),
				pos + Vector3(1, 0, 0),
				pos + Vector3(0, 0, 0)
			]
		Vector3.RIGHT:
			vertices = [
				pos + Vector3(1, 0, 0),
				pos + Vector3(1, 0, 1),
				pos + Vector3(1, 1, 1),
				pos + Vector3(1, 1, 0)
			]
		Vector3.LEFT:
			vertices = [
				pos + Vector3(0, 0, 1),
				pos + Vector3(0, 0, 0),
				pos + Vector3(0, 1, 0),
				pos + Vector3(0, 1, 1)
			]
		Vector3.FORWARD:
			vertices = [
				pos + Vector3(0, 0, 1),
				pos + Vector3(1, 0, 1),
				pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 1)
			]
		Vector3.BACK:
			vertices = [
				pos + Vector3(1, 0, 0),
				pos + Vector3(0, 0, 0),
				pos + Vector3(0, 1, 0),
				pos + Vector3(1, 1, 0)
			]
	
	# UV координаты
	uvs = [
		Vector2(0, 1),
		Vector2(1, 1),
		Vector2(1, 0),
		Vector2(0, 0)
	]
	
	# Добавляем два треугольника для квада
	var indices = [0, 1, 2, 0, 2, 3]
	
	for i in indices:
		surface_tool.set_normal(normal)
		surface_tool.set_uv(uvs[i])
		surface_tool.set_color(Color.WHITE)  # Можно использовать для тонирования
		surface_tool.add_vertex(vertices[i])


## Обновляет коллизию чанка
func _update_collision(array_mesh: ArrayMesh) -> void:
	if array_mesh == null:
		return
	
	var shape = array_mesh.create_trimesh_shape()
	if shape != null:
		collision_shape.shape = shape


## Сохраняет чанк в данные
func save_chunk_data() -> Dictionary:
	var data = {
		"position": {"x": chunk_position.x, "y": chunk_position.y, "z": chunk_position.z},
		"blocks": []
	}
	
	# Сохраняем только непустые блоки
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block = blocks[x][y][z]
				if block != null and block != "":
					data["blocks"].append({
						"pos": {"x": x, "y": y, "z": z},
						"id": block
					})
	
	return data


## Загружает чанк из данных
func load_chunk_data(data: Dictionary) -> void:
	if not data.has("blocks"):
		return
	
	_initialize_blocks()
	
	for block_data in data["blocks"]:
		var pos = Vector3i(
			block_data["pos"]["x"],
			block_data["pos"]["y"],
			block_data["pos"]["z"]
		)
		set_block(pos, block_data["id"])
	
	is_loaded = true
	needs_mesh_update = true


## Очищает чанк
func clear() -> void:
	_initialize_blocks()
	needs_mesh_update = true
	is_generated = false
	is_loaded = false


## Освобождает ресурсы
func cleanup() -> void:
	if mesh_instance:
		mesh_instance.queue_free()
	if static_body:
		static_body.queue_free()
	queue_free()
