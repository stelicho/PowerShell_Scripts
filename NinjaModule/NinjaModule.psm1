$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
$privateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($function in @($publicFunctions) + @($privateFunctions)) {
    . $function.FullName
}

Export-ModuleMember -Function $publicFunctions.BaseName
