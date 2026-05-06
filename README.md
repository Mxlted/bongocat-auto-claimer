# Bongo Cat Auto-Claim Chest Mod

A throttled DLL patch for Bongo Cat that auto-claims chests in the background without checking or clicking every frame.

> Working as of May 2026

## What It Does

This patched `Assembly-CSharp.dll` injects a lightweight `Update()` method into `BongoCat.Shop`.

Instead of checking every frame, the mod checks roughly once every 30 seconds. If a chest is ready (`CanGetChest`), it calls the game's existing claim handler (`OnClick()`).

That means chests should be claimed within about a 30-second window, while avoiding the old per-frame loop that could repeatedly trigger UI shake animations while a Steam/server claim was already pending.

Equivalent C#:

```csharp
private float _autoClaimNextCheckAt;

void Update()
{
    float now = Time.realtimeSinceStartup;
    if (now < _autoClaimNextCheckAt)
        return;

    _autoClaimNextCheckAt = now + 30f;

    if (CanGetChest)
        OnClick();
}
```

## Files

| File | Description |
|------|-------------|
| `Assembly-CSharp.dll` | Patched DLL with throttled auto-claim behavior |
| `Assembly-CSharp.dll.pre-throttle.bak` | Backup of the previous modded DLL before the throttle patch |
| `tools/PatchThrottle.ps1` | PowerShell/Mono.Cecil patcher used to add or change the throttle interval |
| `tools/ilspycmd/` | Local ILSpy CLI package used for decompiling and Mono.Cecil patching |

Note: `Assembly-CSharp.dll.pre-throttle.bak` is not guaranteed to be the original Steam DLL. To restore the true original, use Steam's "Verify integrity of game files" or a backup you made before modding.

## Requirements

- [Bongo Cat on Steam](https://store.steampowered.com/app/2324940/Bongo_Cat/)
- PowerShell 7 or Windows PowerShell for re-running the throttle patcher
- .NET runtime for ILSpy/Mono.Cecil tooling already downloaded under `tools/ilspycmd/`

## Installation

1. Close Bongo Cat.
2. Locate your Bongo Cat install, typically under a Steam library folder.
3. Navigate to `BongoCat_Data\Managed\`.
4. Back up the original `Assembly-CSharp.dll` if you have not already.
5. Copy this folder's patched `Assembly-CSharp.dll` into `BongoCat_Data\Managed\`.
6. Launch the game.

## Changing the Claim Interval

The current interval is 30 seconds. To change it, run the patch script from this repository:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchThrottle.ps1 -IntervalSeconds 45
```

Run that command from the `bongocat-auto-claimer` directory, or pass `-AssemblyPath` if patching a DLL elsewhere.

Examples:

```powershell
# Check every 60 seconds
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchThrottle.ps1 -IntervalSeconds 60

# Patch a DLL inside the Steam install directly
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchThrottle.ps1 -AssemblyPath "C:\Path\To\BongoCat_Data\Managed\Assembly-CSharp.dll" -IntervalSeconds 30
```

## How It Works

| Component | Purpose |
|-----------|---------|
| `CanGetChest` | Existing property on `BongoCat.Shop`; returns `true` when a chest reward is ready and affordable |
| `OnClick()` | Existing game method that claims the chest through the normal UI purchase flow |
| `_autoClaimNextCheckAt` | Injected private float storing the next allowed check time |
| `Update()` | Injected Unity lifecycle method; exits immediately until the throttle window expires |

The original `TimerUpdate()` coroutine is left untouched. The patch is additive and only changes the injected auto-claim behavior.

## Background Load Notes

For the lowest background impact while gaming:

- Keep Bongo Cat's `Cat Bobbing` setting off.
- Keep `Always Show Chest` off if you do not need the chest UI visible.
- Use the throttled DLL instead of the older per-frame auto-claim DLL.

Bongo Cat still runs as a transparent Unity overlay and uses window/input hooks as part of the base game, so it remains worth testing with and without the app if you are isolating display or GPU crashes.

## Troubleshooting

- **Game updated / patch stopped working**: Steam may have replaced the DLL. Re-copy the patched DLL or re-run the patcher against the new one.
- **Game won't launch**: restore the original DLL or use Steam's "Verify integrity of game files."
- **Claiming is too slow**: lower `-IntervalSeconds`, but avoid going back to per-frame checks.
- **Still seeing background load**: turn off constant-rendering options in Bongo Cat and test with the app closed during GPU/display troubleshooting.

## Disclaimer

Use at your own risk. Modifying game files may violate the game's terms of service and Steam updates may overwrite the patched DLL.
