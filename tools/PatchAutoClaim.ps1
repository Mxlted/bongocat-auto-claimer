param(
	[string]$AssemblyPath = (Join-Path (Get-Location) "Assembly-CSharp.dll"),
	[float]$IntervalSeconds = 5.0,
	[float]$NormalInitialDelaySeconds = 1.0,
	[float]$EmoteInitialDelaySeconds = 2.0,
	[string]$CecilPath = (Join-Path (Get-Location) "tools\ilspycmd\tools\net10.0\any\Mono.Cecil.dll")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$assemblyItem = Get-Item -LiteralPath $AssemblyPath
$cecilItem = Get-Item -LiteralPath $CecilPath

Add-Type -Path $cecilItem.FullName

$backupPath = "$($assemblyItem.FullName).pre-autoclaim.bak"
if (-not (Test-Path -LiteralPath $backupPath)) {
	Copy-Item -LiteralPath $assemblyItem.FullName -Destination $backupPath
}

$readerParameters = [Mono.Cecil.ReaderParameters]::new()
$readerParameters.InMemory = $true

$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($assemblyItem.FullName, $readerParameters)
$module = $assembly.MainModule

$shop = $module.Types | Where-Object { $_.FullName -eq "BongoCat.Shop" } | Select-Object -First 1
if ($null -eq $shop) {
	throw "Could not find BongoCat.Shop."
}

$shopItem = $module.Types | Where-Object { $_.FullName -eq "BongoCat.ShopItem" } | Select-Object -First 1
if ($null -eq $shopItem) {
	throw "Could not find BongoCat.ShopItem."
}

$awake = $shop.Methods | Where-Object { $_.Name -eq "Awake" } | Select-Object -First 1
if ($null -eq $awake -or -not $awake.HasBody) {
	throw "Could not find BongoCat.Shop.Awake()."
}

$isEmoteShopField = $shop.Fields | Where-Object { $_.Name -eq "_isEmoteShop" } | Select-Object -First 1
$shopItemField = $shop.Fields | Where-Object { $_.Name -eq "_shopItem" } | Select-Object -First 1
$chestIsReadyField = $shop.Fields | Where-Object { $_.Name -eq "ChestIsReady" } | Select-Object -First 1
if ($null -eq $isEmoteShopField -or $null -eq $shopItemField -or $null -eq $chestIsReadyField) {
	throw "Could not find one or more required Shop fields."
}

$canBuy = $shopItem.Methods | Where-Object { $_.Name -eq "CanBuy" -and -not $_.HasParameters } | Select-Object -First 1
$buy = $shopItem.Methods | Where-Object { $_.Name -eq "Buy" -and -not $_.HasParameters } | Select-Object -First 1
if ($null -eq $canBuy -or $null -eq $buy) {
	throw "Could not find ShopItem.CanBuy() or ShopItem.Buy()."
}

$existingAutoClaimTick = $shop.Methods | Where-Object { $_.Name -eq "AutoClaimTick" } | Select-Object -First 1
if ($null -eq $existingAutoClaimTick) {
	$autoClaimTick = [Mono.Cecil.MethodDefinition]::new(
		"AutoClaimTick",
		[Mono.Cecil.MethodAttributes]::Private -bor [Mono.Cecil.MethodAttributes]::HideBySig,
		$module.TypeSystem.Void
	)
	[void]$shop.Methods.Add($autoClaimTick)
} else {
	$autoClaimTick = $existingAutoClaimTick
}

$autoClaimTick.Body = [Mono.Cecil.Cil.MethodBody]::new($autoClaimTick)
$autoClaimTick.Body.InitLocals = $false
$autoClaimIl = $autoClaimTick.Body.GetILProcessor()
$autoClaimReturn = [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ret)

$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $chestIsReadyField))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $shopItemField))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $shopItemField))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Callvirt, $canBuy))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $shopItemField))
$autoClaimIl.Append([Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Callvirt, $buy))
$autoClaimIl.Append($autoClaimReturn)

$invokeRepeating = [Mono.Cecil.MethodReference]::new("InvokeRepeating", $module.TypeSystem.Void, $shop.BaseType)
$invokeRepeating.HasThis = $true
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("methodName", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.String))
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("time", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.Single))
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("repeatRate", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.Single))

$awakeIl = $awake.Body.GetILProcessor()
$awakeReturns = @($awake.Body.Instructions | Where-Object { $_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret })
if ($awakeReturns.Count -eq 0) {
	throw "Could not find return instruction in Shop.Awake()."
}

foreach ($awakeReturn in $awakeReturns) {
	$alreadySchedulesThisReturn = $false
	$scanInstruction = $awakeReturn.Previous
	while ($null -ne $scanInstruction -and $scanInstruction.OpCode.Code -ne [Mono.Cecil.Cil.Code]::Ret) {
		if ($scanInstruction.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldstr -and $scanInstruction.Operand -eq "AutoClaimTick") {
			$alreadySchedulesThisReturn = $true
			break
		}
		$scanInstruction = $scanInstruction.Previous
	}

	if ($alreadySchedulesThisReturn) {
		continue
	}

	$normalDelayInstruction = [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$NormalInitialDelaySeconds)
	$intervalInstruction = [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$IntervalSeconds)

	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldstr, "AutoClaimTick"))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $isEmoteShopField))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $normalDelayInstruction))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$EmoteInitialDelaySeconds))
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Br_S, $intervalInstruction))
	$awakeIl.InsertBefore($awakeReturn, $normalDelayInstruction)
	$awakeIl.InsertBefore($awakeReturn, $intervalInstruction)
	$awakeIl.InsertBefore($awakeReturn, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Call, $invokeRepeating))
}

$assembly.Write($assemblyItem.FullName)

Write-Host "Patched $($assemblyItem.FullName)"
Write-Host "Backup: $backupPath"
Write-Host "Auto claim: direct ShopItem.Buy(), initial delays ${NormalInitialDelaySeconds}s/${EmoteInitialDelaySeconds}s, interval ${IntervalSeconds}s"
