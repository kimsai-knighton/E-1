extends CharacterBody3D

@export var speed: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var carry_strength: float = 15.0 # Сила, с которой предмет тянется к камере

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

func _unhandled_input(event):
	if note_viewer.visible:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	if event.is_action_pressed("interact"):
		if held_object:
			_drop_object() # Если в руках что-то есть — бросаем
		else:
			_try_interact() # Иначе пытаемся взаимодействовать

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
	# Временно отключаем гравитацию объекта, чтобы его вес не тянул вниз при переноске
	held_object.gravity_scale = 0.0

func _drop_object():
	if held_object:
		# Возвращаем гравитацию
		held_object.gravity_scale = 1.0
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
		
		# Плавно гасим вращение, чтобы предмет не дергался и не крутился в руках
		held_object.angular_velocity = held_object.angular_velocity.lerp(Vector3.ZERO, 0.1)

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
