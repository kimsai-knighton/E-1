extends Control

@onready var texture_rect = $TextureRect
#@onready var sound = preload("res://global/sfx/paper.mp3")
#@onready var close = preload("res://global/sfx/close_note.mp3")

func _ready():
	hide() # Скрываем при старте игры

func open_note(texture: Texture2D):
	if texture:
		texture_rect.texture = texture
	show()
	var pitch = randf_range(0.9, 1.1)
	#play_sound(sound, pitch)

func close_note():
	hide()
	var pitch = randf_range(0.9, 1.1)
	#play_sound(close, pitch)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Если окно открыто и игрок нажимает "interact", ESC или ЛКМ — закрываем
	if visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
			close_note()
			get_viewport().set_input_as_handled() # Предотвращаем срабатывание клика в игре

func play_sound(stream: AudioStream, pitch) -> void:
	if not stream:
		return
		
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	
	player.finished.connect(player.queue_free)
	
	get_tree().current_scene.add_child(player)
	player.play()
