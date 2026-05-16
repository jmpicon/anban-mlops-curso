# Empieza aquí

Bienvenido al curso. Esto es lo único que tienes que leer para empezar.

---

## La hoja de ruta del curso, en 8 comandos

Esto es **todo** lo que vas a teclear durante los dos días. Si te
pierdes en cualquier momento, vuelve a esta página.

```bash
# (1) Sólo la primera vez: arrancar el laboratorio
./setup.sh

# (2) DÍA 1 · mañana — DataOps con DVC
cd labs/lab1_dataops && ./run.sh

# (3) DÍA 1 · tarde — Tracking con MLflow
cd ../lab2_mlflow_dvc && ./run.sh

# (4) DÍA 2 · mañana — Servir el modelo (FastAPI + Docker)
cd ../lab3_serving && ./run.sh

# (5) DÍA 2 · tarde — CI/CD y detección de drift
cd ../lab4_cicd_monitoring && ./run.sh

# (6) CIERRE — caso end-to-end y Model Card
cd ../lab5_e2e && ./run.sh

# (7) Al terminar la sesión, parar Docker
cd ../.. && ./shutdown.sh

# (8) Mañana, volver a empezar
./setup.sh
```

Si **algo se rompe**, en cualquier momento:

```bash
./doctor.sh
```

Te dirá qué está mal y cómo arreglarlo.

> **Nota:** en Windows nativo (sin WSL), reemplaza `./setup.sh` por
> `.\setup.ps1` y `./run.sh` por `.\run.ps1`. En todo lo demás, lo
> mismo.

---

## Antes de la hoja de ruta: requisitos

Solo dos cosas:

1. **Docker Desktop** instalado y abierto (la ballena fija en la
   bandeja). Si no lo tienes, ve al apéndice A al final.
2. **Una terminal**. En macOS o Linux, la que viene de serie. En
   Windows, abre **Ubuntu** (WSL) — apéndice B al final.

Nada más. Ni Python, ni Git, ni nada que instalar. Todo va dentro de
Docker.

---

## Paso 0 · Descargar el material

Pide a tu profesor el fichero `Anbam-curso.zip`. Descomprímelo donde
quieras:

- **macOS / Linux / WSL**: en `~/Anbam-curso`.
- **Windows nativo**: en `C:\Anbam-curso`.

Para WSL, si tienes el ZIP en Descargas de Windows:

```bash
cd ~
unzip /mnt/c/Users/$USER/Downloads/Anbam-curso.zip
cd Anbam-curso
```

A partir de aquí, todos los comandos los lanzas desde `Anbam-curso/`.

---

## Paso 1 · `./setup.sh` (1 vez al día, primera vez tarda 5-10 min)

Arranca todo el laboratorio con una sola orden:

```bash
./setup.sh
```

(En Windows nativo: `.\setup.ps1` en PowerShell.)

El script:

1. Comprueba que Docker está abierto y funciona.
2. Descarga las 5 imágenes que necesita el curso (la primera vez
   tarda 5-10 minutos según tu red).
3. Levanta los servicios.
4. Espera a que respondan correctamente.
5. Te muestra los enlaces para abrir en el navegador.

**No cierres la terminal mientras corre. Espera hasta el final.**

Al terminar verás algo como esto:

```
================================================
  LISTO. Abre estos enlaces en tu navegador:
================================================

  Jupyter   : http://localhost:8888   (token: anban)
  MLflow    : http://localhost:5050
  MinIO UI  : http://localhost:9001   (minio / minio12345)
================================================
```

**Antes de seguir, comprueba que los tres URLs abren en tu navegador.**
Si alguno no responde, espera 30 segundos y vuelve a probar. Si sigue
sin ir, ejecuta `./doctor.sh`.

---

## Paso 2 · Los 5 labs, uno detrás de otro

Cada lab tiene su propio `run.sh` que te guía paso a paso. Tú **solo
pulsas Enter** entre paso y paso. Lee lo que sale en pantalla, está
pensado para que entiendas qué pasa.

### Lab 1 — DataOps con DVC (40-50 min)

```bash
cd labs/lab1_dataops
./run.sh
```

Aprendes a versionar datasets, montar un pipeline reproducible y
detectar datos rotos.

### Lab 2 — MLflow Tracking y Registry (50 min)

```bash
cd ../lab2_mlflow_dvc
./run.sh
```

Entrenas tres modelos, los comparas en MLflow y promocionas el mejor a
Staging.

### Lab 3 — Servir el modelo con FastAPI + Docker (40 min)

```bash
cd ../lab3_serving
./run.sh
```

Empaquetas el modelo en una imagen Docker con API REST, validación
Pydantic y `/predict`, `/health`, `/version`, `/metrics`.

### Lab 4 — CI/CD y detección de drift (50 min)

```bash
cd ../lab4_cicd_monitoring
./run.sh
```

Generas drift sintético, mides PSI por feature y pruebas el promote
condicional.

### Lab 5 — Caso end-to-end + Model Card (45 min)

```bash
cd ../lab5_e2e
./run.sh
```

Cierre del curso. Recorre todo el ciclo y genera la Model Card
automática del modelo en Staging.

---

## Paso 3 · Cerrar al final de la sesión

Para parar Docker sin perder ningún dato:

```bash
cd /ruta/a/Anbam-curso
./shutdown.sh
```

Mañana, vuelves a la carpeta y lanzas `./setup.sh`. Todo arranca sin
descargar nada (las imágenes y los datos siguen ahí).

---

## Si algo falla en cualquier punto

```bash
./doctor.sh
```

Diagnóstico automático en 8 bloques. Cada problema viene con su
"arreglo:" explicado. Si después de aplicar el arreglo sigue sin
funcionar, copia la salida de `./doctor.sh` y pide ayuda al profesor.

---

# Apéndice A · Instalar Docker

## macOS

```bash
# si tienes Homebrew:
brew install --cask docker

# si no, descarga de:
# https://www.docker.com/products/docker-desktop/
```

Abre Docker Desktop al menos una vez para que pida permisos. Cuando
veas la ballena fija en la barra superior, está listo.

## Windows

Descarga e instala desde:

`https://www.docker.com/products/docker-desktop/`

Durante la instalación, marca **"Use WSL 2 instead of Hyper-V"**.

Tras instalar, **cierra sesión de Windows y vuelve a entrar** (no hace
falta reiniciar el equipo).

Abre Docker Desktop. La primera vez tarda 1-2 minutos. Cuando la
ballena de la bandeja se queda fija (no animada), está listo.

## Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# cierra y abre la terminal para que el grupo entre en vigor
```

---

# Apéndice B · Instalar WSL en Windows

PowerShell **como administrador**:

```powershell
wsl --install -d Ubuntu
```

Reinicia el equipo cuando lo pida. Tras el reinicio, se abre solo una
ventana de Ubuntu que pide:

- **Nombre de usuario** (en minúsculas, sin acentos, ej. `jose`).
- **Contraseña** (escribes dos veces; no verás los caracteres, es
  normal).

A partir de aquí, abres "Ubuntu" desde el menú Inicio y trabajas como
en Linux.

## Si te da error `0x80370102`

Es que falta activar la virtualización. Pasos:

1. PowerShell **como administrador**:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
2. **Reinicia el equipo** (esta vez sí, reinicio completo).
3. Comprueba en el Administrador de tareas → Rendimiento → CPU que
   "Virtualización" pone "Habilitado". Si pone "Deshabilitado", entra
   en la BIOS (tecla F2/F10/Del según marca al arrancar) y activa
   **Intel VT-x** o **AMD SVM**.

Después, vuelve a ejecutar `wsl --install -d Ubuntu`.

---

# Apéndice C · Conectar Docker Desktop con WSL

Una vez tengas Docker Desktop y WSL instalados, hay que decirle a
Docker que se vea desde Ubuntu:

1. Abre Docker Desktop.
2. Engranaje arriba derecha (Settings) → **Resources** → **WSL
   integration**.
3. Marca **"Enable integration with my default WSL distro"**.
4. En la lista de abajo, activa el switch de **Ubuntu**.
5. **Apply & Restart**.

Comprueba desde Ubuntu:

```bash
docker --version
docker run --rm hello-world
```

Si ves "Hello from Docker!", todo bien.
