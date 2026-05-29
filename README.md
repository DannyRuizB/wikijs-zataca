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
├── scripts/
│   └── reset-pass.sh       # reset de password del admin (bcrypt + psql)
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

Si pierdes la contraseña del usuario administrador, hay un script que
regenera el hash bcrypt dentro del contenedor de Wiki.js y lo aplica a la BD:

```bash
# Pide email y password por teclado
./scripts/reset-pass.sh

# O pasa el email como argumento
./scripts/reset-pass.sh admin@example.com
```

El script valida que el usuario existe antes de actualizar y exige
confirmación de la nueva password. Debe ejecutarse desde la raíz del repo,
con `wikijs-app` y `wikijs-db` corriendo y un `.env` válido en el directorio.

## Contexto

Proyecto Final del Módulo 8 de las prácticas FCT en
[Zataca](https://www.zataca.com/) (Elche, curso 2025/2026). La documentación
formal del proyecto vive en un repositorio separado del curso; este repo
contiene únicamente el código necesario para desplegar el stack.

## Licencia

MIT — ver [LICENSE](LICENSE).
