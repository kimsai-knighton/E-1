extends CharacterBody3D

@export var speed: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var carry_strength: float = 15.0 # Сила, с которой предмет тянется к камере

@export var min_hold_distance: float = 0.25   # Минимальное расстояние (самое близкое)
@export var max_hold_distance: float = 1.5   # Максимальное расстояние
@export var scroll_step: float = 0.2         # Шаг изменения дистанции за один тик колесика
var current_hold_distance: float = 0.5       # Текущая дистанция по умолчанию

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var counter = 0

@onready var head = $Head
@onready var camera = $Head/Camera
@onready var interact_ray = $Head/Camera/RayCast3D
@onready var hold_position = $Head/Camera/HoldPosition # Новая точка для удержания
@onready var note_viewer = $Viewer
@onready var crosshair = $Crosshair

var held_object: RigidBody3D = null # Переменная для хранения текущего предмета

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_hold_distance = abs(hold_position.position.z)

func _unhandled_input(event):
	if note_viewer.visible:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	# --- Обработка скролла колесика мыши ---
	if held_object and event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Приближаем объект
			current_hold_distance = clamp(current_hold_distance - scroll_step, min_hold_distance, max_hold_distance)
			hold_position.position.z = -current_hold_distance
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Отдаляем объект
			current_hold_distance = clamp(current_hold_distance + scroll_step, min_hold_distance, max_hold_distance)
			hold_position.position.z = -current_hold_distance

	if event.is_action_pressed("interact"):
		if held_object:
			_drop_object()
		else:
			_try_interact()

func _physics_process(delta):
	if note_viewer.visible:
		velocity.x = 0
		velocity.z = 0
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		counter += 1
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	_process_held_object() # Обрабатываем физику предмета в руках
	_check_raycast_hover()

func _check_raycast_hover():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		# Добавлена проверка на RigidBody3D для отображения прицела
		if target and ("is_interactable" in target or target.has_method("interact") or target is RigidBody3D):
			crosshair.is_hovering = true
			return
			
	crosshair.is_hovering = false

func _try_interact():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		# 1. Проверяем, физический ли это объект
		if target is RigidBody3D:
			_pick_up_object(target)
			return
		
		# 2. Если нет, работает стандартная логика записок/кнопок
		if target and target.has_method("interact"):
			target.interact(self)

func _pick_up_object(target: RigidBody3D):
	held_object = target
	held_object.gravity_scale = 0.0
	held_object.get_node("CollisionShape3D").set_deferred("disabled", true)
	
	# Сброс на дефолтную дистанцию при взятии в руки:
	current_hold_distance = 0.5
	hold_position.position.z = -current_hold_distance
	
func _drop_object():
	if held_object:
		# Возвращаем гравитацию
		held_object.gravity_scale = 1.0
		held_object.get_node("CollisionShape3D").set_deferred("disabled", false)
		held_object = null

func _process_held_object():
	if held_object:
		var target_pos = hold_position.global_position
		var obj_pos = held_object.global_position
		var direction = target_pos - obj_pos
		var distance = direction.length()
		
		# Защита от багов: если предмет застрял за стеной и игрок отошел далеко,
		# связь разрывается, чтобы объект не пролетал сквозь стены на огромной скорости.
		if distance > 3.0:
			_drop_object()
			return
			
		# Придаем объекту скорость в направлении точки HoldPosition
		held_object.linear_velocity = direction * carry_strength
		
		held_object.angular_velocity = Vector3.ZERO
		
		var target_basis = hold_position.global_basis.rotated(
			hold_position.global_basis.x.normalized(), 
			deg_to_rad(30.0)
		)
		
		var current_quat = held_object.global_basis.get_rotation_quaternion()
		var target_quat = target_basis.get_rotation_quaternion()
		held_object.global_basis = Basis(current_quat.slerp(target_quat, 0.2))

func open_note_view(texture: Texture2D):
	note_viewer.open_note(texture)

func play_sound(stream: AudioStream) -> void:
	if not stream:
		return
		
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	get_tree().current_scene.add_child(player)
	player.play()
