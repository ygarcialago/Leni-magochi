extends Node
class_name UpdateInstaller

signal installation_started
signal installation_failed(error_message: String)

#const INSTALLER_SOURCE := "res://installer/linux_installer.sh"
const UPDATES_DIR := "user://updates"
const STAGING_DIR := "user://updates/staging"
const INSTALLER_COPY := "user://updates/linux_installer.sh"

var installer_source := OS.get_executable_path().get_base_dir().path_join(
    "linux_installer.sh"
)

func install_update(
	verified_zip_path: String,
	installation_dir: String,
	executable_relative_path: String
) -> bool:

	# No permitir instalar desde el editor.
	if OS.has_feature("editor"):
		return _fail("No se permiten instalaciones desde el editor.")

	if OS.get_name() != "Linux":
		return _fail("Este instalador solo funciona en Linux.")

	if not FileAccess.file_exists(verified_zip_path):
		return _fail("No existe el ZIP de actualización.")

	if executable_relative_path.is_empty():
		return _fail("No se ha indicado el ejecutable principal.")

	if executable_relative_path.begins_with("/"):
		return _fail("La ruta del ejecutable debe ser relativa.")

	if ".." in executable_relative_path:
		return _fail("La ruta del ejecutable no es válida.")

	var install_path := installation_dir.simplify_path()

	if not DirAccess.dir_exists_absolute(install_path):
		return _fail("No existe la carpeta de instalación.")

	# Crear y limpiar staging.
	var updates_absolute := ProjectSettings.globalize_path(UPDATES_DIR)
	var staging_absolute := ProjectSettings.globalize_path(STAGING_DIR)

	if not _remove_directory(staging_absolute):
		return _fail("No se pudo limpiar la carpeta temporal.")

	if DirAccess.make_dir_recursive_absolute(staging_absolute) != OK:
		return _fail("No se pudo crear la carpeta temporal.")

	# Extraer ZIP de forma segura.
	var zip_reader := ZIPReader.new()

	var zip_error := zip_reader.open(verified_zip_path)

	if zip_error != OK:
		return _fail("No se pudo abrir el ZIP.")

	var files := zip_reader.get_files()

	if files.is_empty():
		zip_reader.close()
		return _fail("El ZIP está vacío.")

	for file_name in files:
		var normalized := file_name.replace("\\", "/")

		if normalized.begins_with("/") or ".." in normalized.split("/"):
			zip_reader.close()
			return _fail("El ZIP contiene una ruta no permitida.")

		if normalized.is_empty():
			continue

		var destination := staging_absolute.path_join(normalized)

		if file_name.ends_with("/"):
			if DirAccess.make_dir_recursive_absolute(destination) != OK:
				zip_reader.close()
				return _fail("No se pudo crear un directorio del ZIP.")
			continue

		var parent := destination.get_base_dir()

		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			zip_reader.close()
			return _fail("No se pudo crear un directorio temporal.")

		var content := zip_reader.read_file(file_name)

		if content.is_empty():
			# Los archivos vacíos son válidos.
			pass

		var output := FileAccess.open(destination, FileAccess.WRITE)

		if output == null:
			zip_reader.close()
			return _fail("No se pudo escribir: " + normalized)

		output.store_buffer(content)
		output.close()

	zip_reader.close()

	# Comprobar que el ejecutable está presente.
	var staged_executable := staging_absolute.path_join(
		executable_relative_path
	)

	if not FileAccess.file_exists(staged_executable):
		return _fail("El ZIP no contiene el ejecutable esperado.")

	# Copiar el script externo a user://.
	# var source := FileAccess.open(INSTALLER_SOURCE, FileAccess.READ)
	var source := FileAccess.open(installer_source, FileAccess.READ)

	if source == null:
		return _fail("No se encuentra linux_installer.sh en el proyecto.")

	var installer_content := source.get_as_text()
	source.close()

	var installer_output := FileAccess.open(INSTALLER_COPY, FileAccess.WRITE)

	if installer_output == null:
		return _fail("No se pudo preparar el instalador externo.")

	installer_output.store_string(installer_content)
	installer_output.close()

	# Lanzar el proceso externo.
	var installer_absolute := ProjectSettings.globalize_path(INSTALLER_COPY)

	var pid := OS.create_process(
		"bash",
		[
			installer_absolute,
			str(OS.get_process_id()),
			install_path,
			staging_absolute,
			executable_relative_path
		]
	)

	if pid <= 0:
		return _fail("No se pudo iniciar el instalador externo.")

	installation_started.emit()
	return true


func _remove_directory(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true

	var dir := DirAccess.open(path)

	if dir == null:
		return false

	dir.list_dir_begin()

	var entry := dir.get_next()

	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)

			if dir.current_is_dir():
				if not _remove_directory(child):
					dir.list_dir_end()
					return false
			else:
				if DirAccess.remove_absolute(child) != OK:
					dir.list_dir_end()
					return false

		entry = dir.get_next()

	dir.list_dir_end()

	return DirAccess.remove_absolute(path) == OK


func _fail(message: String) -> bool:
	push_error("UpdateInstaller: " + message)
	installation_failed.emit(message)
	return false
