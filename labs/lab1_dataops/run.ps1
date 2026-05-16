# run.ps1 — Lab 1 ASISTIDO (Windows PowerShell).

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Banner($t) {
  Write-Host ""
  Write-Host "================================================" -ForegroundColor White
  Write-Host "  $t" -ForegroundColor White
  Write-Host "================================================" -ForegroundColor White
}
function Paso($t)    { Write-Host ""; Write-Host ">>> $t" -ForegroundColor Cyan }
function Explica($t) { Write-Host "    $t" -ForegroundColor DarkGray }
function Run-Cmd {
  $cmd = $args -join ' '
  Write-Host ""
  Write-Host "    `$ $cmd" -ForegroundColor Yellow
  Write-Host ""
  & $args[0] @($args[1..($args.Length - 1)])
  if ($LASTEXITCODE -eq 0) { Write-Host ""; Write-Host "    [OK]" -ForegroundColor Green }
  else { Write-Host ""; Write-Host "    [FALLO]" -ForegroundColor Red; exit 1 }
}
function Pausa { Write-Host ""; Write-Host "    (Enter para continuar)" -ForegroundColor DarkGray; Read-Host | Out-Null }

Banner "LAB 1 - DataOps con DVC"
Write-Host ""
Write-Host "  En este lab vas a:"
Write-Host "    1. Crear un repo git nuevo."
Write-Host "    2. Inicializar DVC dentro del repo."
Write-Host "    3. Trackear un dataset (UCI Adult) con DVC."
Write-Host "    4. Definir un pipeline declarativo."
Write-Host "    5. Ejecutarlo y ver la magia."
Write-Host "    6. Romper los datos a proposito para ver la proteccion."
Pausa

# Paso 0 - limpieza
Paso "Paso 0 - Limpieza previa"
Explica "Si has ejecutado este lab antes, borramos el estado anterior."
$toRemove = @('.dvc', '.dvcignore', 'dvc.lock', 'data')
foreach ($r in $toRemove) {
  if (Test-Path $r) { Remove-Item -Recurse -Force $r }
}
if ((Test-Path '.git') -and (Select-String -Path '.git/config' -Pattern 'lab1_dataops' -Quiet -ErrorAction SilentlyContinue)) {
  Remove-Item -Recurse -Force '.git'
}
New-Item -ItemType Directory -Path "data/raw","data/processed" -Force | Out-Null
Write-Host "    [OK] limpio" -ForegroundColor Green
Pausa

# Paso 1 - dependencias
Paso "Paso 1 - Comprobar DVC y pandas instalados"
$dvc = Get-Command dvc -ErrorAction SilentlyContinue
if (-not $dvc) {
  Write-Host "    DVC no esta instalado. Lo instalo:" -ForegroundColor Yellow
  pip install --quiet "dvc[s3]==3.55.2" pandas pyarrow scikit-learn pyyaml
}
Write-Host "    DVC: $(dvc --version)"
Write-Host "    [OK]" -ForegroundColor Green
Pausa

# Paso 2 - git init
Paso "Paso 2 - Inicializar repositorio Git"
Explica "DVC vive DENTRO de Git. Sin Git no hay DVC."
Run-Cmd git init -q
& git config --local user.email "alumno@anban.es"
& git config --local user.name "Alumno ANBAN"
& git add -A 2>$null | Out-Null
& git commit -q -m "snapshot inicial" 2>$null | Out-Null
Write-Host "    [OK] commit inicial hecho" -ForegroundColor Green
Pausa

# Paso 3 - dvc init
Paso "Paso 3 - Inicializar DVC"
Run-Cmd dvc init -q
& git add .dvc .dvcignore 2>$null | Out-Null
& git commit -q -m "inicializa dvc" 2>$null | Out-Null
Write-Host "    [OK] DVC dentro de Git" -ForegroundColor Green
Pausa

# Paso 4 - remote MinIO
Paso "Paso 4 - Configurar MinIO como remoto de DVC"
Explica "Los CSV pesados NO se guardan en Git, sino en MinIO."
Run-Cmd dvc remote add -d minio s3://datasets/lab1
Run-Cmd dvc remote modify minio endpointurl http://localhost:9000
& dvc remote modify --local minio access_key_id minio | Out-Null
& dvc remote modify --local minio secret_access_key minio12345 | Out-Null
Write-Host "    credenciales en .dvc/config.local (fuera de Git)"
& git add .dvc/config 2>$null | Out-Null
& git commit -q -m "remoto minio configurado" 2>$null | Out-Null
Write-Host "    [OK]" -ForegroundColor Green
Pausa

# Paso 5 - copiar dataset
Paso "Paso 5 - Copiar el dataset UCI Adult"
$src = "..\..\datasets\adult\adult.csv"
if (Test-Path $src) {
  Copy-Item $src "data\raw\adult.csv"
  Write-Host "    Dataset copiado:"
  Get-Item "data\raw\adult.csv" | Format-Table Length, Name -AutoSize
  Write-Host "    [OK]" -ForegroundColor Green
} else {
  Write-Host "    [FALLO] no encuentro $src" -ForegroundColor Red
  exit 1
}
Pausa

# Paso 6 - dvc add
Paso "Paso 6 - dvc add"
Explica "DVC calcula el hash, mueve el fichero a su cache y crea un puntero."
Run-Cmd dvc add data/raw/adult.csv
Write-Host "    Archivos creados:"
Get-ChildItem data\raw | Format-Table Length, Name -AutoSize
& git add data/raw/adult.csv.dvc data/raw/.gitignore 2>$null | Out-Null
& git commit -q -m "trackea dataset" 2>$null | Out-Null
Write-Host "    [OK] dataset trackeado por DVC" -ForegroundColor Green
Pausa

# Paso 7 - dvc push
Paso "Paso 7 - Subir el blob a MinIO (dvc push)"
Run-Cmd dvc push
Write-Host "    Abre http://localhost:9001 y busca el bucket 'datasets'."
Pausa

# Paso 8 - dvc.yaml + repro
Paso "Paso 8 - Ejecutar el pipeline (dvc repro)"
if (-not (Test-Path dvc.yaml)) {
@'
stages:
  validate:
    cmd: python src/ge_validate.py data/raw/adult.csv
    deps:
      - data/raw/adult.csv
      - src/ge_validate.py
  preprocess:
    cmd: python src/preprocess.py
    deps:
      - data/raw/adult.csv
      - src/preprocess.py
      - params.yaml
    outs:
      - data/processed/train.parquet
      - data/processed/test.parquet
'@ | Out-File -Encoding utf8 dvc.yaml
}
if (-not (Test-Path params.yaml)) {
@'
preprocess:
  test_size: 0.2
  random_state: 42
  drop_columns: ["fnlwgt", "education"]
'@ | Out-File -Encoding utf8 params.yaml
}
Run-Cmd dvc repro
Write-Host "    Generados en data\processed:"
Get-ChildItem data\processed | Format-Table Length, Name -AutoSize
Pausa

# Paso 9 - repro sin cambios
Paso "Paso 9 - Volver a ejecutar dvc repro"
Explica "Esta vez DVC debe decir 'didn't change, skipping'."
Run-Cmd dvc repro
Pausa

# Paso 10 - romper dato
Paso "Paso 10 - Romper el dato a proposito"
$lines = Get-Content data\raw\adult.csv
$parts = $lines[4].Split(',')
$parts[0] = '200'
$lines[4] = ($parts -join ',')
$lines | Set-Content data\raw\adult.csv
Write-Host "    Linea 5 modificada: age=200"
Write-Host ""
Write-Host "    `$ python src/ge_validate.py data/raw/adult.csv" -ForegroundColor Yellow
Write-Host ""
& python src/ge_validate.py data/raw/adult.csv
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "    [OK] La validacion detecto el age fuera de rango." -ForegroundColor Green
} else {
  Write-Host "    [!] La validacion NO fallo. Raro." -ForegroundColor Yellow
}
Pausa

# Paso 11 - recuperar
Paso "Paso 11 - Recuperar el dato bueno"
Run-Cmd Copy-Item ..\..\datasets\adult\adult.csv data\raw\adult.csv -Force
Run-Cmd dvc add data/raw/adult.csv
& git add data/raw/adult.csv.dvc 2>$null | Out-Null
& git commit -q -m "restaura dataset" 2>$null | Out-Null
Run-Cmd dvc repro
Pausa

Banner "LAB 1 COMPLETO"
Write-Host ""
Write-Host "  Has hecho:" -ForegroundColor Green
Write-Host "    [OK] Git + DVC inicializados"
Write-Host "    [OK] Dataset trackeado por DVC y subido a MinIO"
Write-Host "    [OK] Pipeline declarativo funcionando"
Write-Host "    [OK] Vivido el caso de datos rotos"
Write-Host ""
Write-Host "  Cuando estes listo, ve al Lab 2:"
Write-Host "      cd ..\lab2_mlflow_dvc"
Write-Host "      .\run.ps1"
Write-Host ""
