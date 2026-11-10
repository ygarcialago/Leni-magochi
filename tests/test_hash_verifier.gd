
extends RefCounted

func run_tests() -> Dictionary:
	var results := {}

	var test_path := "user://test_hash_file.tmp"

	var file := FileAccess.open(test_path, FileAccess.WRITE)

	if file == null:
		results["Creación de archivo temporal"] = false
		return results

	file.store_string("Tamagochi hash test")
	file.close()

	var correct_hash := HashVerifier.calculate_hash(test_path)

	results["Cálculo SHA-256"] = not correct_hash.is_empty()

	results["Hash correcto aceptado"] = (
		HashVerifier.verify_file(test_path, correct_hash)
	)

	results["Hash incorrecto rechazado"] = (
		not HashVerifier.verify_file(test_path, "0".repeat(64))
	)

	results["Archivo inexistente rechazado"] = (
		not HashVerifier.verify_file(
			"user://archivo_que_no_existe.tmp",
			correct_hash
		)
	)

	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(test_path)
	)

	return results
