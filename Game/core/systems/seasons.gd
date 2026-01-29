extends Node
class_name SeasonSystem

## Система сезонов
## Управляет сменой сезонов и их эффектами

## Сигналы
signal season_changed(new_season: String)
signal day_changed(day: int)

## Текущий сезон
enum Season {
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER
}

var current_season: Season = Season.SPRING

## Длительность сезона в игровых днях
@export var season_length: int = 10

## Текущий день в сезоне
var current_day_in_season: int = 0

## Общий день
var total_days: int = 0

## Время суток (0-24000, где 6000 = полдень, 18000 = полночь)
var time_of_day: float = 0.0

## Скорость времени (1.0 = нормальная)
@export var time_speed: float = 1.0

## Длительность дня в секундах
@export var day_length: float = 1200.0  # 20 минут

## Ссылка на DirectionalLight (солнце)
var sun: DirectionalLight3D = null

## Параметры сезонов
var season_data: Dictionary = {
	Season.SPRING: {
		"name": "Spring",
		"color_tint": Color(0.9, 1.0, 0.9),
		"growth_speed": 1.5,
		"rain_chance": 0.3,
		"temperature": 15.0
	},
	Season.SUMMER: {
		"name": "Summer",
		"color_tint": Color(1.0, 1.0, 0.9),
		"growth_speed": 1.0,
		"rain_chance": 0.1,
		"temperature": 25.0
	},
	Season.AUTUMN: {
		"name": "Autumn",
		"color_tint": Color(1.0, 0.9, 0.8),
		"growth_speed": 0.8,
		"rain_chance": 0.4,
		"temperature": 12.0
	},
	Season.WINTER: {
		"name": "Winter",
		"color_tint": Color(0.9, 0.95, 1.0),
		"growth_speed": 0.2,
		"rain_chance": 0.2,  # Снег
		"temperature": -5.0
	}
}


func _ready() -> void:
	# Находим солнце в сцене
	_find_sun()


func _process(delta: float) -> void:
	# Обновляем время суток
	_update_time_of_day(delta)
	
	# Обновляем освещение
	_update_lighting()


## Находит DirectionalLight в сцене
func _find_sun() -> void:
	var root = get_tree().root
	sun = _find_directional_light(root)
	if sun:
		print("Sun found: ", sun.name)


## Рекурсивно ищет DirectionalLight
func _find_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	
	for child in node.get_children():
		var result = _find_directional_light(child)
		if result:
			return result
	
	return null


## Обновляет время суток
func _update_time_of_day(delta: float) -> void:
	time_of_day += (24000.0 / day_length) * delta * time_speed
	
	# Новый день
	if time_of_day >= 24000.0:
		time_of_day = 0.0
		_advance_day()


## Переходит к следующему дню
func _advance_day() -> void:
	total_days += 1
	current_day_in_season += 1
	
	day_changed.emit(total_days)
	
	# Проверяем смену сезона
	if current_day_in_season >= season_length:
		_change_season()


## Меняет сезон
func _change_season() -> void:
	current_day_in_season = 0
	
	# Следующий сезон
	current_season = (current_season + 1) % 4
	
	season_changed.emit(get_season_name())
	print("Season changed to: ", get_season_name())


## Обновляет освещение
func _update_lighting() -> void:
	if not sun:
		return
	
	# Угол солнца (0-360 градусов)
	var sun_angle = (time_of_day / 24000.0) * 360.0
	
	# Поворачиваем солнце
	sun.rotation_degrees.x = sun_angle - 90.0
	
	# Цвет освещения в зависимости от времени суток
	var light_color = _get_light_color()
	sun.light_color = light_color
	
	# Энергия света (ярче днем, темнее ночью)
	var light_energy = _get_light_energy()
	sun.light_energy = light_energy
	
	# Применяем тонировку сезона
	var season_tint = season_data[current_season]["color_tint"]
	sun.light_color = sun.light_color * season_tint


## Получает цвет света в зависимости от времени
func _get_light_color() -> Color:
	var time_normalized = time_of_day / 24000.0
	
	# Рассвет (0.2-0.3)
	if time_normalized >= 0.2 and time_normalized < 0.3:
		var t = (time_normalized - 0.2) / 0.1
		return Color(1.0, 0.6, 0.4).lerp(Color(1.0, 1.0, 0.95), t)
	
	# День (0.3-0.7)
	elif time_normalized >= 0.3 and time_normalized < 0.7:
		return Color(1.0, 1.0, 0.95)
	
	# Закат (0.7-0.8)
	elif time_normalized >= 0.7 and time_normalized < 0.8:
		var t = (time_normalized - 0.7) / 0.1
		return Color(1.0, 1.0, 0.95).lerp(Color(1.0, 0.5, 0.3), t)
	
	# Ночь
	else:
		return Color(0.4, 0.5, 0.7)


## Получает энергию света
func _get_light_energy() -> float:
	var time_normalized = time_of_day / 24000.0
	
	# День (0.25-0.75)
	if time_normalized >= 0.25 and time_normalized < 0.75:
		return 1.0
	
	# Рассвет/Закат (0.2-0.25 и 0.75-0.8)
	elif (time_normalized >= 0.2 and time_normalized < 0.25) or \
		 (time_normalized >= 0.75 and time_normalized < 0.8):
		if time_normalized < 0.25:
			var t = (time_normalized - 0.2) / 0.05
			return lerp(0.3, 1.0, t)
		else:
			var t = (time_normalized - 0.75) / 0.05
			return lerp(1.0, 0.3, t)
	
	# Ночь
	else:
		return 0.3


## Получает имя текущего сезона
func get_season_name() -> String:
	return season_data[current_season]["name"]


## Получает данные текущего сезона
func get_season_data() -> Dictionary:
	return season_data[current_season]


## Получает скорость роста растений
func get_growth_speed() -> float:
	return season_data[current_season]["growth_speed"]


## Получает шанс дождя/снега
func get_precipitation_chance() -> float:
	return season_data[current_season]["rain_chance"]


## Получает температуру
func get_temperature() -> float:
	return season_data[current_season]["temperature"]


## Проверяет является ли сейчас зима
func is_winter() -> bool:
	return current_season == Season.WINTER


## Проверяет день или ночь
func is_daytime() -> bool:
	var time_normalized = time_of_day / 24000.0
	return time_normalized >= 0.25 and time_normalized < 0.75


## Устанавливает время суток
func set_time(time: float) -> void:
	time_of_day = clamp(time, 0.0, 24000.0)


## Устанавливает сезон
func set_season(season: Season) -> void:
	current_season = season
	current_day_in_season = 0
	season_changed.emit(get_season_name())


## Добавляет дни
func add_days(days: int) -> void:
	for i in range(days):
		_advance_day()


## Сохраняет состояние
func save_state() -> Dictionary:
	return {
		"current_season": current_season,
		"current_day_in_season": current_day_in_season,
		"total_days": total_days,
		"time_of_day": time_of_day
	}


## Загружает состояние
func load_state(data: Dictionary) -> void:
	if data.has("current_season"):
		current_season = data["current_season"]
	if data.has("current_day_in_season"):
		current_day_in_season = data["current_day_in_season"]
	if data.has("total_days"):
		total_days = data["total_days"]
	if data.has("time_of_day"):
		time_of_day = data["time_of_day"]
