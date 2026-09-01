param(
	[string]$AssemblyPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "Assembly-CSharp.dll"),
	[float]$IntervalSeconds = 5.0,
	[float]$NormalInitialDelaySeconds = 1.0,
	[float]$EmoteInitialDelaySeconds = 2.0,
	[string]$CecilPath = (Join-Path $PSScriptRoot "ilspycmd\tools\net10.0\any\Mono.Cecil.dll"),
	[switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-PositiveFiniteSingle {
	param(
		[float]$Value,
		[string]$Name
	)

	if ([single]::IsNaN($Value) -or [single]::IsInfinity($Value) -or $Value -le 0) {
		throw "$Name must be a finite number greater than zero. Received: $Value"
	}
}

Assert-PositiveFiniteSingle -Value $IntervalSeconds -Name "IntervalSeconds"
Assert-PositiveFiniteSingle -Value $NormalInitialDelaySeconds -Name "NormalInitialDelaySeconds"
Assert-PositiveFiniteSingle -Value $EmoteInitialDelaySeconds -Name "EmoteInitialDelaySeconds"

$assemblyItem = Get-Item -LiteralPath $AssemblyPath
$cecilItem = Get-Item -LiteralPath $CecilPath

Add-Type -Path $cecilItem.FullName

function Get-SingleType {
	param(
		[Mono.Cecil.ModuleDefinition]$Module,
		[string]$FullName
	)

	$matches = @($Module.Types | Where-Object { $_.FullName -eq $FullName })
	if ($matches.Count -ne 1) {
		throw "Expected exactly one $FullName type, but found $($matches.Count)."
	}

	return $matches[0]
}

function Get-SingleField {
	param(
		[Mono.Cecil.TypeDefinition]$Type,
		[string]$Name,
		[string]$FieldTypeFullName
	)

	$matches = @($Type.Fields | Where-Object {
		$_.Name -eq $Name -and $_.FieldType.FullName -eq $FieldTypeFullName
	})
	if ($matches.Count -ne 1) {
		throw "Expected exactly one $($Type.FullName).$Name field of type $FieldTypeFullName, but found $($matches.Count)."
	}

	return $matches[0]
}

function Get-SingleParameterlessInstanceMethod {
	param(
		[Mono.Cecil.TypeDefinition]$Type,
		[string]$Name,
		[string]$ReturnTypeFullName
	)

	$matches = @($Type.Methods | Where-Object {
		$_.Name -eq $Name -and
		-not $_.IsStatic -and
		-not $_.HasParameters -and
		$_.ReturnType.FullName -eq $ReturnTypeFullName
	})
	if ($matches.Count -ne 1) {
		throw "Expected exactly one parameterless instance method $($Type.FullName).$Name returning $ReturnTypeFullName, but found $($matches.Count)."
	}

	return $matches[0]
}

function Test-Code {
	param(
		[Mono.Cecil.Cil.Instruction]$Instruction,
		[Mono.Cecil.Cil.Code[]]$Codes
	)

	return $null -ne $Instruction -and $Codes -contains $Instruction.OpCode.Code
}

function Get-AutoClaimScheduleBeforeReturn {
	param(
		[Mono.Cecil.Cil.Instruction]$ReturnInstruction,
		[string]$IsEmoteShopFieldFullName
	)

	$call = $ReturnInstruction.Previous
	$interval = if ($null -ne $call) { $call.Previous } else { $null }
	$normalDelay = if ($null -ne $interval) { $interval.Previous } else { $null }
	$branchToInterval = if ($null -ne $normalDelay) { $normalDelay.Previous } else { $null }
	$emoteDelay = if ($null -ne $branchToInterval) { $branchToInterval.Previous } else { $null }
	$branchToNormal = if ($null -ne $emoteDelay) { $emoteDelay.Previous } else { $null }
	$loadEmoteFlag = if ($null -ne $branchToNormal) { $branchToNormal.Previous } else { $null }
	$loadThisForFlag = if ($null -ne $loadEmoteFlag) { $loadEmoteFlag.Previous } else { $null }
	$loadMethodName = if ($null -ne $loadThisForFlag) { $loadThisForFlag.Previous } else { $null }
	$start = if ($null -ne $loadMethodName) { $loadMethodName.Previous } else { $null }

	if (-not (Test-Code $call @([Mono.Cecil.Cil.Code]::Call))) { return $null }
	if (-not (Test-Code $interval @([Mono.Cecil.Cil.Code]::Ldc_R4))) { return $null }
	if (-not (Test-Code $normalDelay @([Mono.Cecil.Cil.Code]::Ldc_R4))) { return $null }
	if (-not (Test-Code $branchToInterval @([Mono.Cecil.Cil.Code]::Br, [Mono.Cecil.Cil.Code]::Br_S))) { return $null }
	if (-not (Test-Code $emoteDelay @([Mono.Cecil.Cil.Code]::Ldc_R4))) { return $null }
	if (-not (Test-Code $branchToNormal @([Mono.Cecil.Cil.Code]::Brfalse, [Mono.Cecil.Cil.Code]::Brfalse_S))) { return $null }
	if (-not (Test-Code $loadEmoteFlag @([Mono.Cecil.Cil.Code]::Ldfld))) { return $null }
	if (-not (Test-Code $loadThisForFlag @([Mono.Cecil.Cil.Code]::Ldarg_0))) { return $null }
	if (-not (Test-Code $loadMethodName @([Mono.Cecil.Cil.Code]::Ldstr))) { return $null }
	if (-not (Test-Code $start @([Mono.Cecil.Cil.Code]::Ldarg_0))) { return $null }

	if ($loadMethodName.Operand -ne "AutoClaimTick") { return $null }
	if ($loadEmoteFlag.Operand.FullName -ne $IsEmoteShopFieldFullName) { return $null }
	if (-not [object]::ReferenceEquals($branchToNormal.Operand, $normalDelay)) { return $null }
	if (-not [object]::ReferenceEquals($branchToInterval.Operand, $interval)) { return $null }

	if ($call.Operand -isnot [Mono.Cecil.MethodReference]) { return $null }
	$method = [Mono.Cecil.MethodReference]$call.Operand
	if ($method.Name -ne "InvokeRepeating" -or
		$method.DeclaringType.FullName -ne "UnityEngine.MonoBehaviour" -or
		$method.ReturnType.FullName -ne "System.Void" -or
		-not $method.HasThis -or
		$method.Parameters.Count -ne 3 -or
		$method.Parameters[0].ParameterType.FullName -ne "System.String" -or
		$method.Parameters[1].ParameterType.FullName -ne "System.Single" -or
		$method.Parameters[2].ParameterType.FullName -ne "System.Single") {
		return $null
	}

	return [pscustomobject]@{
		Start = $start
		NormalDelay = $normalDelay
		EmoteDelay = $emoteDelay
		Interval = $interval
	}
}

function Redirect-BranchesToSchedule {
	param(
		[Mono.Cecil.Cil.MethodBody]$Body,
		[Mono.Cecil.Cil.Instruction]$ReturnInstruction,
		[Mono.Cecil.Cil.Instruction]$ScheduleStart
	)

	foreach ($instruction in @($Body.Instructions)) {
		if ($instruction.Operand -is [Mono.Cecil.Cil.Instruction]) {
			if ([object]::ReferenceEquals($instruction.Operand, $ReturnInstruction)) {
				$instruction.Operand = $ScheduleStart
			}
		} elseif ($instruction.Operand -is [Mono.Cecil.Cil.Instruction[]]) {
			$targets = [Mono.Cecil.Cil.Instruction[]]$instruction.Operand
			for ($index = 0; $index -lt $targets.Length; $index++) {
				if ([object]::ReferenceEquals($targets[$index], $ReturnInstruction)) {
					$targets[$index] = $ScheduleStart
				}
			}
			$instruction.Operand = $targets
		}
	}
}

function Assert-PatchedAssembly {
	param(
		[string]$Path,
		[float]$ExpectedNormalDelay,
		[float]$ExpectedEmoteDelay,
		[float]$ExpectedInterval
	)

	$validationParameters = [Mono.Cecil.ReaderParameters]::new()
	$validationParameters.InMemory = $true
	$validationAssembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Path, $validationParameters)
	try {
		$validationModule = $validationAssembly.MainModule
		$validationShop = Get-SingleType $validationModule "BongoCat.Shop"
		$validationShopItem = Get-SingleType $validationModule "BongoCat.ShopItem"
		$validationAwake = Get-SingleParameterlessInstanceMethod $validationShop "Awake" "System.Void"
		$validationField = Get-SingleField $validationShop "_isEmoteShop" "System.Boolean"
		$validationShopItemField = Get-SingleField $validationShop "_shopItem" "BongoCat.ShopItem"
		$validationChestIsReadyField = Get-SingleField $validationShop "ChestIsReady" "System.Boolean"
		$validationOpeningChestField = Get-SingleField $validationShop "_openingChest" "System.Boolean"
		$validationCanBuy = Get-SingleParameterlessInstanceMethod $validationShopItem "CanBuy" "System.Boolean"
		$validationBuy = Get-SingleParameterlessInstanceMethod $validationShopItem "Buy" "System.Void"
		$validationTicks = @($validationShop.Methods | Where-Object {
			$_.Name -eq "AutoClaimTick" -and -not $_.IsStatic -and -not $_.HasParameters -and $_.ReturnType.FullName -eq "System.Void"
		})
		if ($validationTicks.Count -ne 1 -or -not $validationTicks[0].HasBody) {
			throw "Written assembly does not contain exactly one valid AutoClaimTick() method."
		}

		$tickBody = $validationTicks[0].Body
		$tickInstructions = @($tickBody.Instructions)
		if ($tickBody.InitLocals -or
			$tickBody.Variables.Count -ne 1 -or
			$tickBody.Variables[0].VariableType.FullName -ne $validationShopItem.FullName -or
			$tickInstructions.Count -ne 17 -or
			-not (Test-Code $tickInstructions[0] @([Mono.Cecil.Cil.Code]::Ldarg_0)) -or
			-not (Test-Code $tickInstructions[1] @([Mono.Cecil.Cil.Code]::Ldfld)) -or
			$tickInstructions[1].Operand.FullName -ne $validationChestIsReadyField.FullName -or
			-not (Test-Code $tickInstructions[2] @([Mono.Cecil.Cil.Code]::Brfalse_S)) -or
			-not (Test-Code $tickInstructions[3] @([Mono.Cecil.Cil.Code]::Ldarg_0)) -or
			-not (Test-Code $tickInstructions[4] @([Mono.Cecil.Cil.Code]::Ldfld)) -or
			$tickInstructions[4].Operand.FullName -ne $validationOpeningChestField.FullName -or
			-not (Test-Code $tickInstructions[5] @([Mono.Cecil.Cil.Code]::Brtrue_S)) -or
			-not (Test-Code $tickInstructions[6] @([Mono.Cecil.Cil.Code]::Ldarg_0)) -or
			-not (Test-Code $tickInstructions[7] @([Mono.Cecil.Cil.Code]::Ldfld)) -or
			$tickInstructions[7].Operand.FullName -ne $validationShopItemField.FullName -or
			-not (Test-Code $tickInstructions[8] @([Mono.Cecil.Cil.Code]::Stloc_0)) -or
			-not (Test-Code $tickInstructions[9] @([Mono.Cecil.Cil.Code]::Ldloc_0)) -or
			-not (Test-Code $tickInstructions[10] @([Mono.Cecil.Cil.Code]::Brfalse_S)) -or
			-not (Test-Code $tickInstructions[11] @([Mono.Cecil.Cil.Code]::Ldloc_0)) -or
			-not (Test-Code $tickInstructions[12] @([Mono.Cecil.Cil.Code]::Callvirt)) -or
			$tickInstructions[12].Operand.FullName -ne $validationCanBuy.FullName -or
			-not (Test-Code $tickInstructions[13] @([Mono.Cecil.Cil.Code]::Brfalse_S)) -or
			-not (Test-Code $tickInstructions[14] @([Mono.Cecil.Cil.Code]::Ldloc_0)) -or
			-not (Test-Code $tickInstructions[15] @([Mono.Cecil.Cil.Code]::Callvirt)) -or
			$tickInstructions[15].Operand.FullName -ne $validationBuy.FullName -or
			-not (Test-Code $tickInstructions[16] @([Mono.Cecil.Cil.Code]::Ret)) -or
			-not [object]::ReferenceEquals($tickInstructions[2].Operand, $tickInstructions[16]) -or
			-not [object]::ReferenceEquals($tickInstructions[5].Operand, $tickInstructions[16]) -or
			-not [object]::ReferenceEquals($tickInstructions[10].Operand, $tickInstructions[16]) -or
			-not [object]::ReferenceEquals($tickInstructions[13].Operand, $tickInstructions[16])) {
			throw "Written AutoClaimTick() method body did not pass structural validation."
		}

		$returns = @($validationAwake.Body.Instructions | Where-Object { $_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret })
		if ($returns.Count -eq 0) {
			throw "Written Shop.Awake() has no return instructions."
		}

		foreach ($returnInstruction in $returns) {
			$schedule = Get-AutoClaimScheduleBeforeReturn $returnInstruction $validationField.FullName
			if ($null -eq $schedule) {
				throw "Written Shop.Awake() has an exit without a valid auto-claim schedule."
			}
			if ([single]$schedule.NormalDelay.Operand -ne [single]$ExpectedNormalDelay -or
				[single]$schedule.EmoteDelay.Operand -ne [single]$ExpectedEmoteDelay -or
				[single]$schedule.Interval.Operand -ne [single]$ExpectedInterval) {
				throw "Written Shop.Awake() contains unexpected auto-claim timing values."
			}
		}

		$markers = @($validationAwake.Body.Instructions | Where-Object {
			$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldstr -and $_.Operand -eq "AutoClaimTick"
		})
		if ($markers.Count -ne $returns.Count) {
			throw "Written Shop.Awake() contains an unexpected number of AutoClaimTick schedules."
		}
	} finally {
		$validationAssembly.Dispose()
	}
}

$readerParameters = [Mono.Cecil.ReaderParameters]::new()
$readerParameters.InMemory = $true

$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($assemblyItem.FullName, $readerParameters)
$module = $assembly.MainModule

$shop = Get-SingleType $module "BongoCat.Shop"
$shopItem = Get-SingleType $module "BongoCat.ShopItem"

$awake = Get-SingleParameterlessInstanceMethod $shop "Awake" "System.Void"
if (-not $awake.HasBody) {
	throw "BongoCat.Shop.Awake() has no IL body."
}

$isEmoteShopField = Get-SingleField $shop "_isEmoteShop" "System.Boolean"
$shopItemField = Get-SingleField $shop "_shopItem" "BongoCat.ShopItem"
$chestIsReadyField = Get-SingleField $shop "ChestIsReady" "System.Boolean"
$openingChestField = Get-SingleField $shop "_openingChest" "System.Boolean"
$canBuy = Get-SingleParameterlessInstanceMethod $shopItem "CanBuy" "System.Boolean"
$buy = Get-SingleParameterlessInstanceMethod $shopItem "Buy" "System.Void"

$awakeReturns = @($awake.Body.Instructions | Where-Object { $_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret })
if ($awakeReturns.Count -eq 0) {
	throw "Could not find a return instruction in BongoCat.Shop.Awake()."
}

$existingAutoClaimTicks = @($shop.Methods | Where-Object { $_.Name -eq "AutoClaimTick" })
if ($existingAutoClaimTicks.Count -gt 1) {
	throw "Found more than one BongoCat.Shop.AutoClaimTick method."
}

$existingSchedules = @()
foreach ($awakeReturn in $awakeReturns) {
	$schedule = Get-AutoClaimScheduleBeforeReturn $awakeReturn $isEmoteShopField.FullName
	if ($null -ne $schedule) {
		$existingSchedules += $schedule
	}
}

$existingMarkers = @($awake.Body.Instructions | Where-Object {
	$_.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldstr -and $_.Operand -eq "AutoClaimTick"
})
if ($existingMarkers.Count -ne $existingSchedules.Count) {
	throw "Found an unrecognized or partial AutoClaimTick schedule in BongoCat.Shop.Awake(). Restore a clean DLL before patching."
}
if ($existingAutoClaimTicks.Count -eq 1 -and $existingSchedules.Count -eq 0) {
	throw "BongoCat.Shop.AutoClaimTick already exists but was not created by this patcher. Refusing to overwrite it."
}
if ($existingAutoClaimTicks.Count -eq 0 -and $existingSchedules.Count -gt 0) {
	throw "BongoCat.Shop.Awake() schedules AutoClaimTick, but the method is missing. Restore a clean DLL before patching."
}

$wasAlreadyPatched = $existingAutoClaimTicks.Count -eq 1
if ($wasAlreadyPatched) {
	$autoClaimTick = $existingAutoClaimTicks[0]
	if ($autoClaimTick.IsStatic -or $autoClaimTick.HasParameters -or $autoClaimTick.ReturnType.FullName -ne "System.Void") {
		throw "Existing BongoCat.Shop.AutoClaimTick has an incompatible signature."
	}
}

if ($ValidateOnly) {
	$patchState = if ($wasAlreadyPatched) { "recognized existing patch" } else { "clean assembly" }
	$assembly.Dispose()
	Write-Host "Compatible: $($assemblyItem.FullName)"
	Write-Host "State: $patchState"
	Write-Host "Validated: BongoCat.Shop.Awake() ($($awakeReturns.Count) exits), required fields including Shop._openingChest, ShopItem.CanBuy(), and ShopItem.Buy()."
	return
}

if (-not $wasAlreadyPatched) {
	$autoClaimTick = [Mono.Cecil.MethodDefinition]::new(
		"AutoClaimTick",
		[Mono.Cecil.MethodAttributes]::Private -bor [Mono.Cecil.MethodAttributes]::HideBySig,
		$module.TypeSystem.Void
	)
	[void]$shop.Methods.Add($autoClaimTick)
}

$autoClaimTick.Body = [Mono.Cecil.Cil.MethodBody]::new($autoClaimTick)
$autoClaimTick.Body.InitLocals = $false
$shopItemVariable = [Mono.Cecil.Cil.VariableDefinition]::new($shopItem)
[void]$autoClaimTick.Body.Variables.Add($shopItemVariable)
$autoClaimIl = $autoClaimTick.Body.GetILProcessor()
$autoClaimReturn = $autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ret)

$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $chestIsReadyField))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $openingChestField))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Brtrue_S, $autoClaimReturn))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $shopItemField))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Stloc_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldloc_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldloc_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Callvirt, $canBuy))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $autoClaimReturn))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Ldloc_0))
$autoClaimIl.Append($autoClaimIl.Create([Mono.Cecil.Cil.OpCodes]::Callvirt, $buy))
$autoClaimIl.Append($autoClaimReturn)

$invokeRepeating = [Mono.Cecil.MethodReference]::new("InvokeRepeating", $module.TypeSystem.Void, $shop.BaseType)
$invokeRepeating.HasThis = $true
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("methodName", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.String))
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("time", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.Single))
[void]$invokeRepeating.Parameters.Add([Mono.Cecil.ParameterDefinition]::new("repeatRate", [Mono.Cecil.ParameterAttributes]::None, $module.TypeSystem.Single))
$invokeRepeating = $module.ImportReference($invokeRepeating)

$awakeIl = $awake.Body.GetILProcessor()
$injectedScheduleCount = 0
$refreshedScheduleCount = 0

foreach ($awakeReturn in $awakeReturns) {
	$schedule = Get-AutoClaimScheduleBeforeReturn $awakeReturn $isEmoteShopField.FullName
	if ($null -ne $schedule) {
		$schedule.NormalDelay.Operand = [single]$NormalInitialDelaySeconds
		$schedule.EmoteDelay.Operand = [single]$EmoteInitialDelaySeconds
		$schedule.Interval.Operand = [single]$IntervalSeconds
		$refreshedScheduleCount++
	} else {
		$start = $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
		$normalDelayInstruction = $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$NormalInitialDelaySeconds)
		$intervalInstruction = $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$IntervalSeconds)

		$awakeIl.InsertBefore($awakeReturn, $start)
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldstr, "AutoClaimTick"))
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $isEmoteShopField))
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Brfalse_S, $normalDelayInstruction))
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]$EmoteInitialDelaySeconds))
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Br_S, $intervalInstruction))
		$awakeIl.InsertBefore($awakeReturn, $normalDelayInstruction)
		$awakeIl.InsertBefore($awakeReturn, $intervalInstruction)
		$awakeIl.InsertBefore($awakeReturn, $awakeIl.Create([Mono.Cecil.Cil.OpCodes]::Call, $invokeRepeating))
		$schedule = [pscustomobject]@{ Start = $start }
		$injectedScheduleCount++
	}

	Redirect-BranchesToSchedule $awake.Body $awakeReturn $schedule.Start
}

$backupPath = $null
if (-not $wasAlreadyPatched) {
	$preferredBackupPath = "$($assemblyItem.FullName).pre-autoclaim.bak"
	if (-not (Test-Path -LiteralPath $preferredBackupPath)) {
		$backupPath = $preferredBackupPath
	} else {
		$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $assemblyItem.FullName).Hash.Substring(0, 12).ToLowerInvariant()
		$versionedBackupPath = "$($assemblyItem.FullName).pre-autoclaim.$sourceHash.bak"
		if (-not (Test-Path -LiteralPath $versionedBackupPath)) {
			$backupPath = $versionedBackupPath
		}
	}

	if ($null -ne $backupPath) {
		Copy-Item -LiteralPath $assemblyItem.FullName -Destination $backupPath
	}
}

$temporaryOutputPath = Join-Path $assemblyItem.DirectoryName ".$($assemblyItem.Name).autoclaim.$([guid]::NewGuid().ToString('N')).tmp"
$replacementRollbackPath = "$temporaryOutputPath.rollback"
try {
	$assembly.Write($temporaryOutputPath)
	Assert-PatchedAssembly $temporaryOutputPath $NormalInitialDelaySeconds $EmoteInitialDelaySeconds $IntervalSeconds
	$assembly.Dispose()
	$assembly = $null
	[System.IO.File]::Replace($temporaryOutputPath, $assemblyItem.FullName, $replacementRollbackPath)
} finally {
	if ($null -ne $assembly) {
		$assembly.Dispose()
	}
	if (Test-Path -LiteralPath $temporaryOutputPath) {
		Remove-Item -LiteralPath $temporaryOutputPath -Force
	}
	if (Test-Path -LiteralPath $replacementRollbackPath) {
		Remove-Item -LiteralPath $replacementRollbackPath -Force
	}
}

Write-Host "Patched and validated: $($assemblyItem.FullName)"
if ($null -ne $backupPath) {
	Write-Host "Backup: $backupPath"
} elseif ($wasAlreadyPatched) {
	Write-Host "Backup: unchanged (input already contained this patch)"
} else {
	Write-Host "Backup: unchanged (this clean DLL version was already backed up)"
}
Write-Host "Schedules: $injectedScheduleCount added, $refreshedScheduleCount refreshed"
Write-Host "Auto claim: direct ShopItem.Buy(), initial delays ${NormalInitialDelaySeconds}s/${EmoteInitialDelaySeconds}s, interval ${IntervalSeconds}s"
