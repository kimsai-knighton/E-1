extends RigidBody3D
class_name ElectricalComponent

# --- Настройки сетки и размещения ---
@export var grid_size_x: int = 1
@export var grid_size_y: int = 1

# --- Настройки электрической схемы ---
@export_enum("lamp", "battery", "key") var component_type: String = "lamp"
@export var is_on: bool = true # Активно для выключателя/ключа

# Список пинов (контактов)
var pins: Array[Pin] = []

func _ready() -> void:
	# Ищем все дочерние ноды с типом Pin (включая вложенные)
	for child in find_children("*", "Pin", true, false):
		if child is Pin:
			pins.append(child)

## Переключение физики при фиксации на доске
func set_placed_on_board(is_placed: bool) -> void:
	var col_shape = find_child("CollisionShape3D", true, false)
	if is_placed:
		freeze = true # Отключаем физику, чтобы предмет не падал
		if col_shape:
			col_shape.set_deferred("disabled", true)
	else:
		freeze = false
		if col_shape:
			col_shape.set_deferred("disabled", false)

## Получить пин по его имени ("plus", "minus", "in", "out")
func get_pin(p_name: String) -> Pin:
	for p in pins:
		if p.pin_name == p_name:
			return p
	return null

## Возвращает противоположный контакт компонента для проведения тока
func get_other_pin(current_pin: Pin) -> Pin:
	for p in pins:
		if p != current_pin:
			return p
	return null

## Визуальное включение/выключение питания
func set_powered(state: bool) -> void:
	if component_type == "lamp":
		var light = find_child("OmniLight3D", true, false)
		if light:
			light.visible = state
