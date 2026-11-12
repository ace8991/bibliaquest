# Downloads and extracts the official CC0 "makehuman_system_assets" pack (about 281 MB).
# Page: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
# Build-time only. Nothing here is needed to run the game.
# Usage:  .\fetch_mh_system_assets.ps1 -Destination D:\somewhere\mh_assets
#         then set  $env:BQ_MH_ASSETS = 'D:\somewhere\mh_assets\system'
param([Parameter(Mandatory = $true)][string]$Destination)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Destination | Out-Null
$url = 'https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
$expected = 'B542127A8E25547C7C29C19F2D1D2ADB9A664C80396ECD694095DBC8028A0107'
$total = 280737770
$target = Join-Path $Destination 'makehuman_system_assets_cc0.zip'
if (-not (Test-Path $target)) {
	# The server is slow per connection, so the file is fetched in parallel byte ranges.
	$parts = 12
	$size = [math]::Ceiling($total / $parts)
	$procs = @()
	for ($i = 0; $i -lt $parts; $i++) {
		$from = $i * $size
		$to = [math]::Min($total - 1, $from + $size - 1)
		$out = Join-Path $Destination ("part_{0:D2}.bin" -f $i)
		$procs += Start-Process curl.exe -NoNewWindow -PassThru -ArgumentList @('-sS', '-L', '--fail', '--retry', '8', '--retry-all-errors', '-A', 'Mozilla/5.0', '-r', "$from-$to", '-o', "`"$out`"", $url)
	}
	$procs | Wait-Process
	$stream = [System.IO.File]::Create($target)
	try {
		for ($i = 0; $i -lt $parts; $i++) {
			$part = [System.IO.File]::OpenRead((Join-Path $Destination ("part_{0:D2}.bin" -f $i)))
			$part.CopyTo($stream)
			$part.Close()
		}
	} finally { $stream.Close() }
}
$hash = (Get-FileHash $target -Algorithm SHA256).Hash
if ($hash -ne $expected) { throw "Unexpected SHA-256 $hash (expected $expected). The pack may have been updated; review it before use." }
$system = Join-Path $Destination 'system'
if (-not (Test-Path $system)) { Expand-Archive $target -DestinationPath $system }
"Ready. Set BQ_MH_ASSETS to $system"
