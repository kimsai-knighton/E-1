extends StaticBody3D

class_name CircuitBoard

# --- Настройки сетки ---
# Размеры доски в клетках (по вашему запросу)
@export var grid_width: int = 20
@export var grid_height: int = 15

# Физический размер одной клетки в метрах. 
# Вам нужно будет подогнать это значение под размер вашей 3D модели доски.
# Например, если доска шириной 1 метр, то 1.0 / 20 = 0.05
@export var cell_size: float = 0.05 

# --- Внутренние переменные ---
# Двумерный массив для хранения состояния клеток
# Внутри будет либо null (свободно), либо ссылка на размещенный объект (RigidBody3D)
var grid: Array = []

func _ready() -> void:
	# Инициализируем пустую сетку при запуске
	_initialize_grid()

func _initialize_grid() -> void:
	grid.clear()
	for x in range(grid_width):
		var column = []
		for y in range(grid_height):
			column.append(null)
		grid.append(column)

# ---------------------------------------------------------
# ПРЕОБРАЗОВАНИЕ КООРДИНАТ
# ---------------------------------------------------------

## Преобразует глобальную точку попадания луча (от RayCast) в координаты сетки (Vector2i)
func get_grid_pos(global_hit_point: Vector3, size_x: int = 1, size_y: int = 1) -> Vector2i:
	var local_pos = to_local(global_hit_point)
	
	var offset_x = (grid_width * cell_size) / 2.0
	var offset_z = (grid_height * cell_size) / 2.0
	
	var x = floor((local_pos.x + offset_x) / cell_size)
	var y = floor((local_pos.z + offset_z) / cell_size)
	
	# Ограничиваем (clamp) координаты, чтобы предмет никогда не выходил за края сетки.
	# Максимальная позиция — это ширина сетки МИНУС размер самого предмета.
	x = clamp(x, 0, grid_width - size_x)
	y = clamp(y, 0, grid_height - size_y)
	
	return Vector2i(x, y)

## Преобразует позицию на сетке (Vector2i) обратно в локальные 3D координаты доски.
## Используется, чтобы "примагнитить" (снэпнуть) объект точно по центру клетки.
func get_local_pos_from_grid(grid_pos: Vector2i, component_size_x: int = 1, component_size_y: int = 1) -> Vector3:
	var offset_x = (grid_width * cell_size) / 2.0
	var offset_z = (grid_height * cell_size) / 2.0
	
	# Считаем позицию левого верхнего угла объекта
	var base_x = (grid_pos.x * cell_size) - offset_x
	var base_z = (grid_pos.y * cell_size) - offset_z
	
	# Добавляем половину размера объекта, чтобы вернуть его ЦЕНТР
	var center_x = base_x + (component_size_x * cell_size) / 2.0
	var center_z = base_z + (component_size_y * cell_size) / 2.0
	
	# Y = 0 (или небольшое смещение вверх, если пивот объекта внизу)
	# Если предметы проваливаются в доску, можно добавить небольшое смещение, например: 0.01
	return Vector3(center_x, 0, center_z)


# ---------------------------------------------------------
# ЛОГИКА РАЗМЕЩЕНИЯ И ПРОВЕРОК
# ---------------------------------------------------------

## Проверяет, можно ли разместить объект заданного размера (в клетках) в указанной позиции сетки
func can_place(grid_pos: Vector2i, size_x: int, size_y: int) -> bool:
	# 1. Проверка на выход за границы сетки
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false
	if grid_pos.x + size_x > grid_width or grid_pos.y + size_y > grid_height:
		return false
		
	# 2. Проверка на пересечение с уже установленными объектами
	for x in range(size_x):
		for y in range(size_y):
			if grid[grid_pos.x + x][grid_pos.y + y] != null:
				return false # Клетка занята
				
	return true # Все клетки свободны

## Фактическое размещение объекта на сетке (записывает его в массив)
func place_object(item: Node3D, grid_pos: Vector2i, size_x: int, size_y: int) -> void:
	if not can_place(grid_pos, size_x, size_y):
		push_warning("Попытка разместить объект в занятой или недопустимой зоне!")
		return

	# Занимаем клетки ссылкой на объект
	for x in range(size_x):
		for y in range(size_y):
			grid[grid_pos.x + x][grid_pos.y + y] = item
			print("Разместились в ", grid_pos.x + x, ";", grid_pos.y + y)	


## Удаление объекта с сетки (если вы захотите его забрать обратно)
func remove_object(grid_pos: Vector2i, size_x: int, size_y: int) -> void:
	for x in range(size_x):
		for y in range(size_y):
			# Очищаем клетки (проверка границ здесь тоже не помешает для безопасности)
			if grid_pos.x + x < grid_width and grid_pos.y + y < grid_height:
				grid[grid_pos.x + x][grid_pos.y + y] = null


# Список всех установленных на доску объектов
var active_components: Array[ElectricalComponent] = []

# Не забудьте добавлять объект в этот массив внутри вашей функции place_object:
# active_components.append(item)
# И удалять при снятии с доски.

func simulate_circuit() -> void:
	# 1. Сначала "выключаем" все лампы
	for comp in active_components:
		comp.set_powered(false)

	# 2. Ищем батарею на доске
	var battery: ElectricalComponent = null
	for comp in active_components:
		if comp.component_type == "battery":
			battery = comp
			break
			
	if not battery:
		return # Нет источника питания

	# 3. Алгоритм протекания тока
	var visited_pins = []
	var start_pin = battery.get_pin("plus")
	var target_pin = battery.get_pin("minus")
	
	if not start_pin or not target_pin:
		return

	var queue: Array[Pin] = [start_pin]
	var circuit_closed = false
	var found_lamps = [] # Лампы, до которых дошел ток

	while queue.size() > 0:
		var current_pin = queue.pop_front()
		
		if current_pin in visited_pins:
			continue
		visited_pins.append(current_pin)

		# Если мы дошли до минуса батареи — цепь замкнута!
		if current_pin == target_pin:
			circuit_closed = true
			continue

		var comp = current_pin.component

		# Если ток дошел до выключателя, проверяем его состояние
		if comp.component_type == "switch" and not comp.is_on:
			continue # Рубильник выключен, ток дальше не идет

		# Если ток прошел через лампу, запоминаем её
		if comp.component_type == "lamp" and not comp in found_lamps:
			found_lamps.append(comp)

		# Распространяем ток по проводам к другим компонентам
		for connected_pin in current_pin.connected_pins:
			queue.append(connected_pin)

		# Распространяем ток "внутри" самого компонента (от клеммы IN к клеммы OUT)
		# Батарею пропускаем, иначе она замкнет сама себя внутри
		if comp.component_type != "battery":
			var other_pin = comp.get_other_pin(current_pin)
			if other_pin:
				queue.append(other_pin)

	# 4. Если ток нашел путь до "минуса", зажигаем все пройденные лампы
	if circuit_closed:
		for lamp in found_lamps:
			lamp.set_powered(true)
