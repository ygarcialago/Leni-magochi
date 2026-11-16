extends Node2D

var speedMovement := 2
var direction := Vector2(1, 0).normalized()
var is_chilling := false
var pet_direction := Vector2(1, 0)
var pet_speed := 120.0

var current_pet := 1

var dragging := false
var drag_offset := Vector2i.ZERO

var resizing := false
var resize_start_mouse := Vector2i.ZERO
var resize_start_position := Vector2i.ZERO
var resize_start_size := Vector2i.ZERO

var resize_direction := Vector2i.ZERO

var resize_margin := 20
const BORDER_SIZE := 12

var min_window_size := Vector2i(300, 200)
var max_window_size := Vector2i(DisplayServer.screen_get_size().x, (DisplayServer.screen_get_size().y / 2))

var current_release_data: Dictionary = {}

var update_installer := UpdateInstaller.new()

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
	
	# ========================================
	# Updater checker
	# ========================================
	$UpdateChecker.update_available.connect(_on_update_available)
	$UpdateChecker.no_update_available.connect(_on_no_update)
	$UpdateChecker.check_failed.connect(_on_update_error)

	#$UpdateChecker.check_for_updates()

	$ManifestDownloader.manifest_downloaded.connect(_on_manifest_downloaded)
	$ManifestDownloader.download_failed.connect(_on_manifest_download_failed)

	$UpdateDownloader.package_verified.connect(_on_package_verified)
	$UpdateDownloader.download_failed.connect(_on_download_failed)
	
	update_installer.installation_started.connect(
		_on_installation_started
	)

	update_installer.installation_failed.connect(
		_on_installation_failed
	)

	$UpdateChecker.check_for_updates()

	var zip_path := "user://Tamagochi-Windows.zip"

	var expected_hash := "27aab77facc7d88b3698d71c29015e9851566e5f2f990dfa921dfcc60aa119c3"

	var real_path := ProjectSettings.globalize_path(zip_path)

	if HashVerifier.verify_file(real_path, expected_hash):
		print("El paquete es seguro para continuar.")
	else:
		print("El paquete ha sido rechazado.")

	# ========================================
	# Hash verifier
	# ========================================ç
	
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


func _process(delta: float) -> void:

	if is_chilling or dragging or resizing:
		return

	var viewport_size := get_viewport_rect().size

	# Usamos el sprite activo para calcular los límites
	var active_pet := get_active_sprite()

	var texture := active_pet.sprite_frames.get_frame_texture(
		active_pet.animation,
		active_pet.frame
	)

	if texture == null:
		return

	var pet_size := texture.get_size()

	# Límites del terrario
	var min_x := pet_size.x / 2.0
	var min_y := pet_size.y / 2.0

	var max_x := viewport_size.x - pet_size.x / 2.0
	var max_y := viewport_size.y - pet_size.y / 2.0

	# Actualizar posición compartida
	active_pet.position += direction * speedMovement * 60.0 * delta

	# Rebote horizontal
	if active_pet.position.x >= max_x:
		active_pet.position.x = max_x
		direction.x = -abs(direction.x)

		active_pet.flip_h = true

	elif active_pet.position.x <= min_x:
		active_pet.position.x = min_x
		direction.x = abs(direction.x)

		active_pet.flip_h = false

	# Rebote vertical
	if active_pet.position.y >= max_y:
		active_pet.position.y = max_y
		direction.y = -abs(direction.y)

	elif active_pet.position.y <= min_y:
		active_pet.position.y = min_y
		direction.y = abs(direction.y)

	# Sincronizar los tres limones
	for pet in [$MedioLimon, $RajaLimon, $LimonEntero]:

		pet.position = active_pet.position
		pet.flip_h = active_pet.flip_h
	_update_mouse_mask()


func _input(event: InputEvent) -> void:
	var window := get_window()

	# =========================================
	# CLICS DEL RATÓN
	# =========================================
	if event is InputEventMouseButton:

		# -------------------------------------
		# BOTÓN IZQUIERDO
		# -------------------------------------
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				var mouse := DisplayServer.mouse_get_position()
				var local_mouse := mouse - window.position

				var direction_resize := get_resize_direction(
					local_mouse,
					window.size
				)

				# REDIMENSIONAR DESDE UN BORDE
				if direction_resize != Vector2i.ZERO:
					resizing = true
					dragging = false

					resize_direction = direction_resize
					resize_start_mouse = mouse
					resize_start_position = window.position
					resize_start_size = window.size

					$WindowHighlight.visible = true

				# MOVER SOLO SI SE PULSA EL LIMÓN
				elif _is_mouse_over_pet(local_mouse):
					dragging = true
					resizing = false

					drag_offset = mouse - window.position

					$WindowHighlight.visible = true

					if not is_chilling:
						start_chilling()

			else:
				# SOLTAR RATÓN
				dragging = false
				resizing = false
				resize_direction = Vector2i.ZERO

				$WindowHighlight.visible = false
				_update_mouse_mask()

		# -------------------------------------
		# BOTÓN DERECHO
		# -------------------------------------
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mouse := DisplayServer.mouse_get_position()
			var local_mouse := mouse - window.position

			if _is_mouse_over_pet(local_mouse):
				change_pet()

	# =========================================
	# MOVIMIENTO DEL RATÓN
	# =========================================
	elif event is InputEventMouseMotion:

		var mouse := DisplayServer.mouse_get_position()

		# -------------------------------------
		# REDIMENSIONAR
		# -------------------------------------
		if resizing:

			var difference := mouse - resize_start_mouse

			var new_size := resize_start_size
			var new_position := resize_start_position

			if resize_direction.x != 0:
				new_size.x += difference.x * resize_direction.x

				if resize_direction.x < 0:
					new_position.x += difference.x

			if resize_direction.y != 0:
				new_size.y += difference.y * resize_direction.y

				if resize_direction.y < 0:
					new_position.y += difference.y

			var clamped_size := Vector2i(
				clampi(new_size.x, min_window_size.x, max_window_size.x),
				clampi(new_size.y, min_window_size.y, max_window_size.y)
			)

			# Mantener fijo el borde opuesto
			if resize_direction.x < 0:
				new_position.x += new_size.x - clamped_size.x

			if resize_direction.y < 0:
				new_position.y += new_size.y - clamped_size.y

			window.size = clamped_size
			window.position = new_position

		# -------------------------------------
		# MOVER VENTANA
		# -------------------------------------
		elif dragging:
			window.position = mouse - drag_offset



func get_resize_direction(
	mouse_position: Vector2i,
	window_size: Vector2i
) -> Vector2i:

	var left := mouse_position.x <= BORDER_SIZE
	var right := mouse_position.x >= window_size.x - BORDER_SIZE

	var top := mouse_position.y <= BORDER_SIZE
	var bottom := mouse_position.y >= window_size.y - BORDER_SIZE

	# No permitir redimensionar desde las esquinas
	if (left or right) and (top or bottom):
		return Vector2i.ZERO

	if left:
		return Vector2i(-1, 0)

	if right:
		return Vector2i(1, 0)

	if top:
		return Vector2i(0, -1)

	if bottom:
		return Vector2i(0, 1)

	return Vector2i.ZERO



func _is_mouse_over_pet(mouse_position: Vector2i) -> bool:

	var pet := get_active_sprite()

	var texture := pet.sprite_frames.get_frame_texture(
		pet.animation,
		pet.frame
	)

	if texture == null:
		return false

	# Convertir la posición del ratón a coordenadas locales
	# del sprite.
	var transform := pet.get_global_transform_with_canvas()
	var local_mouse := transform.affine_inverse() * Vector2(mouse_position)

	var texture_size := texture.get_size()

	var rect_position := pet.offset

	if pet.centered:
		rect_position -= texture_size / 2.0

	var pixel_position := local_mouse - rect_position

	var pixel_x := int(floor(pixel_position.x))
	var pixel_y := int(floor(pixel_position.y))

	if pixel_x < 0 or pixel_x >= texture_size.x:
		return false

	if pixel_y < 0 or pixel_y >= texture_size.y:
		return false

	# Obtener el píxel real de la textura.
	if pet.flip_h:
		pixel_x = int(texture_size.x) - 1 - pixel_x

	var image := texture.get_image()

	return image.get_pixel(pixel_x, pixel_y).a > 0.1



func save_window_settings() -> void:

	var config := ConfigFile.new()

	config.set_value("window", "position", get_window().position)
	config.set_value("window", "size", get_window().size)

	config.save("user://settings.cfg")

func load_window_settings() -> void:

	var config := ConfigFile.new()

	var error := config.load("user://settings.cfg")

	if error != OK:
		return

	var window := get_window()

	window.position = config.get_value(
		"window",
		"position",
		window.position
	)

	window.size = config.get_value(
		"window",
		"size",
		window.size
	)

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
	var window := get_window()

	# Desactivar el passthrough para que Godot
	# pueda recibir los eventos del ratón en toda la ventana.
	# Así podemos detectar los cuatro bordes y el limón.
	window.mouse_passthrough_polygon = PackedVector2Array()

"""
func _get_mouse_polygon(image: Image) -> PackedVector2Array:

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image)

	return bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		1.0
	)[0] if not bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		1.0
	).is_empty() else PackedVector2Array()
"""

func _on_update_available(release_data: Dictionary) -> void:
	print("¡Hay una actualización disponible!")
	# print("Versión: ", release_data.get("tag_name", "Desconocida"))
	# print("Notas: ", release_data.get("body", "Sin notas"))
	current_release_data = release_data
	
	print("Descargando manifiesto...")

	$ManifestDownloader.download_manifest(release_data)

func _on_no_update() -> void:
	print("Tu Tamagotchi está actualizado.")


func _on_update_error(error_message: String) -> void:
	print("Error comprobando actualizaciones: ", error_message)
	
func _on_manifest_downloaded(manifest: Dictionary) -> void:
	print("¡Manifiesto recibido!")
	# print("Versión: ", manifest["version"])
	# print("Canal: ", manifest["channel"])
	# print("Plataformas: ", manifest["platforms"].keys())
	print("Iniciando descarga del paquete...")

	$UpdateDownloader.download_update(manifest, current_release_data)

func _on_manifest_download_failed(error_message: String) -> void:
	push_error("Error descargando manifiesto: " + error_message)
	
func _on_package_verified(file_path: String, platform: String) -> void:
	print("¡Paquete descargado y verificado!")
	print("Plataforma: ", platform)
	print("Archivo: ", file_path)
	var installation_dir := OS.get_executable_path().get_base_dir()

	update_installer.install_update(
		file_path,
		installation_dir,
		"Regalo Helena.x86_64"
		)


func _on_download_failed(error_message: String) -> void:
	push_error("Error descargando actualización: " + error_message)



func _on_installation_started() -> void:
	print("Instalador iniciado. Cerrando Tamagochi...")
	get_tree().quit()


func _on_installation_failed(error_message: String) -> void:
	push_error("Error de instalación: " + error_message)
