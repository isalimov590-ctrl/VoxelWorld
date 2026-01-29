extends Resource
class_name Block

## Базовый класс для воксельного блока
## Определяет свойства и поведение блока в игре

## Уникальный идентификатор блока
@export var id: String = ""

## Отображаемое имя блока
@export var display_name: String = ""

## Прочность блока (время разрушения)
@export var hardness: float = 1.0

## Сопротивление взрывам
@export var blast_resistance: float = 1.0

## Является ли блок твердым (коллизия)
@export var is_solid: bool = true

## Является ли блок прозрачным
@export var is_transparent: bool = false

## Можно ли пройти сквозь блок
@export var is_walkthrough: bool = false

## Излучает ли блок свет (0-15)
@export_range(0, 15) var light_level: int = 0

## Путь к текстуре блока
@export var texture_path: String = ""

## Тип инструмента для эффективной добычи
@export_enum("none", "pickaxe", "axe", "shovel", "hoe") var tool_type: String = "none"

## Минимальный уровень инструмента для добычи
@export_range(0, 5) var tool_level: int = 0

## Предмет, который выпадает при разрушении
@export var drop_item: String = ""

## Количество выпадающих предметов
@export var drop_count: int = 1

## Звук при размещении блока
@export var place_sound: String = ""

## Звук при разрушении блока
@export var break_sound: String = ""

## Звук при ходьбе по блоку
@export var step_sound: String = ""

## Можно ли заменить этот блок другим
@export var is_replaceable: bool = false

## Тикает ли блок (для редстоуна и т.д.)
@export var is_tickable: bool = false

## Частота тиков (если тикает)
@export var tick_rate: float = 1.0

## Дополнительные данные блока
var metadata: Dictionary = {}


func _init(block_id: String = "", name: String = "") -> void:
	id = block_id
	display_name = name


## Вызывается при размещении блока
func on_place(world_position: Vector3i, placer) -> void:
	pass


## Вызывается при разрушении блока
func on_break(world_position: Vector3i, breaker) -> void:
	pass


## Вызывается при взаимодействии с блоком
func on_interact(world_position: Vector3i, interactor) -> bool:
	return false


## Вызывается каждый тик (если is_tickable = true)
func on_tick(world_position: Vector3i, delta: float) -> void:
	pass


## Вызывается при обновлении соседнего блока
func on_neighbor_update(world_position: Vector3i, neighbor_position: Vector3i) -> void:
	pass


## Возвращает время разрушения с учетом инструмента
func get_break_time(tool: String, tool_level_value: int) -> float:
	var base_time = hardness
	
	# Если инструмент подходит
	if tool == tool_type and tool_level_value >= tool_level:
		# Эффективная добыча
		base_time *= 0.2
	elif tool_type != "none":
		# Неэффективная добыча
		base_time *= 5.0
	
	return base_time


## Возвращает предмет для выпадения
func get_drop() -> Dictionary:
	if drop_item.is_empty():
		return {"item": id, "count": drop_count}
	else:
		return {"item": drop_item, "count": drop_count}


## Создает копию блока
func duplicate_block() -> Block:
	var new_block = Block.new(id, display_name)
	new_block.hardness = hardness
	new_block.blast_resistance = blast_resistance
	new_block.is_solid = is_solid
	new_block.is_transparent = is_transparent
	new_block.is_walkthrough = is_walkthrough
	new_block.light_level = light_level
	new_block.texture_path = texture_path
	new_block.tool_type = tool_type
	new_block.tool_level = tool_level
	new_block.drop_item = drop_item
	new_block.drop_count = drop_count
	new_block.place_sound = place_sound
	new_block.break_sound = break_sound
	new_block.step_sound = step_sound
	new_block.is_replaceable = is_replaceable
	new_block.is_tickable = is_tickable
	new_block.tick_rate = tick_rate
	new_block.metadata = metadata.duplicate()
	return new_block
