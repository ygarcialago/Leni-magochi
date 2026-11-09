extends Node2D

var speedMovement := 2
var direction := Vector2(1, 0)
var is_chilling := false

var current_pet := 1

var current_release_data: Dictionary = {}


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

	$UpdateChecker.check_for_updates()
	# ========================================
	# Updater checker
	# ========================================
	# ========================================
	# Manifest downloader
	# ========================================
	$ManifestDownloader.manifest_downloaded.connect(_on_manifest_downloaded)
	$ManifestDownloader.download_failed.connect(_on_manifest_download_failed)
	# ========================================
	# Manifest downloader
	# ========================================
	
	# ========================================
	# Update downloader
	# ========================================
	$UpdateDownloader.package_verified.connect(_on_package_verified)
	$UpdateDownloader.download_failed.connect(_on_download_failed)
	# ========================================
	# Update downloader
	# ========================================
	$UpdateChecker.check_for_updates()
	# ========================================
	# Hash verifier
	# ========================================
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


func _on_download_failed(error_message: String) -> void:
	push_error("Error descargando actualización: " + error_message)
