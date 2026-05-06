param(
    [string]$AssemblyPath = (Join-Path $PSScriptRoot "..\Assembly-CSharp.dll"),
    [float]$IntervalSeconds = 30.0
)

$ErrorActionPreference = "Stop"

$assemblyFullPath = [System.IO.Path]::GetFullPath($AssemblyPath)
$toolRoot = Join-Path $PSScriptRoot "ilspycmd\tools\net10.0\any"
$cecilPath = Join-Path $toolRoot "Mono.Cecil.dll"

if (-not (Test-Path -LiteralPath $assemblyFullPath)) {
    throw "Assembly not found: $assemblyFullPath"
}
if (-not (Test-Path -LiteralPath $cecilPath)) {
    throw "Mono.Cecil not found: $cecilPath"
}

[void][System.Reflection.Assembly]::LoadFrom($cecilPath)

$backupPath = "$assemblyFullPath.pre-throttle.bak"
if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $assemblyFullPath -Destination $backupPath
}

$readerParams = [Mono.Cecil.ReaderParameters]::new()
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($assemblyFullPath, $readerParams)

try {
    $module = $assembly.MainModule
    $shop = $module.Types | Where-Object { $_.FullName -eq "BongoCat.Shop" } | Select-Object -First 1
    if (-not $shop) {
        throw "Could not find BongoCat.Shop"
    }

    $update = $shop.Methods | Where-Object { $_.Name -eq "Update" -and -not $_.IsStatic } | Select-Object -First 1
    if (-not $update) {
        throw "Could not find BongoCat.Shop.Update"
    }

    $canGetChest = $shop.Methods | Where-Object { $_.Name -eq "get_CanGetChest" -and -not $_.IsStatic } | Select-Object -First 1
    $onClick = $shop.Methods | Where-Object { $_.Name -eq "OnClick" -and -not $_.IsStatic } | Select-Object -First 1
    if (-not $canGetChest -or -not $onClick) {
        throw "Could not find get_CanGetChest and OnClick on BongoCat.Shop"
    }

    $fieldName = "_autoClaimNextCheckAt"
    $nextCheckField = $shop.Fields | Where-Object { $_.Name -eq $fieldName } | Select-Object -First 1
    if (-not $nextCheckField) {
        $nextCheckField = [Mono.Cecil.FieldDefinition]::new(
            $fieldName,
            [Mono.Cecil.FieldAttributes]::Private,
            $module.TypeSystem.Single
        )
        $shop.Fields.Add($nextCheckField)
    }

    $unityCore = $module.AssemblyReferences | Where-Object { $_.Name -eq "UnityEngine.CoreModule" } | Select-Object -First 1
    if (-not $unityCore) {
        throw "Could not find UnityEngine.CoreModule assembly reference"
    }

    $timeType = [Mono.Cecil.TypeReference]::new("UnityEngine", "Time", $module, $unityCore)
    $getRealtime = [Mono.Cecil.MethodReference]::new(
        "get_realtimeSinceStartup",
        $module.TypeSystem.Single,
        $timeType
    )
    $getRealtime.HasThis = $false
    $getRealtime = $module.ImportReference($getRealtime)

    $update.Body.Instructions.Clear()
    $update.Body.ExceptionHandlers.Clear()
    $update.Body.Variables.Clear()
    $update.Body.InitLocals = $true

    $nowLocal = [Mono.Cecil.Cil.VariableDefinition]::new($module.TypeSystem.Single)
    $update.Body.Variables.Add($nowLocal)

    $il = $update.Body.GetILProcessor()
    $ret = $il.Create([Mono.Cecil.Cil.OpCodes]::Ret)

    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Call, $getRealtime))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Stloc_0))

    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldloc_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $nextCheckField))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Blt_S, $ret))

    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldloc_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$IntervalSeconds))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Add))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Stfld, $nextCheckField))

    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Call, $canGetChest))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $ret))

    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
    $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Call, $onClick))
    $il.Append($ret)

    $writerParams = [Mono.Cecil.WriterParameters]::new()
    $tempPath = "$assemblyFullPath.tmp"
    $assembly.Write($tempPath, $writerParams)
}
finally {
    if ($assembly) {
        $assembly.Dispose()
    }
}

Move-Item -Force -LiteralPath $tempPath -Destination $assemblyFullPath

[pscustomobject]@{
    Assembly = $assemblyFullPath
    Backup = $backupPath
    IntervalSeconds = $IntervalSeconds
    Patched = $true
}
