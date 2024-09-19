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

# Función para obtener el rango de IP de la subred local
function Get-LocalSubnetRange {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    $ip = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
    $network = $ip.IPAddress -replace "\.\d+$", ".0"
    $mask = $ip.PrefixLength
    return @{
        Network = $network
        Mask = $mask
    }
}

# Obtener el rango de la subred local
$subnetInfo = Get-LocalSubnetRange
$network = $subnetInfo.Network
$mask = $subnetInfo.Mask

Write-Host "Analizando la red $network/$mask" -ForegroundColor Cyan

# Calcular el rango de direcciones IP a escanear
$networkOctets = $network.Split('.')
$startIP = [int]$networkOctets[3] + 1
$endIP = [math]::Pow(2, (32 - $mask)) - 2

$totalIPs = $endIP - $startIP + 1
$progress = 0

# Escanear el rango de IPs
$results = @()
for ($i = $startIP; $i -le $endIP; $i++) {
    $currentIP = "$($networkOctets[0]).$($networkOctets[1]).$($networkOctets[2]).$i"
    $progress++
    $percentComplete = [math]::Round(($progress / $totalIPs) * 100, 2)
    Write-Progress -Activity "Escaneando red interna" -Status "$percentComplete% Completo" -PercentComplete $percentComplete

    if (Test-Connection -ComputerName $currentIP -Count 1 -Quiet) {
        $hostname = Get-ReverseDNS -IPAddress $currentIP
        $results += [PSCustomObject]@{
            IPAddress = $currentIP
            Hostname = if ($hostname) { $hostname } else { "No se pudo resolver" }
            Status = if ($hostname) { "Resuelto" } else { "No resuelto" }
        }
    }
}

Write-Progress -Activity "Escaneando red interna" -Completed

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
    Write-Host "1. Falta de registros PTR en el servidor DNS interno." -ForegroundColor Yellow
    Write-Host "2. Configuración incorrecta de la zona de búsqueda inversa en el servidor DNS." -ForegroundColor Yellow
    Write-Host "3. Los dispositivos no están registrados correctamente en el DNS." -ForegroundColor Yellow
    Write-Host "4. Problemas de replicación de DNS si hay múltiples servidores DNS." -ForegroundColor Yellow
    
    Write-Host "`nPasos recomendados:" -ForegroundColor Cyan
    Write-Host "1. Verificar la configuración de la zona de búsqueda inversa en el servidor DNS interno." -ForegroundColor Cyan
    Write-Host "2. Asegurarse de que DHCP esté configurado para registrar automáticamente los registros PTR." -ForegroundColor Cyan
    Write-Host "3. Revisar la configuración de DNS en los dispositivos que no se resuelven." -ForegroundColor Cyan
    Write-Host "4. Considerar la actualización manual de registros PTR para dispositivos estáticos." -ForegroundColor Cyan
    Write-Host "5. Verificar la replicación de DNS si se utilizan múltiples servidores DNS." -ForegroundColor Cyan
}
else {
    Write-Host "`nNo se detectaron problemas significativos de resolución inversa de DNS." -ForegroundColor Green
}
