#!/usr/bin/env bash
#
# Resetea la contraseña de un usuario de Wiki.js generando el hash bcrypt
# dentro del contenedor de la app y aplicándolo a la BD con psql.
#
# Uso:
#   ./scripts/reset-pass.sh                 # pide email y password interactivamente
#   ./scripts/reset-pass.sh user@dominio    # pide solo la password
#
# Debe ejecutarse desde la raíz del repo, con los contenedores wikijs-app y
# wikijs-db en marcha y un .env válido en el directorio actual.

set -euo pipefail

APP_CONTAINER="wikijs-app"
DB_CONTAINER="wikijs-db"
ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: no se encuentra $ENV_FILE en $(pwd). Ejecuta el script desde la raíz del repo." >&2
  exit 1
fi

for c in "$APP_CONTAINER" "$DB_CONTAINER"; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "ERROR: el contenedor '$c' no está corriendo." >&2
    exit 1
  fi
done

# Email: argumento o prompt
EMAIL="${1:-}"
if [[ -z "$EMAIL" ]]; then
  read -rp "Email del usuario: " EMAIL
fi
if [[ -z "$EMAIL" ]]; then
  echo "ERROR: email vacío." >&2
  exit 1
fi

# Password: siempre interactivo (no se acepta por argumento ni por env para
# evitar que quede en el history o en el process list)
read -rsp "Nueva password: " NEW_PASS; echo
read -rsp "Repite la password: " NEW_PASS2; echo
if [[ "$NEW_PASS" != "$NEW_PASS2" ]]; then
  echo "ERROR: las contraseñas no coinciden." >&2
  exit 1
fi
if [[ ${#NEW_PASS} -lt 8 ]]; then
  echo "ERROR: la password debe tener al menos 8 caracteres (mínimo de Wiki.js)." >&2
  exit 1
fi

# Credenciales de la BD desde .env
PGUSER=$(grep -E '^POSTGRES_USER=' "$ENV_FILE" | cut -d= -f2-)
PGPASS=$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)
PGDB=$(grep -E '^POSTGRES_DB=' "$ENV_FILE" | cut -d= -f2-)
if [[ -z "$PGUSER" || -z "$PGPASS" || -z "$PGDB" ]]; then
  echo "ERROR: faltan POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB en $ENV_FILE." >&2
  exit 1
fi

# Hash bcrypt (rounds=12, mismo coste que usa Wiki.js)
HASH=$(docker exec -e NEW_PASS="$NEW_PASS" "$APP_CONTAINER" \
  node -e 'process.stdout.write(require("bcryptjs").hashSync(process.env.NEW_PASS, 12))')

if [[ -z "$HASH" ]]; then
  echo "ERROR: no se pudo generar el hash bcrypt." >&2
  exit 1
fi

# Verifica que el usuario existe antes de tocar nada
COUNT=$(docker exec -i -e PGPASSWORD="$PGPASS" "$DB_CONTAINER" \
  psql -U "$PGUSER" -d "$PGDB" -t -A -v ON_ERROR_STOP=1 \
  -v email="$EMAIL" <<'SQL'
SELECT count(*) FROM users WHERE email = :'email';
SQL
)
if [[ "$COUNT" -eq 0 ]]; then
  echo "ERROR: no existe ningún usuario con email '$EMAIL'." >&2
  exit 1
fi

# UPDATE — :'var' en psql cita strings de forma segura (los $ del hash bcrypt
# no se expanden porque viajan como variable, no como literal en el SQL).
docker exec -i -e PGPASSWORD="$PGPASS" "$DB_CONTAINER" \
  psql -U "$PGUSER" -d "$PGDB" -v ON_ERROR_STOP=1 -q \
  -v hash="$HASH" -v email="$EMAIL" <<'SQL'
UPDATE users SET password = :'hash' WHERE email = :'email';
SQL

echo "OK: password actualizada para $EMAIL."
