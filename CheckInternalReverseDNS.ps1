# Función para realizar una búsqueda DNS inversa
function Get-ReverseDNS {
    param (
        [string]$IPAddress
    )
    try {
        $result = [System.Net.Dns]::GetHostEntry($IPAddress)
        return $result.HostName
    }
    catch {
        return $null
    }
}

# Función para validar una dirección IP
function Test-IPAddress {
    param (
        [string]$IPAddress
    )
    return $IPAddress -match "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
}

# Función para validar una máscara de red
function Test-Netmask {
    param (
        [int]$Netmask
    )
    return $Netmask -ge 0 -and $Netmask -le 32
}

# Solicitar al usuario la dirección de red
do {
    $networkAddress = Read-Host "Introduce la dirección de red (por ejemplo, 192.168.1.0)"
} while (-not (Test-IPAddress $networkAddress))

# Solicitar al usuario la máscara de red
do {
    $subnetMask = Read-Host "Introduce la máscara de red en formato CIDR (0-32)"
} while (-not (Test-Netmask $subnetMask))

Write-Host "Analizando la red: $networkAddress/$subnetMask" -ForegroundColor Cyan

# Calcular el rango de direcciones IP a escanear
$networkOctets = $networkAddress.Split('.')
$startIP = [int]$networkOctets[3] + 1
$endIP = [math]::Pow(2, (32 - [int]$subnetMask)) - 2

$totalIPs = $endIP - $startIP + 1
$progress = 0

# Escanear el rango de IPs
$results = @()
for ($i = $startIP; $i -le $endIP; $i++) {
    $currentIP = "$($networkOctets[0]).$($networkOctets[1]).$($networkOctets[2]).$i"
    $progress++
    $percentComplete = [math]::Round(($progress / $totalIPs) * 100, 2)
    Write-Progress -Activity "Escaneando red" -Status "$percentComplete% Completo" -PercentComplete $percentComplete

    if (Test-Connection -ComputerName $currentIP -Count 1 -Quiet) {
        $hostname = Get-ReverseDNS -IPAddress $currentIP
        $results += [PSCustomObject]@{
            IPAddress = $currentIP
            Hostname = if ($hostname) { $hostname } else { "No se pudo resolver" }
            Status = if ($hostname) { "Resuelto" } else { "No resuelto" }
        }
    }
}

Write-Progress -Activity "Escaneando red" -Completed

# Mostrar resultados
Write-Host "`nResultados del escaneo de resolución inversa de DNS:" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Análisis de resultados
$totalDevices = $results.Count
$resolvedDevices = ($results | Where-Object { $_.Status -eq "Resuelto" }).Count
$unresolvedDevices = $totalDevices - $resolvedDevices

Write-Host "`nResumen:" -ForegroundColor Cyan
Write-Host "Total de dispositivos encontrados: $totalDevices" -ForegroundColor Green
Write-Host "Dispositivos con resolución inversa exitosa: $resolvedDevices" -ForegroundColor Green
Write-Host "Dispositivos sin resolución inversa: $unresolvedDevices" -ForegroundColor Yellow

if ($unresolvedDevices -gt 0) {
    $percentageUnresolved = [math]::Round(($unresolvedDevices / $totalDevices) * 100, 2)
    Write-Host "`nProblemas potenciales detectados:" -ForegroundColor Yellow
    Write-Host "- $percentageUnresolved% de los dispositivos no tienen resolución inversa de DNS." -ForegroundColor Yellow
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "1. Falta de registros PTR en el servidor DNS." -ForegroundColor Yellow
    Write-Host "2. Configuración incorrecta de la zona de búsqueda inversa en el servidor DNS." -ForegroundColor Yellow
    Write-Host "3. Los dispositivos no están registrados correctamente en el DNS." -ForegroundColor Yellow
    Write-Host "4. Problemas de propagación de DNS en la red." -ForegroundColor Yellow
    
    Write-Host "`nPasos recomendados:" -ForegroundColor Cyan
    Write-Host "1. Verificar la configuración de la zona de búsqueda inversa en el servidor DNS." -ForegroundColor Cyan
    Write-Host "2. Asegurarse de que el servidor DHCP (si se usa) esté configurado para registrar automáticamente los registros PTR." -ForegroundColor Cyan
    Write-Host "3. Revisar la configuración de DNS en los dispositivos que no se resuelven." -ForegroundColor Cyan
    Write-Host "4. Considerar la actualización manual de registros PTR para dispositivos con IP estática." -ForegroundColor Cyan
    Write-Host "5. Verificar la propagación de DNS en la infraestructura de red." -ForegroundColor Cyan
}
else {
    Write-Host "`nNo se detectaron problemas significativos de resolución inversa de DNS." -ForegroundColor Green
}
