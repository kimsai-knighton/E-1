extends Node3D
class_name Pin

@export var pin_name: String = "pin" # Например: "plus", "minus", "in", "out"

# Массив других пинов, к которым мы будем подключать провода
var connected_pins: Array[Pin] = []

# Ссылка на компонент, которому принадлежит этот пин
@onready var component = get_parent()

# Функция для соединения с другим пином (вызовем позже, когда будем тянуть провода)
func connect_to(other_pin: Pin) -> void:
	if not other_pin in connected_pins:
		connected_pins.append(other_pin)
		other_pin.connected_pins.append(self)
		
# Разрыв соединения
func disconnect_from(other_pin: Pin) -> void:
	connected_pins.erase(other_pin)
	other_pin.connected_pins.erase(self)
