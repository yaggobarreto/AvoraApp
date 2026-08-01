# Liga e desliga o ambiente de desenvolvimento do Avora.
#
#   .\scripts\dev.ps1 start   -> Docker + Supabase + app web
#   .\scripts\dev.ps1 stop    -> derruba tudo e devolve a RAM
#   .\scripts\dev.ps1 status  -> o que esta rodando e quanto esta consumindo
#
# O Supabase local segura ~1,2 GB de RAM mesmo parado. Nesta maquina isso faz
# diferenca real, entao vale desligar quando nao estiver programando.

param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'status')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dockerExe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"

function Test-DockerReady {
    try { docker info *> $null; return $? } catch { return $false }
}

function Start-Environment {
    if (-not (Test-DockerReady)) {
        Write-Host 'Iniciando o Docker Desktop...' -ForegroundColor Cyan
        if (-not (Test-Path $dockerExe)) {
            Write-Host "Docker Desktop nao encontrado em $dockerExe" -ForegroundColor Red
            return
        }
        Start-Process $dockerExe
        $waited = 0
        while (-not (Test-DockerReady)) {
            if ($waited -ge 180) {
                Write-Host 'Docker nao subiu em 3 minutos. Abra o Docker Desktop na mao.' -ForegroundColor Red
                return
            }
            Start-Sleep -Seconds 5
            $waited += 5
        }
    }
    Write-Host 'Docker pronto.' -ForegroundColor Green

    Set-Location $projectRoot
    supabase start

    # O runtime das edge functions costuma ficar parado apos um restart do
    # Docker; subir de novo e barato e evita erro de funcao indisponivel.
    docker start supabase_edge_runtime_avora *> $null

    Write-Host ''
    Write-Host 'Supabase no ar. Para abrir o app:' -ForegroundColor Green
    Write-Host '  flutter run -d web-server --web-port 5695 --release --dart-define=SUPABASE_URL=http://192.168.0.180:54321'
}

function Stop-Environment {
    Set-Location $projectRoot

    Get-NetTCPConnection -LocalPort 5695 -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host "Encerrando servidor web (PID $($_.OwningProcess))..." -ForegroundColor Cyan
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        }

    if (Test-DockerReady) {
        Write-Host 'Parando o Supabase...' -ForegroundColor Cyan
        supabase stop
    }

    Write-Host 'Desligando a VM do WSL para devolver a memoria...' -ForegroundColor Cyan
    wsl --shutdown

    Write-Host 'Pronto. Feche o Docker Desktop pela bandeja para liberar o resto.' -ForegroundColor Green
}

function Show-Status {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    Write-Host "RAM: $freeGB GB livres de $totalGB GB" -ForegroundColor Cyan

    if (Test-DockerReady) {
        Write-Host ''
        Write-Host 'Containers no ar:' -ForegroundColor Cyan
        docker ps --format '  {{.Names}}'
    }
    else {
        Write-Host 'Docker parado (nenhum container consumindo memoria).' -ForegroundColor Green
    }

    $web = Get-NetTCPConnection -LocalPort 5695 -State Listen -ErrorAction SilentlyContinue
    if ($web) { Write-Host 'App web rodando em http://localhost:5695' -ForegroundColor Cyan }
}

switch ($Action) {
    'start' { Start-Environment }
    'stop' { Stop-Environment }
    'status' { Show-Status }
}
