
extends Node
class_name UpdateDownloader

const DOWNLOAD_DIRECTORY := "user://updates/"

signal package_verified(file_path: String, platform: String)
signal download_failed(error_message: String)

var http_request: HTTPRequest
var is_downloading := false

var current_platform := ""
var current_file_path := ""
var expected_hash := ""


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = 120.0
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)


## Identifica la plataforma y descarga el paquete indicado en el manifiesto.
func download_update(manifest: Dictionary, release_data: Dictionary) -> void:
	if is_downloading:
		return

	current_platform = _get_current_platform()

	if current_platform.is_empty():
		download_failed.emit("Sistema operativo no compatible.")
		return

	var platforms = manifest.get("platforms", {})

	if not platforms is Dictionary or not platforms.has(current_platform):
		download_failed.emit(
			"No hay un paquete disponible para: " + current_platform
		)
		return

	var platform_data = platforms[current_platform]

	if not platform_data is Dictionary:
		download_failed.emit("Los datos de la plataforma no son válidos.")
		return

	var file_name := str(platform_data.get("file", ""))
	expected_hash = str(platform_data.get("sha256", "")).strip_edges().to_lower()

	if not _is_valid_file_name(file_name):
		download_failed.emit("El nombre del paquete no es válido.")
		return

	if expected_hash.length() != 64 or not expected_hash.is_valid_hex_number(false):
		download_failed.emit("El SHA-256 del paquete no es válido.")
		return

	var download_url := _find_asset_url(release_data, file_name)

	if download_url.is_empty():
		download_failed.emit(
			"No se encontró el paquete " + file_name + " entre los assets de GitHub."
		)
		return

	if not download_url.begins_with("https://"):
		download_failed.emit("La URL del paquete no utiliza HTTPS.")
		return

	var directory_path := ProjectSettings.globalize_path(DOWNLOAD_DIRECTORY)

	var dir_error := DirAccess.make_dir_recursive_absolute(directory_path)

	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		download_failed.emit("No se pudo crear la carpeta de descargas.")
		return

	current_file_path = DOWNLOAD_DIRECTORY + file_name
	var absolute_file_path := ProjectSettings.globalize_path(current_file_path)

	# Elimina una descarga anterior con el mismo nombre.
	if FileAccess.file_exists(current_file_path):
		var remove_error := DirAccess.remove_absolute(absolute_file_path)

		if remove_error != OK:
			download_failed.emit("No se pudo eliminar el paquete anterior.")
			return

	http_request.download_file = current_file_path
	is_downloading = true

	var headers := PackedStringArray([
		"Accept: application/octet-stream",
		"User-Agent: Tamagochi-Updater"
	])

	var error := http_request.request(
		download_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		is_downloading = false
		http_request.download_file = ""
		_remove_partial_file()
		download_failed.emit(
			"No se pudo iniciar la descarga: " + str(error)
		)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	is_downloading = false
	http_request.download_file = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_remove_partial_file()
		download_failed.emit(
			"Error durante la descarga del paquete: " + str(result)
		)
		return

	if response_code != 200:
		_remove_partial_file()
		download_failed.emit(
			"GitHub respondió con el código HTTP: " + str(response_code)
		)
		return

	var absolute_file_path := ProjectSettings.globalize_path(current_file_path)

	if not FileAccess.file_exists(current_file_path):
		download_failed.emit("No se encuentra el archivo descargado.")
		return

	print("UpdateDownloader: paquete descargado.")
	print("Calculando SHA-256...")

	if not HashVerifier.verify_file(absolute_file_path, expected_hash):
		_remove_partial_file()
		download_failed.emit(
			"El SHA-256 no coincide. El paquete ha sido rechazado."
		)
		return

	print("UpdateDownloader: integridad del paquete verificada.")

	package_verified.emit(current_file_path, current_platform)


## Devuelve la plataforma usando los nombres del manifiesto.
func _get_current_platform() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
		"macOS":
			return "macos"
		_:
			return ""


## Busca la URL de descarga del ZIP entre los assets de la release.
func _find_asset_url(release_data: Dictionary, file_name: String) -> String:
	var assets = release_data.get("assets", [])

	if not assets is Array:
		return ""

	for asset in assets:
		if not asset is Dictionary:
			continue

		if str(asset.get("name", "")) == file_name:
			return str(asset.get("browser_download_url", ""))

	return ""


## Evita nombres de archivo con rutas o extensiones inesperadas.
func _is_valid_file_name(file_name: String) -> bool:
	if file_name.is_empty():
		return false

	if file_name.get_file() != file_name:
		return false

	if not file_name.to_lower().ends_with(".zip"):
		return false

	return true


func _remove_partial_file() -> void:
	if current_file_path.is_empty():
		return

	if FileAccess.file_exists(current_file_path):
		var absolute_path := ProjectSettings.globalize_path(current_file_path)
		DirAccess.remove_absolute(absolute_path)
