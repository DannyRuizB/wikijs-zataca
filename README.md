# wikijs-zataca

Despliegue auto-hospedado de [Wiki.js](https://js.wiki/) sobre Docker Compose,
pensado para una VM Debian 13 en un entorno de laboratorio o producción interna.

Tres servicios en dos redes:

- **PostgreSQL 17 (alpine)** — base de datos. Red interna `backend`, sin
  puertos expuestos al host.
- **Wiki.js 2.5** — aplicación. Redes `backend` (para hablar con la DB) y
  `frontend` (para que el reverse proxy la alcance).
- **Nginx 1.27 (alpine)** — reverse proxy en `:80`. Único servicio expuesto al
  host, dominio servido: `wikijs.practicas.local`.

Las credenciales sensibles viven en `.env` (excluido por `.gitignore`). Los
datos persistentes están en volúmenes Docker nombrados (`db_data`,
`wiki_data`), de modo que sobreviven a `docker-compose down`.

## Prerrequisitos

- Docker Engine 24+ y Docker Compose v2.
- Una entrada DNS (o `/etc/hosts`) que resuelva `wikijs.practicas.local` a la
  IP del host.

## Quickstart

```bash
git clone https://github.com/DannyRuizB/wikijs-zataca.git
cd wikijs-zataca

# 1) Generar credenciales reales
cp .env.example .env
sed -i "s/changeme/$(openssl rand -hex 16)/" .env
chmod 600 .env

# 2) Levantar el stack
docker-compose up -d

# 3) Abrir el navegador en http://wikijs.practicas.local
#    y completar el wizard de setup de Wiki.js.
```

## Estructura del repo

```
wikijs-zataca/
├── docker-compose.yml      # 3 servicios + redes + volúmenes
├── .env.example            # plantilla de variables (sin secretos)
├── nginx/
│   └── default.conf        # vhost de Nginx que hace proxy_pass a wiki:3000
├── .gitignore
├── LICENSE                 # MIT
└── README.md
```

## Comandos útiles

```bash
# Estado de los contenedores
docker-compose ps

# Logs en vivo de un servicio
docker-compose logs -f wiki

# Reiniciar un servicio sin tocar los demás
docker-compose restart wiki

# Parar el stack conservando datos
docker-compose down

# Borrar también los volúmenes (DESTRUCTIVO: pierde la BD y los uploads)
docker-compose down -v
```

## Reset de la contraseña de admin

Si pierdes la contraseña del usuario administrador, puedes regenerar el hash
desde dentro del contenedor de Wiki.js y aplicarlo a la BD:

```bash
EMAIL="tu.email@example.com"
read -srp "Nueva password: " NEW_PASS; echo

HASH=$(docker exec -e NEW_PASS="$NEW_PASS" wikijs-app \
  node -e 'console.log(require("bcryptjs").hashSync(process.env.NEW_PASS, 12))')

PGPASS=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)

docker exec -e PGPASSWORD="$PGPASS" wikijs-db \
  psql -U wikijs -d wikijs -c \
  "UPDATE users SET password='$HASH' WHERE email='$EMAIL';"
```

## Contexto

Proyecto Final del Módulo 8 de las prácticas FCT en
[Zataca](https://www.zataca.com/) (Elche, curso 2025/2026). La documentación
formal del proyecto vive en un repositorio separado del curso; este repo
contiene únicamente el código necesario para desplegar el stack.

## Licencia

MIT — ver [LICENSE](LICENSE).
