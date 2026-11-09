
extends Node
class_name UpdateChecker

# ==================================================
# CONFIGURACIÓN
# ==================================================

# MODIFICA ESTA URL:
# Sustituye USUARIO y REPOSITORIO por los tuyos.
const LATEST_RELEASE_URL := "https://api.github.com/repos/ygarcialago/Leni-magochi/releases/latest"

# Versión actual de tu Tamagotchi.
# Tendrás que actualizarla cuando publiques una versión nueva.
const CURRENT_VERSION := "0.1.0"

# Tiempo máximo de espera de la petición.
const TIMEOUT := 15.0


# ==================================================
# SEÑALES
# ==================================================

signal check_started
signal update_available(release_data: Dictionary)
signal no_update_available
signal check_failed(error_message: String)


# ==================================================
# VARIABLES
# ==================================================

var http_request: HTTPRequest
var is_checking := false

var latest_version := ""
var latest_release_data: Dictionary = {}


# ==================================================
# INICIALIZACIÓN
# ==================================================

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = TIMEOUT

	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)


# ==================================================
# COMPROBAR ACTUALIZACIONES
# ==================================================

func check_for_updates() -> void:

	if is_checking:
		return

	is_checking = true

	check_started.emit()

	var headers := [
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"User-Agent: Tamagochi-Updater"
	]

	var error := http_request.request(
		LATEST_RELEASE_URL,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		is_checking = false
		check_failed.emit("No se pudo iniciar la petición HTTP: " + str(error))


# ==================================================
# RESPUESTA DE GITHUB
# ==================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	is_checking = false

	if result != HTTPRequest.RESULT_SUCCESS:
		check_failed.emit("Error de conexión con GitHub: " + str(result))
		return

	if response_code != 200:
		check_failed.emit("GitHub respondió con el código HTTP: " + str(response_code))
		return

	var json := JSON.new()

	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		check_failed.emit("No se pudo interpretar la respuesta de GitHub.")
		return

	var data = json.data

	if not data is Dictionary:
		check_failed.emit("La respuesta de GitHub no es válida.")
		return

	latest_release_data = data

	# No permitir actualizaciones desde versiones marcadas como borrador
	# o prerelease.
	if data.get("draft", false) or data.get("prerelease", false):
		check_failed.emit("La publicación no es una versión estable válida.")
		return

	latest_version = str(data.get("tag_name", "")).trim_prefix("v")

	if latest_version.is_empty():
		check_failed.emit("La publicación no contiene un número de versión.")
		return

	_compare_versions()


# ==================================================
# COMPARAR VERSIONES
# ==================================================

func _compare_versions() -> void:

	if _is_newer_version(latest_version, CURRENT_VERSION):
		update_available.emit(latest_release_data)
	else:
		no_update_available.emit()


# ==================================================
# COMPARACIÓN SEMÁNTICA
# ==================================================

func _is_newer_version(remote: String, local: String) -> bool:

	var remote_parts := remote.split(".")
	var local_parts := local.split(".")

	if remote_parts.size() != 3 or local_parts.size() != 3:
		check_failed.emit("Formato de versión incorrecto. Utiliza X.Y.Z.")
		return false

	for i in range(3):

		if not remote_parts[i].is_valid_int() or not local_parts[i].is_valid_int():
			check_failed.emit("Los números de versión no son válidos.")
			return false

		var remote_number := int(remote_parts[i])
		var local_number := int(local_parts[i])

		if remote_number > local_number:
			return true

		if remote_number < local_number:
			return false

	return false


# ==================================================
# INFORMACIÓN DE LA ACTUALIZACIÓN
# ==================================================

func get_latest_version() -> String:
	return latest_version


func get_release_notes() -> String:
	return str(latest_release_data.get("body", ""))


func get_release_url() -> String:
	return str(latest_release_data.get("html_url", ""))


func get_download_assets() -> Array:
	return latest_release_data.get("assets", [])
