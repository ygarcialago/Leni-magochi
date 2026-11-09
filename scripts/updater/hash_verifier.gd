extends RefCounted
class_name HashVerifier


## Comprueba que un archivo coincide con el SHA-256 esperado.
static func verify_file(file_path: String, expected_hash: String) -> bool:

	# Comprobar que existe el archivo.
	if not FileAccess.file_exists(file_path):
		push_error("HashVerifier: El archivo no existe: " + file_path)
		return false

	# Normalizar el hash.
	expected_hash = expected_hash.strip_edges().to_lower()

	# SHA-256 siempre tiene 64 caracteres hexadecimales.
	if expected_hash.length() != 64 or not expected_hash.is_valid_hex_number(false):
		push_error("HashVerifier: El SHA-256 esperado no es válido.")
		return false

	# Calcular el hash real del archivo.
	var calculated_hash := FileAccess.get_sha256(file_path).to_lower()

	if calculated_hash.is_empty():
		push_error("HashVerifier: No se pudo calcular el hash.")
		return false

	# Comparar ambos hashes.
	if calculated_hash == expected_hash:
		print("HashVerifier: Integridad verificada correctamente.")
		return true

	push_error("HashVerifier: ¡El hash no coincide!")
	push_error("Esperado: " + expected_hash)
	push_error("Calculado: " + calculated_hash)

	return false


## Devuelve el SHA-256 calculado de un archivo.
static func calculate_hash(file_path: String) -> String:

	if not FileAccess.file_exists(file_path):
		return ""

	return FileAccess.get_sha256(file_path).to_lower()
