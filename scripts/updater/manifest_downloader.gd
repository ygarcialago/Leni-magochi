
extends Node
class_name ManifestDownloader

const MANIFEST_FILENAME := "manifest.json"
const SIGNATURE_FILENAME := "manifest.json.sig"
const TIMEOUT := 30.0

signal manifest_downloaded(manifest: Dictionary)
signal download_failed(error_message: String)

var manifest_request: HTTPRequest
var signature_request: HTTPRequest

var is_downloading := false
var manifest_bytes := PackedByteArray()


func _ready() -> void:
	# Petición para descargar el manifiesto.
	manifest_request = HTTPRequest.new()
	manifest_request.timeout = TIMEOUT
	add_child(manifest_request)
	manifest_request.request_completed.connect(
		_on_manifest_request_completed
	)

	# Petición independiente para descargar la firma.
	signature_request = HTTPRequest.new()
	signature_request.timeout = TIMEOUT
	add_child(signature_request)
	signature_request.request_completed.connect(
		_on_signature_request_completed
	)


## Busca los dos archivos en los assets de GitHub.
func download_manifest(release_data: Dictionary) -> void:
	if is_downloading:
		return
	
	current_release_data = release_data

	var manifest_url := _find_asset_url(
		release_data,
		MANIFEST_FILENAME
	)

	var signature_url := _find_asset_url(
		release_data,
		SIGNATURE_FILENAME
	)

	if manifest_url.is_empty():
		download_failed.emit(
            "No se encontró manifest.json en la release."
		)
		return

	if signature_url.is_empty():
		download_failed.emit(
            "No se encontró manifest.json.sig en la release."
		)
		return

	if not manifest_url.begins_with("https://"):
		download_failed.emit(
            "La URL del manifiesto no es HTTPS."
		)
		return

	if not signature_url.begins_with("https://"):
		download_failed.emit(
            "La URL de la firma no es HTTPS."
		)
		return

	manifest_bytes.clear()
	is_downloading = true

	print("ManifestDownloader: descargando manifiesto...")

	var headers := PackedStringArray([
		"Accept: application/octet-stream",
        "User-Agent: Tamagochi-Updater"
	])

	var error := manifest_request.request(
		manifest_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_fail(
            "No se pudo iniciar la descarga del manifiesto: "
			+ str(error)
		)


## Recibe el manifiesto sin interpretarlo todavía.
func _on_manifest_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(
			"Error descargando el manifiesto: " + str(result)
		)
		return

	if response_code != 200:
		_fail(
            "GitHub respondió al manifiesto con HTTP "
			+ str(response_code)
		)
		return

	if body.is_empty():
		_fail("El manifiesto descargado está vacío.")
		return

	# Guardamos los bytes originales.
	# No debemos modificar ni reinterpretar el JSON antes de verificarlo.
	manifest_bytes = body

	print("ManifestDownloader: manifiesto descargado.")
	print("Descargando firma Ed25519...")

	# Descargamos ahora la firma.
	# La URL se obtuvo previamente de los assets de la release.
	# Volvemos a buscarla en los datos de la release almacenados.
	# La guardamos en una variable de instancia para la siguiente petición.
	_request_signature()


var current_release_data: Dictionary = {}


func _request_signature() -> void:
	var signature_url := _find_asset_url(
		current_release_data,
		SIGNATURE_FILENAME
	)

	if signature_url.is_empty():
		_fail("No se encuentra la URL de la firma.")
		return

	var headers := PackedStringArray([
		"Accept: application/octet-stream",
        "User-Agent: Tamagochi-Updater"
	])

	var error := signature_request.request(
		signature_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_fail(
            "No se pudo iniciar la descarga de la firma: "
			+ str(error)
		)


## Recibe la firma y verifica su autenticidad.
func _on_signature_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	signature_bytes: PackedByteArray
) -> void:

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(
			"Error descargando la firma: " + str(result)
		)
		return

	if response_code != 200:
		_fail(
            "GitHub respondió a la firma con HTTP "
			+ str(response_code)
		)
		return

	if signature_bytes.size() != 64:
		_fail("La firma descargada no tiene 64 bytes.")
		return

	print("ManifestDownloader: verificando firma Ed25519...")

	# Verificación con la clave pública integrada en Godot.
	if not SignatureVerifier.verify_manifest(
		manifest_bytes,
		signature_bytes
	):
		_fail(
            "La firma del manifiesto no es válida. "
			+ "Actualización rechazada."
		)
		return

	print("ManifestDownloader: firma auténtica.")

	# SOLO después de verificar la firma interpretamos el JSON.
	_process_verified_manifest()


## Interpreta y valida el manifiesto ya autenticado.
func _process_verified_manifest() -> void:
	var json := JSON.new()

	var parse_error := json.parse(
		manifest_bytes.get_string_from_utf8()
	)

	if parse_error != OK:
		_fail("El manifiesto firmado no contiene un JSON válido.")
		return

	if not json.data is Dictionary:
		_fail(
            "El contenido del manifiesto no es un objeto JSON."
		)
		return

	var manifest: Dictionary = json.data

	if not _validate_manifest(manifest):
		is_downloading = false
		return

	is_downloading = false

	print("ManifestDownloader: manifiesto autenticado y validado.")
	print("Versión: ", manifest["version"])

	manifest_downloaded.emit(manifest)


## Comprueba que el manifiesto tiene los campos necesarios.
func _validate_manifest(manifest: Dictionary) -> bool:
	var version := str(manifest.get("version", ""))
	var channel := str(manifest.get("channel", ""))
	var platforms = manifest.get("platforms", null)

	if version.is_empty():
		download_failed.emit(
            "El manifiesto no contiene una versión."
		)
		return false

	if channel.is_empty():
		download_failed.emit(
            "El manifiesto no contiene un canal."
		)
		return false

	if not platforms is Dictionary or platforms.is_empty():
		download_failed.emit(
            "El manifiesto no contiene plataformas válidas."
		)
		return false

	for platform in platforms.keys():
		var platform_data = platforms[platform]

		if not platform_data is Dictionary:
			download_failed.emit(
                "Datos inválidos para la plataforma: "
				+ str(platform)
			)
			return false

		var file_name := str(platform_data.get("file", ""))
		var sha256 := str(
			platform_data.get("sha256", "")
		).to_lower()

		if file_name.is_empty():
			download_failed.emit(
                "Falta el nombre del ZIP de: "
				+ str(platform)
			)
			return false

		if sha256.length() != 64 or not sha256.is_valid_hex_number(false):
			download_failed.emit(
                "El SHA-256 no es válido para: "
				+ str(platform)
			)
			return false

	return true


## Busca un asset por nombre.
func _find_asset_url(
	release_data: Dictionary,
	file_name: String
) -> String:

	var assets = release_data.get("assets", [])

	if not assets is Array:
		return ""

	for asset in assets:
		if not asset is Dictionary:
			continue

		if str(asset.get("name", "")) == file_name:
			return str(
				asset.get("browser_download_url", "")
			)

	return ""


## Detiene el proceso ante cualquier error.
func _fail(error_message: String) -> void:
	is_downloading = false
	manifest_bytes.clear()

	push_error("ManifestDownloader: " + error_message)
	download_failed.emit(error_message)
