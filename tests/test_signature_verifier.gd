
extends RefCounted

var TEST_MESSAGE := "Tamagochi Ed25519 test".to_utf8_buffer()

# Clave privada de prueba, exclusivamente para tests.
# Nunca utilizar en producción.
const TEST_PRIVATE_SEED_HEX := "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"

const TEST_PUBLIC_KEY_HEX := "03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8"

func run_tests() -> Dictionary:
	var results := {}

	var seed := PackedByteArray()
	for i in range(0, TEST_PRIVATE_SEED_HEX.length(), 2):
		seed.append(TEST_PRIVATE_SEED_HEX.substr(i, 2).hex_to_int())

	var public_key := PackedByteArray()
	for i in range(0, TEST_PUBLIC_KEY_HEX.length(), 2):
		public_key.append(TEST_PUBLIC_KEY_HEX.substr(i, 2).hex_to_int())

	# Generamos una firma de prueba.
	var signature: PackedByteArray = Ed25519.sign(
		TEST_MESSAGE,
		seed,
		public_key
	)

	results["Firma original"] = (
		Ed25519.verify(signature, TEST_MESSAGE, public_key)
	)

	# Modificamos el mensaje.
	var modified_message := TEST_MESSAGE.duplicate()
	modified_message[0] ^= 1

	results["Mensaje modificado rechazado"] = (
		not Ed25519.verify(signature, modified_message, public_key)
	)

	# Modificamos la firma.
	var modified_signature := signature.duplicate()
	modified_signature[0] ^= 1

	results["Firma modificada rechazada"] = (
		not Ed25519.verify(modified_signature, TEST_MESSAGE, public_key)
	)

	return results
