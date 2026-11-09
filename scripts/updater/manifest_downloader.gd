
extends Node
class_name ManifestDownloader

const MANIFEST_FILENAME := "manifest.json"
const TIMEOUT := 30.0

signal manifest_downloaded(manifest: Dictionary)
signal download_failed(error_message: String)

var http_request: HTTPRequest
var is_downloading := false


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.timeout = TIMEOUT
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)


## Busca manifest.json entre los assets de una release y lo descarga.
func download_manifest(release_data: Dictionary) -> void:
	if is_downloading:
		return

	var assets = release_data.get("assets", [])

	if not assets is Array:
		download_failed.emit("La release no contiene una lista válida de assets.")
		return

	var manifest_url := ""

	for asset in assets:
		if not asset is Dictionary:
			continue

		if str(asset.get("name", "")) == MANIFEST_FILENAME:
			manifest_url = str(asset.get("browser_download_url", ""))
			break

	if manifest_url.is_empty():
		download_failed.emit("No se encontró manifest.json en la release.")
		return

	if not manifest_url.begins_with("https://"):
		download_failed.emit("La URL del manifiesto no es HTTPS.")
		return

	var headers := PackedStringArray([
		"Accept: application/json",
		"User-Agent: Tamagochi-Updater"
	])

	is_downloading = true

	var error := http_request.request(
		manifest_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		is_downloading = false
		download_failed.emit(
			"No se pudo iniciar la descarga del manifiesto: " + str(error)
		)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	is_downloading = false

	if result != HTTPRequest.RESULT_SUCCESS:
		download_failed.emit(
			"Error de conexión al descargar el manifiesto: " + str(result)
		)
		return

	if response_code != 200:
		download_failed.emit(
			"GitHub respondió con el código HTTP: " + str(response_code)
		)
		return

	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		download_failed.emit("El manifiesto no contiene un JSON válido.")
		return

	if not json.data is Dictionary:
		download_failed.emit("El contenido del manifiesto no es un objeto JSON.")
		return

	var manifest: Dictionary = json.data

	if not _validate_manifest(manifest):
		return

	print("ManifestDownloader: manifiesto descargado correctamente.")
	print("Versión del manifiesto: ", manifest["version"])

	manifest_downloaded.emit(manifest)


## Comprueba que el manifiesto tiene los campos necesarios.
func _validate_manifest(manifest: Dictionary) -> bool:
	var version := str(manifest.get("version", ""))
	var channel := str(manifest.get("channel", ""))
	var platforms = manifest.get("platforms", null)

	if version.is_empty():
		download_failed.emit("El manifiesto no contiene una versión.")
		return false

	if channel.is_empty():
		download_failed.emit("El manifiesto no contiene un canal.")
		return false

	if not platforms is Dictionary or platforms.is_empty():
		download_failed.emit("El manifiesto no contiene plataformas válidas.")
		return false

	for platform in platforms.keys():
		var platform_data = platforms[platform]

		if not platform_data is Dictionary:
			download_failed.emit("Datos inválidos para la plataforma: " + str(platform))
			return false

		var file_name := str(platform_data.get("file", ""))
		var sha256 := str(platform_data.get("sha256", "")).to_lower()

		if file_name.is_empty():
			download_failed.emit("Falta el nombre del ZIP de: " + str(platform))
			return false

		if sha256.length() != 64 or not sha256.is_valid_hex_number(false):
			download_failed.emit("El SHA-256 no es válido para: " + str(platform))
			return false

	return true
