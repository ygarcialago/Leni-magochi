
extends RefCounted
class_name SignatureVerifier

const PUBLIC_KEY_HEX := "94bd5b8878be0ad43cca3272c83d4ce31330f18c902279a52638016f8016ac96"

static func verify_manifest(
	manifest_bytes: PackedByteArray,
	signature_bytes: PackedByteArray
) -> bool:

	if manifest_bytes.is_empty():
		push_error("El manifiesto está vacío.")
		return false

	if signature_bytes.size() != 64:
		push_error("La firma no tiene 64 bytes.")
		return false

	if PUBLIC_KEY_HEX.length() != 64:
		push_error("La clave pública no tiene 64 caracteres.")
		return false

	var public_key := PackedByteArray()

	for i in range(0, PUBLIC_KEY_HEX.length(), 2):
		var byte_value := PUBLIC_KEY_HEX.substr(i, 2).hex_to_int()
		public_key.append(byte_value)

	if public_key.size() != 32:
		push_error("La clave pública no tiene 32 bytes.")
		return false

	var is_valid: bool = Ed25519.verify(
		signature_bytes,
		manifest_bytes,
		public_key
	)

	if not is_valid:
		push_error("La firma Ed25519 no es válida.")
		return false

	print("SignatureVerifier: Firma Ed25519 válida.")
	return true
