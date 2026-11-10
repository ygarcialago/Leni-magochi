@tool
extends EditorScript

func _initialize() -> void:
	call_deferred("run_all_tests")


func run_all_tests() -> void:
	var total := 0
	var passed := 0
	var failed := 0

	print("\n========== TAMAGOCHI TESTS ==========\n")

	var test_suites := [
		{
			"name": "HashVerifier",
			"script": preload("res://tests/test_hash_verifier.gd")
		},
		{
			"name": "SignatureVerifier",
			"script": preload("res://tests/test_signature_verifier.gd")
		}
	]

	for suite in test_suites:
		print("\n--- ", suite["name"], " ---")

		var instance = suite["script"].new()
		var results: Dictionary = instance.run_tests()

		for test_name in results:
			total += 1

			if results[test_name]:
				passed += 1
				print("[PASS] ", test_name)
			else:
				failed += 1
				print("[FAIL] ", test_name)

	print("\n========== RESULTADO ==========")
	print("Tests: ", total)
	print("Correctos: ", passed)
	print("Fallidos: ", failed)

	if failed == 0:
		print("TODOS LOS TESTS HAN PASADO.")
	else:
		push_error("HAY TESTS FALLIDOS.")

	#quit(0 if failed == 0 else 1)
