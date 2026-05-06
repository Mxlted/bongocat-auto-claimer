# Bongo Cat Auto Chest Claimer

A lightweight patched `Assembly-CSharp.dll` for Bongo Cat that auto-claims available chests without synthetic mouse input, UI clicking, or per-frame polling.

## What It Does

This patch adds a small scheduled claim tick to `BongoCat.Shop`.

Instead of calling the game's `OnClick()` handler or checking every frame, the patch uses Unity's `InvokeRepeating()` to run a direct claim check every 5 seconds. When a chest is ready and affordable, it calls the game's normal `ShopItem.Buy()` method.

Equivalent C#:

```csharp
private void AutoClaimTick()
{
    if (ChestIsReady && _shopItem != null && _shopItem.CanBuy())
    {
        _shopItem.Buy();
    }
}
```

## Why This Version

The older `TimerUpdate()` patch was stable and claimed quickly, but it changed more of the game's original coroutine logic.

The newer throttled `Update()` patch felt better in Bongo Cat, but it still added a Unity frame callback and used `OnClick()`, which can trigger UI click behavior such as shake animations.

This version keeps the original timer coroutine intact and avoids the click handler entirely:

- No synthetic mouse clicks
- No `OnClick()` auto-claim path
- No per-frame `Update()` polling
- No repeated UI shake/flash attempts while unavailable
- Normal and emote chests are staggered to avoid simultaneous claims

## Behavior

- Normal chest first checks after 1 second
- Emote chest first checks after 2 seconds
- Both shops recheck every 5 seconds
- Claims only when `ChestIsReady` is true
- Claims only when `_shopItem.CanBuy()` is true
- Uses the game's existing `ShopItem.Buy()` flow, including Steam/server handling

## Files

| File | Description |
|------|-------------|
| `Assembly-CSharp.dll` | Patched DLL to copy into Bongo Cat |
| `tools/PatchAutoClaim.ps1` | Mono.Cecil patcher used to inject or refresh the auto-claim logic |
| `.gitignore` | Keeps local reference docs, backups, and downloaded tooling out of commits |

Local backups and reference notes are intentionally not part of the repo.

## Installation

1. Close Bongo Cat.
2. Find the game install folder in Steam.
3. Open `BongoCat_Data\Managed\`.
4. Back up the original `Assembly-CSharp.dll`.
5. Copy this repo's patched `Assembly-CSharp.dll` into `BongoCat_Data\Managed\`.
6. Launch Bongo Cat.

Typical Steam path:

```text
Steam\steamapps\common\BongoCat\BongoCat_Data\Managed\Assembly-CSharp.dll
```

## Re-Patching

If Bongo Cat updates and Steam replaces the DLL, restore or download the new clean `Assembly-CSharp.dll`, place it in this repo, then run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchAutoClaim.ps1
```

Optional timing settings:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchAutoClaim.ps1 -IntervalSeconds 10
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\PatchAutoClaim.ps1 -NormalInitialDelaySeconds 1 -EmoteInitialDelaySeconds 2
```

The patcher expects Mono.Cecil to be available at:

```text
tools\ilspycmd\tools\net10.0\any\Mono.Cecil.dll
```

That downloaded tool folder is ignored so the repository stays small.

## Troubleshooting

- **Game will not launch**: restore your original DLL backup or verify game files through Steam.
- **Patch stopped working after an update**: Steam likely replaced the DLL; re-run the patcher against the new DLL.
- **Claims feel too delayed**: lower `-IntervalSeconds`, but avoid per-frame checking.
- **Mouse still feels odd while gaming**: test with Bongo Cat fully closed as a baseline, since the base game is still a transparent Unity overlay.

## Disclaimer

Use at your own risk. Modifying game files can be overwritten by Steam updates and may violate a game's terms of service.
