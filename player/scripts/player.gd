extends CharacterBody3D

@export var speed: float = 3.0
@export var mouse_sensitivity: float = 0.003

#@onready var footstep_sounds: Array[AudioStream] = [
	#preload("res://global/sfx/1.mp3"),
	#preload("res://global/sfx/2.mp3"),
	#preload("res://global/sfx/3.mp3"),
	#preload("res://global/sfx/4.mp3"),
	#preload("res://global/sfx/5.mp3")
#]

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var counter = 0


@onready var head = $Head
@onready var camera = $Head/Camera
@onready var interact_ray = $Head/Camera/RayCast3D
@onready var note_viewer = $Viewer
@onready var crosshair = $Crosshair

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	# Если открыт просмотрщик записки — игнорируем вращение камеры
	if note_viewer.visible:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	if event.is_action_pressed("interact"):
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
		#if counter == 50:
			#var last_step = -1
			#var new_index = randi() % footstep_sounds.size()
			#
			#if new_index == last_step:
				#new_index = (new_index + 1) % footstep_sounds.size()
		#
			#last_step = new_index
	#
			#play_sound(footstep_sounds[new_index])
			#counter = 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Проверяем прицел каждый физический кадр
	_check_raycast_hover()


func _check_raycast_hover():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		# Проверяем, есть ли у объекта переменная is_interactable или метод interact
		if target and ("is_interactable" in target or target.has_method("interact")):
			crosshair.is_hovering = true
			return
			
	# Если RayCast ни во что не уперся или объект не интерактивен
	crosshair.is_hovering = false

func _try_interact():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target and target.has_method("interact"):
			# Передаем self, чтобы объект мог вызвать методы игрока / UI
			target.interact(self)

# Метод, который вызывается из скрипта записки
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
