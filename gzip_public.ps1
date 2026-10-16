# Badi .js files ki .gz copy banata hai (server ye phone ko chhoti file bhejne ke liye use karta hai)
$dir = Join-Path $PSScriptRoot 'web\cpp_backend\public'
foreach ($n in 'main.dart.js','flutter.js','flutter_bootstrap.js') {
  $src = Join-Path $dir $n
  if (-not (Test-Path $src)) { continue }
  $in = [IO.File]::OpenRead($src)
  $out = [IO.File]::Create($src + '.gz')
  $gz = New-Object IO.Compression.GZipStream($out, [IO.Compression.CompressionLevel]::Optimal)
  $in.CopyTo($gz); $gz.Dispose(); $out.Dispose(); $in.Dispose()
  '{0}: {1:N0} KB -> {2:N0} KB' -f $n, ((Get-Item $src).Length/1KB), ((Get-Item ($src+'.gz')).Length/1KB)
}
