extends StatusIndicator


var tray_supported := false


@onready var menuApp: PopupMenu = $PopupMenu


func _ready() -> void:

	# --------------------------------------------------------
	# Comprobar soporte
	# --------------------------------------------------------

	tray_supported = (
		DisplayServer.has_feature(
			DisplayServer.FEATURE_STATUS_INDICATOR
		)
		and not Engine.is_embedded_in_editor()
	)

	# Ocultar inicialmente
	visible = false

	if not tray_supported:
		return


	# --------------------------------------------------------
	# Evitar que Godot cierre el programa al pulsar X
	# --------------------------------------------------------

	get_tree().auto_accept_quit = false


	# --------------------------------------------------------
	# Configurar icono
	# --------------------------------------------------------

	icon = preload(
		"res://sprites/medio_limon.png"
	)

	tooltip = "Mi Tamagotchi"


	# --------------------------------------------------------
	# Menú
	# --------------------------------------------------------

	menuApp.add_item("Mostrar", 0)
	menuApp.add_item("Ocultar", 1)

	menuApp.add_separator()

	menuApp.add_item("Salir", 2)


	# --------------------------------------------------------
	# Señales
	# --------------------------------------------------------

	menuApp.id_pressed.connect(
		_on_menu_pressed
	)

	pressed.connect(
		_on_tray_pressed
	)


# ============================================================
# CLICK EN ICONO
# ============================================================

func _on_tray_pressed(
	mouse_button: int,
	_position: Vector2i
) -> void:

	if mouse_button == MOUSE_BUTTON_LEFT:

		show_tamagotchi()


# ============================================================
# MENÚ
# ============================================================

func _on_menu_pressed(id: int) -> void:

	match id:

		0:
			show_tamagotchi()

		1:
			hide_tamagotchi()

		2:
			quit_application()


# ============================================================
# MOSTRAR
# ============================================================

func show_tamagotchi() -> void:

	var tamagotchi := get_tree().current_scene

	if tamagotchi.has_method(
		"show_tamagotchi"
	):
		tamagotchi.show_tamagotchi()

	visible = false


# ============================================================
# OCULTAR
# ============================================================

func hide_tamagotchi() -> void:

	var tamagotchi := get_tree().current_scene

	if tamagotchi.has_method(
		"hide_tamagotchi"
	):
		tamagotchi.hide_tamagotchi()

	visible = true


# ============================================================
# SALIR
# ============================================================

func quit_application() -> void:

	get_tree().auto_accept_quit = true

	get_tree().quit()


# ============================================================
# BOTÓN X
# ============================================================

func _notification(what: int) -> void:

	if not tray_supported:
		return


	if what == NOTIFICATION_WM_CLOSE_REQUEST:

		# No cerramos el programa.
		# Ocultamos el Tamagotchi.

		get_tree().current_scene.hide_tamagotchi()

		# Mostrar icono en tray
		visible = true
