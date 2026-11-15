
#!/usr/bin/env bash
set -Eeuo pipefail

# Argumentos:
# 1. PID del juego
# 2. Carpeta de instalación
# 3. Carpeta con los archivos nuevos
# 4. Ruta relativa del ejecutable principal

if [[ $# -ne 4 ]]; then
    echo "Uso: installer.sh PID INSTALL_DIR STAGING_DIR EXECUTABLE"
    exit 1
fi

GAME_PID="$1"
INSTALL_DIR="$2"
STAGING_DIR="$3"
EXECUTABLE="$4"

# Comprobar argumentos básicos.
if ! [[ "$GAME_PID" =~ ^[0-9]+$ ]] || [[ "$GAME_PID" -le 1 ]]; then
    echo "PID no válido."
    exit 1
fi

if [[ "$EXECUTABLE" == /* || "$EXECUTABLE" == *".."* ]]; then
    echo "Ruta del ejecutable no válida."
    exit 1
fi

if [[ ! -d "$INSTALL_DIR" || ! -d "$STAGING_DIR" ]]; then
    echo "No existe la carpeta de instalación o staging."
    exit 1
fi

INSTALL_DIR="$(realpath -e -- "$INSTALL_DIR")"
STAGING_DIR="$(realpath -e -- "$STAGING_DIR")"

if [[ "$INSTALL_DIR" == "/" || "$INSTALL_DIR" == "$HOME" ]]; then
    echo "Destino de instalación peligroso."
    exit 1
fi

# Esperar al cierre del juego.
echo "Esperando a que termine Tamagochi..."

while kill -0 "$GAME_PID" 2>/dev/null; do
    sleep 0.5
done

PARENT_DIR="$(dirname "$INSTALL_DIR")"
DIR_NAME="$(basename "$INSTALL_DIR")"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

NEW_DIR="$PARENT_DIR/.${DIR_NAME}_new_${TIMESTAMP}"
BACKUP_DIR="$PARENT_DIR/.${DIR_NAME}_backup_${TIMESTAMP}"

# Preparar la nueva versión en el mismo sistema de archivos.
mkdir -p "$NEW_DIR"

cleanup_on_error() {
    STATUS=$?

    if [[ -d "$BACKUP_DIR" && ! -d "$INSTALL_DIR" ]]; then
        echo "Restaurando copia de seguridad..."
        mv "$BACKUP_DIR" "$INSTALL_DIR"
    fi

    rm -rf "$NEW_DIR"
    exit "$STATUS"
}

trap cleanup_on_error ERR

cp -a "$STAGING_DIR/." "$NEW_DIR/"

if [[ ! -f "$NEW_DIR/$EXECUTABLE" ]]; then
    echo "No se encuentra el ejecutable esperado: $EXECUTABLE"
    exit 1
fi

chmod u+x "$NEW_DIR/$EXECUTABLE"

# Sustituir la instalación.
echo "Creando copia de seguridad..."
mv "$INSTALL_DIR" "$BACKUP_DIR"

echo "Instalando nueva versión..."
mv "$NEW_DIR" "$INSTALL_DIR"

# Comprobar que el ejecutable existe y se puede ejecutar.
if [[ ! -x "$INSTALL_DIR/$EXECUTABLE" ]]; then
    echo "El nuevo ejecutable no está disponible."
    mv "$INSTALL_DIR" "$NEW_DIR"
    mv "$BACKUP_DIR" "$INSTALL_DIR"
    exit 1
fi

trap - ERR

echo "Actualización instalada."
echo "Backup conservado en: $BACKUP_DIR"

# Arrancar la nueva versión.
"$INSTALL_DIR/$EXECUTABLE" >/dev/null 2>&1 &
NEW_PID=$!

sleep 1

if ! kill -0 "$NEW_PID" 2>/dev/null; then
    echo "La nueva versión no ha podido arrancar."
    echo "Se conserva el backup para recuperación manual."
    exit 1
fi

echo "Tamagochi actualizado correctamente."
