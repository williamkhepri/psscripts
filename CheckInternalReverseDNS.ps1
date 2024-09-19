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

# Función para obtener el rango de IP de la subred seleccionada
function Get-SubnetRange {
    param (
        [Parameter(Mandatory=$true)]
        [System.Net.NetworkInformation.NetworkInterface]$Adapter
    )
    $ip = Get-NetIPAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4
    $network = $ip.IPAddress -replace "\.\d+$", ".0"
    $mask = $ip.PrefixLength
    return @{
        Network = $network
        Mask = $mask
    }
}

# Obtener todas las interfaces de red activas
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Mostrar las interfaces disponibles al usuario
Write-Host "Interfaces de red disponibles:" -ForegroundColor Cyan
for ($i = 0; $i -lt $activeAdapters.Count; $i++) {
    Write-Host "$($i + 1). $($activeAdapters[$i].Name) - $($activeAdapters[$i].InterfaceDescription)"
}

# Pedir al usuario que seleccione la interfaz de la VPN
do {
    $selection = Read-Host "Seleccione el número de la interfaz de la VPN"
    $selectedAdapter = $activeAdapters[$selection - 1]
} while (-not $selectedAdapter)

# Obtener información de la subred seleccionada
$subnetInfo = Get-SubnetRange -Adapter $selectedAdapter
$network = $subnetInfo.Network
$mask = $subnetInfo.Mask

Write-Host "Analizando la red VPN: $network/$mask" -ForegroundColor Cyan

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
    Write-Progress -Activity "Escaneando red VPN" -Status "$percentComplete% Completo" -PercentComplete $percentComplete

    if (Test-Connection -ComputerName $currentIP -Count 1 -Quiet) {
        $hostname = Get-ReverseDNS -IPAddress $currentIP
        $results += [PSCustomObject]@{
            IPAddress = $currentIP
            Hostname = if ($hostname) { $hostname } else { "No se pudo resolver" }
            Status = if ($hostname) { "Resuelto" } else { "No resuelto" }
        }
    }
}

Write-Progress -Activity "Escaneando red VPN" -Completed

# Mostrar resultados
Write-Host "`nResultados del escaneo de resolución inversa de DNS en la red VPN:" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Análisis de resultados
$totalDevices = $results.Count
$resolvedDevices = ($results | Where-Object { $_.Status -eq "Resuelto" }).Count
$unresolvedDevices = $totalDevices - $resolvedDevices

Write-Host "`nResumen:" -ForegroundColor Cyan
Write-Host "Total de dispositivos encontrados en la VPN: $totalDevices" -ForegroundColor Green
Write-Host "Dispositivos con resolución inversa exitosa: $resolvedDevices" -ForegroundColor Green
Write-Host "Dispositivos sin resolución inversa: $unresolvedDevices" -ForegroundColor Yellow

if ($unresolvedDevices -gt 0) {
    $percentageUnresolved = [math]::Round(($unresolvedDevices / $totalDevices) * 100, 2)
    Write-Host "`nProblemas potenciales detectados en la red VPN:" -ForegroundColor Yellow
    Write-Host "- $percentageUnresolved% de los dispositivos no tienen resolución inversa de DNS." -ForegroundColor Yellow
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "1. Falta de registros PTR en el servidor DNS de la VPN." -ForegroundColor Yellow
    Write-Host "2. Configuración incorrecta de la zona de búsqueda inversa en el servidor DNS de la VPN." -ForegroundColor Yellow
    Write-Host "3. Los dispositivos de la VPN no están registrados correctamente en el DNS." -ForegroundColor Yellow
    Write-Host "4. Problemas de propagación de DNS en la red VPN." -ForegroundColor Yellow
    
    Write-Host "`nPasos recomendados:" -ForegroundColor Cyan
    Write-Host "1. Verificar la configuración de la zona de búsqueda inversa en el servidor DNS de la VPN." -ForegroundColor Cyan
    Write-Host "2. Asegurarse de que el servidor VPN esté configurado para registrar automáticamente los registros PTR de los clientes." -ForegroundColor Cyan
    Write-Host "3. Revisar la configuración de DNS en los dispositivos VPN que no se resuelven." -ForegroundColor Cyan
    Write-Host "4. Considerar la actualización manual de registros PTR para dispositivos VPN con IP estática." -ForegroundColor Cyan
    Write-Host "5. Verificar la propagación de DNS en la infraestructura de la VPN." -ForegroundColor Cyan
}
else {
    Write-Host "`nNo se detectaron problemas significativos de resolución inversa de DNS en la red VPN." -ForegroundColor Green
}
