# Bongo Cat Auto-Claim Chest Mod

A DLL patch for Bongo Cat that auto-claims chests as soon as they become available.

> Working as of May 2026

## What It Does

Injects an `Update()` method into `BongoCat.Shop` that checks every frame whether a chest is ready (`CanGetChest`) and auto-claims it (`OnClick()`). No manual clicking required.

The injected IL is minimal:

```
IL_0000: ldarg.0
IL_0001: call get_CanGetChest
IL_0006: brfalse.s IL_000e
IL_0008: ldarg.0
IL_0009: call OnClick
IL_000e: ret
```

Equivalent C#:

```csharp
void Update()
{
    if (CanGetChest)
        OnClick();
}
```

## Files

| File | Description |
|------|-------------|
| `Assembly-CSharp.dll` | Patched DLL with auto-claim injected |
| `Assembly-CSharp.dll.bak` | Original unmodified DLL (backup) |
| `tool/Patcher.cs` | C# tool that injects the `Update()` method via Mono.Cecil |
| `tool/FinalVerify.cs` | Verification tool - confirms the patch is applied correctly |
| `tool/Explore.cs` | Diagnostic tool - inspects the DLL's Shop internals |
| `tool/Verify.cs` | Diagnostic tool - checks exception handlers in `ToggleOnHover` |
| `tool/Mono.Cecil.dll` | .NET assembly read/write library used by the patcher |

## Requirements

- [Bongo Cat on Steam](https://store.steampowered.com/app/2324940/Bongo_Cat/)
- If building from source: .NET Framework 4.x or .NET SDK

## Installation

1. Locate your Bongo Cat install (typically `Steam\steamapps\common\BongoCat`)
2. Navigate to `BongoCat_Data\Managed\`
3. Back up the original `Assembly-CSharp.dll` (rename to `.dll.bak`)
4. Copy the patched `Assembly-CSharp.dll` from this repo into that folder
5. Launch the game - chests will auto-claim when ready

## Building From Source

1. Back up your original `Assembly-CSharp.dll` as `Assembly-CSharp.dll.bak`
2. Compile and run the patcher:

```bash
csc /r:tool/Mono.Cecil.dll /out:tool/Patcher.exe tool/Patcher.cs
Patcher.exe
```

The patcher reads `Assembly-CSharp.dll.bak`, injects the `Update()` method into `BongoCat.Shop`, and writes the patched `Assembly-CSharp.dll`.

## How It Works

| Component | Purpose |
|-----------|---------|
| `CanGetChest` | Existing property on `Shop` - returns `true` when a chest reward is ready |
| `OnClick()` | Existing method - claims the chest (normally triggered by clicking the UI) |
| `Update()` | Unity lifecycle method called every frame - injected by the patcher to check and auto-claim |

The patcher uses [Mono.Cecil](https://github.com/jbevain/cecil) to manipulate IL directly. It reads the backup DLL in memory, creates a new `Update()` method definition on `BongoCat.Shop`, emits the four IL instructions, and writes the modified assembly.

The original `TimerUpdate()` coroutine is left untouched - the injection is additive.

## Troubleshooting

- **Game updated / patch stopped working** → re-apply. Steam's "Verify integrity of game files" also reverts the DLL.
- **Patcher can't find `Shop` or required methods** → the game may have been updated; check that `BongoCat.Shop`, `get_CanGetChest`, and `OnClick()` still exist.
- **Game won't launch** → restore `Assembly-CSharp.dll.bak`.

## Disclaimer

This mod is for educational purposes. Use at your own risk. Modifying game files may violate terms of service.
