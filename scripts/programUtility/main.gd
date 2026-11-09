extends Node2D

var speedMovement := 2
var direction := Vector2(1, 0)
var is_chilling := false

var current_pet := 1




func change_pet() -> void:
	#current_pet = 2 if current_pet == 1 else 1
	current_pet += 1
	if current_pet > 3:
		current_pet = 1

	$MedioLimon.visible = current_pet == 1
	$RajaLimon.visible = current_pet == 2
	$LimonEntero.visible = current_pet == 3

func _ready() -> void:
	$RajaLimon.visible = false
	$LimonEntero.visible = false
	var window := get_window()
	
	$UpdateChecker.update_available.connect(_on_update_available)
	$UpdateChecker.no_update_available.connect(_on_no_update)
	$UpdateChecker.check_failed.connect(_on_update_error)

	$UpdateChecker.check_for_updates()

	# Configuración de la ventana
	get_viewport().transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = true
	window.unresizable = false

	# Esperamos a que la ventana termine de inicializarse
	await get_tree().process_frame

	# Colocar el Tamagotchi encima de la barra de tareas
	var usable_screen := DisplayServer.screen_get_usable_rect()

	var target_y := usable_screen.end.y - window.size.y

	window.position = Vector2i(
		usable_screen.position.x,
		target_y
	)

	# Configurar la máscara de ratón
	_update_mouse_mask()

	$MedioLimon.frame_changed.connect(_update_mouse_mask)
	$RajaLimon.frame_changed.connect(_update_mouse_mask)
	$LimonEntero.frame_changed.connect(_update_mouse_mask)

	# Empezar caminando
	get_active_sprite().play("walk")


func _process(_delta: float) -> void:
	# Mientras está chilling no se mueve
	if is_chilling:
		return

	var window := get_window()

	var movement := Vector2i(direction * speedMovement)

	window.position += movement

	var usable_screen := DisplayServer.screen_get_usable_rect()

	# Llegamos al lado derecho
	if window.position.x + window.size.x >= usable_screen.end.x:
		window.position.x = usable_screen.end.x - window.size.x

		direction.x = -1
		$MedioLimon.flip_h = true
		$RajaLimon.flip_h = true
		$LimonEntero.flip_h = true

	# Llegamos al lado izquierdo
	elif window.position.x <= usable_screen.position.x:
		window.position.x = usable_screen.position.x

		direction.x = 1
		$MedioLimon.flip_h = false
		$RajaLimon.flip_h = false
		$LimonEntero.flip_h = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():

		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_chilling:
				start_chilling()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			change_pet()

func get_active_sprite() -> AnimatedSprite2D:
	if current_pet == 1:
		return $MedioLimon
	elif current_pet == 2:
		return $RajaLimon
	else:
		return $LimonEntero

func start_chilling() -> void:
	is_chilling = true

	$MedioLimon.play("idle")
	$RajaLimon.play("idle")
	$LimonEntero.play("idle")

	await get_tree().create_timer(3.0).timeout

	# Por si el Tamagotchi ha sido eliminado mientras esperaba
	if not is_inside_tree():
		return

	is_chilling = false

	$MedioLimon.play("walk")
	$RajaLimon.play("walk")
	$LimonEntero.play("walk")


func _update_mouse_mask() -> void:
	var anim_sprite := get_active_sprite()

	var texture = anim_sprite.sprite_frames.get_frame_texture(
		anim_sprite.animation,
		anim_sprite.frame
	)

	if texture == null:
		return

	var image = texture.get_image()

	if anim_sprite.flip_h:
		image.flip_x()

	var bitmap := BitMap.new()

	bitmap.create_from_image_alpha(image)


func _on_update_available(release_data: Dictionary) -> void:
	print("¡Hay una actualización disponible!")
	print("Versión: ", release_data.get("tag_name", "Desconocida"))
	print("Notas: ", release_data.get("body", "Sin notas"))

	#print("Versión: ", $UpdateChecker.get_latest_version())
	#print("Notas: ", $UpdateChecker.get_release_notes())


func _on_no_update() -> void:
	print("Tu Tamagotchi está actualizado.")


func _on_update_error(error_message: String) -> void:
	print("Error comprobando actualizaciones: ", error_message)
