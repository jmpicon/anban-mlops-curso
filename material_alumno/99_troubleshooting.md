# Errores frecuentes y cómo resolverlos

Esta sección recoge los problemas que aparecen casi en cada edición del curso. Si te encuentras con un error que no está aquí, búscalo por palabras clave en este capítulo antes de pedir ayuda. La mayoría de los fallos vienen de cuatro causas:

1. Puertos ocupados por otra cosa en tu máquina.
2. Mezcla de entornos Python (sistema / venv / anaconda).
3. Credenciales o endpoints S3 mal configurados.
4. Confusión entre `localhost` (desde tu PC) y nombres de servicio dentro de Docker.

---

## 1 · Docker no arranca o no responde

### 1.1 `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`

Significa que el motor de Docker no está corriendo.

- **Windows / macOS:** abre Docker Desktop manualmente y espera a que el icono se ponga verde.
- **Linux:**
  ```bash
  sudo systemctl start docker
  sudo systemctl enable docker   # para que arranque al inicio
  ```

### 1.2 `permission denied while trying to connect to the Docker daemon` (Linux)

Tu usuario no está en el grupo `docker`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 1.3 Docker Desktop "Engine stopped" en Windows

Reinicia WSL desde PowerShell:

```powershell
wsl --shutdown
```

Después vuelve a abrir Docker Desktop.

---

## 2 · Puertos ocupados

### 2.1 `bind: address already in use`

Cuando arrancas el stack te dice que un puerto está en uso (5000, 5432, 8888, 9000 o 9001). Algún otro programa ya lo tiene tomado.

**Identifica al culpable:**

- **Linux / macOS:**
  ```bash
  lsof -iTCP:5000 -sTCP:LISTEN
  ```
  o:
  ```bash
  ss -tlnp | grep 5000
  ```

- **Windows (PowerShell):**
  ```powershell
  Get-NetTCPConnection -LocalPort 5000 | Select OwningProcess
  Get-Process -Id <PID>
  ```

**Solución A — para el programa que lo usa.** Por ejemplo, otro proyecto tuyo con el mismo puerto.

**Solución B — cambia el puerto del host en el compose.** Edita `docker/docker-compose.yml` y cambia el lado izquierdo del `:`:

```yaml
mlflow:
  ports:
    - "5050:5000"   # antes "5000:5000"
```

Aplica el cambio sin tocar el resto del stack:

```bash
docker compose up -d mlflow
```

> Cuidado: el lado **izquierdo** es el puerto en tu máquina (host). El **derecho** es el puerto dentro del contenedor y no debe cambiarse — está pegado a la configuración interna del servicio.

### 2.2 Puerto 9000 vs 9001 (MinIO) — error muy frecuente

MinIO expone **dos puertos distintos** y se confunden constantemente:

| Puerto | ¿Qué es?          | ¿Quién lo usa?                      |
|--------|-------------------|-------------------------------------|
| 9000   | API S3 (binaria)  | DVC, MLflow, `boto3`, `mc`          |
| 9001   | Consola web HTML  | Humanos abriendo el navegador       |

Si configuras DVC apuntando a `9001` verás errores `400 Bad Request`. Si abres `9000` en el navegador, verás "XML inválido" o similar — no es para el navegador.

Regla: **DVC y MLflow siempre 9000. Tu navegador siempre 9001.**

---

## 3 · Postgres: "esta página no funciona" en el navegador

Postgres **no es una página web**. No se abre desde el navegador, habla un protocolo binario propio.

Conecta con uno de estos clientes:

- **Línea de comandos:**
  ```bash
  PGPASSWORD=mlflow psql -h localhost -p 5432 -U mlflow -d mlflow
  ```
- **DBeaver** (GUI cross-platform):
  - Host: `localhost` · Port: `5432` · DB: `mlflow` · User: `mlflow` · Pass: `mlflow`.
- **Desde Jupyter:**
  ```python
  import psycopg2
  conn = psycopg2.connect(host="postgres", port=5432, dbname="mlflow", user="mlflow", password="mlflow")
  ```
  > Desde un contenedor, el host se llama `postgres`, no `localhost`.

---

## 4 · `localhost` vs nombres de servicio Docker

| Desde dónde te conectas       | A dónde      | Host a usar    | Puerto          |
|-------------------------------|--------------|----------------|-----------------|
| Tu PC (host)                  | MLflow       | `localhost`    | `5050`          |
| Tu PC (host)                  | MinIO S3     | `localhost`    | `9000`          |
| Tu PC (host)                  | Postgres     | `localhost`    | `5432`          |
| Contenedor (Jupyter, etc.)    | MLflow       | `mlflow`       | `5000` (interno)|
| Contenedor                    | MinIO S3     | `minio`        | `9000`          |
| Contenedor                    | Postgres     | `postgres`     | `5432`          |

Si confundes los dos lados, verás errores del tipo "Connection refused" o "Name or service not known".

---

## 5 · Errores de Python y entornos virtuales

### 5.1 `ModuleNotFoundError: No module named 'X'`

El paquete no está instalado **en el Python que estás usando**. Comprueba qué Python ejecutas:

```bash
which python        # macOS/Linux/WSL
where python        # Windows
```

Y compara con `which dvc` / `which mlflow`. Si están en directorios distintos (típico: `dvc` en anaconda, tu venv en otra parte), tienes mezcla.

**Solución general:** activa el venv y ejecuta el paquete vía Python:

```bash
source .venv/bin/activate
python -m dvc push
```

Si quieres dejarlo bien:

```bash
pip install --force-reinstall dvc dvc-s3
hash -r       # zsh/bash: refresca cache de paths
which dvc     # debe estar dentro del .venv
```

### 5.2 `IndentationError: unexpected indent` en Jupyter

Has copiado código con espacios al principio de línea. Selecciona toda la celda (`Ctrl+A` dentro), pulsa `Shift+Tab` varias veces para sacar la indentación, y vuelve a ejecutar.

### 5.3 Anaconda interfiere con el venv

En el shebang del binario aparece `#!/home/usuario/anaconda3/bin/python` aunque tengas un venv activo. Causa: el comando está en `~/anaconda3/bin/`, que va antes en `$PATH`.

Soluciones:

- **Solución puntual:** `python -m <comando>` para forzar el Python del venv.
- **Solución permanente:** instala el comando dentro del venv (`pip install --force-reinstall <paquete>`) y limpia la caché del shell (`hash -r`).
- **Solución radical:** desactiva el auto-activate de anaconda:
  ```bash
  conda config --set auto_activate_base false
  ```

---

## 6 · DVC: errores frecuentes

### 6.1 `remote 'X' doesn't exist`

Has escrito mal el nombre del remote (típico typo: `nimio` en lugar de `minio`). Comprueba los existentes:

```bash
dvc remote list
```

### 6.2 `requires 'dvc-s3' to be installed`

Falta el plugin S3 para DVC:

```bash
pip install dvc-s3
```

Si dices que ya está instalado pero el error persiste, casi seguro estás ejecutando el `dvc` de otro Python (ver sección 5.3).

### 6.3 `Bad Request (400)` al hacer `dvc push` o `dvc pull`

Tres causas, en orden de probabilidad:

1. **Endpoint apuntando a 9001 en lugar de 9000.** Cámbialo:
   ```bash
   dvc remote modify minio endpointurl http://localhost:9000
   ```
2. **Credenciales mal o ausentes.** Pon las del entorno del curso (no se commitean, van a `.dvc/config.local`):
   ```bash
   dvc remote modify --local minio access_key_id minio
   dvc remote modify --local minio secret_access_key minio12345
   ```
3. **MinIO no está arriba o sin bucket.** Comprueba:
   ```bash
   curl -s http://localhost:9000/minio/health/live -o /dev/null -w "%{http_code}\n"
   ```
   Debe devolver `200`. Y verifica buckets:
   ```bash
   docker exec anban-minio mc alias set local http://localhost:9000 minio minio12345
   docker exec anban-minio mc ls local/
   ```

### 6.4 Tras clonar un repo: `Unable to locate credentials`

`.dvc/config.local` está en `.gitignore` adrede (no se commitean secretos). En el clon nuevo configura las credenciales otra vez:

```bash
dvc remote modify --local minio access_key_id minio
dvc remote modify --local minio secret_access_key minio12345
dvc pull
```

---

## 7 · Jupyter

### 7.1 Pide token al entrar

Es lo normal. Introduce `anban` (el token está configurado en `docker-compose.yml`).

### 7.2 `Server connection closed` o "no se puede conectar"

El contenedor de Jupyter está parado. Comprueba:

```bash
docker compose ps jupyter
docker logs anban-jupyter --tail=30
```

Si está `Exited`, reinícialo:

```bash
docker compose start jupyter
```

### 7.3 Falta un paquete en Jupyter

Instálalo desde una celda:

```python
!pip install psycopg2-binary
```

Esto solo dura mientras el contenedor exista. Para hacerlo permanente, añádelo al `command:` del servicio Jupyter en el `docker-compose.yml`.

---

## 8 · MLflow no responde o se queda colgado

La primera vez tras un `up`, MLflow instala dependencias al arrancar (`psycopg2-binary`, `boto3`). Tarda 30–60 segundos. Mira los logs:

```bash
docker logs anban-mlflow --tail=20 -f
```

Cuando veas `Listening at: http://0.0.0.0:5000`, está listo.

---

## 9 · Comandos universales para diagnosticar

Guárdate estos: resuelven el 80 % de los problemas.

```bash
# ¿Qué contenedores hay y en qué estado?
docker compose ps

# ¿Qué dice el contenedor X?
docker logs <nombre> --tail=50

# ¿Mi puerto está libre? (Linux/macOS)
lsof -iTCP:<puerto> -sTCP:LISTEN

# ¿MinIO API responde?
curl -s http://localhost:9000/minio/health/live -o /dev/null -w "%{http_code}\n"

# Reiniciar un servicio sin tocar el resto
docker compose restart <servicio>

# Empezar de cero (pierdes datos en volúmenes)
docker compose down -v
docker compose up -d
```

---

## 10 · Cuándo pedir ayuda

Antes de levantar la mano en clase o escribir al foro, ten preparado:

1. **Qué intentabas hacer** (paso del lab, comando exacto).
2. **Qué error sale** (copia-pega completo, no resumido).
3. **Qué has comprobado** (al menos `docker compose ps` y los logs del contenedor en cuestión).

Con esos tres datos, el 99 % de los errores se resuelve en un minuto.
