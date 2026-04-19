# Bongo Cat Auto Chest Claimer

Patches Bongo Cat's `Shop.TimerUpdate()` coroutine to auto-claim chests and emote chests shortly after they become available.

> Working as of April 2026

## Requirements
- [dnSpy](https://github.com/dnSpy/dnSpy) (64-bit .NET)
- Bongo Cat on Steam

## How to Apply
1. **Back up** `Steam\steamapps\common\BongoCat\BongoCat_Data\Managed\Assembly-CSharp.dll` first
2. Open the DLL in dnSpy
3. Navigate to `Assembly-CSharp.dll → BongoCat → Shop → TimerUpdate()`
4. Right-click → **Edit Method (C#)**
5. Replace the entire method with the code below
6. **File → Save Module → OK** and replace the original DLL

## Method

```csharp
using System;
using System.Collections;
using System.Collections.Generic;
using BongoCat.Multiplayer;
using Steamworks;
using TMPro;
using UnityEngine;
using Vfx;

namespace BongoCat
{
	// Token: 0x0200012A RID: 298
	public partial class Shop : MonoBehaviour
	{
		// Token: 0x0600061E RID: 1566 RVA: 0x000059FD File Offset: 0x00003BFD
		private IEnumerator TimerUpdate()
		{
			for (;;)
			{
				if (this._outOfStockObj.activeSelf)
				{
					this.StockRefreshTimeLeft--;
					PlayerPrefs.SetInt(this._shopTimeKey, this.StockRefreshTimeLeft);
					this._stockRefreshText.text = string.Format("{0:mm':'ss}", TimeSpan.FromSeconds((double)this.StockRefreshTimeLeft));
					SteamItemDetails_t steamItemDetails_t = this._isEmoteShop ? CatInventory.Instance.EmoteChestToken : CatInventory.Instance.ChestToken;
					if (this.StockRefreshTimeLeft <= 0)
					{
						if (steamItemDetails_t.m_unQuantity == 0)
						{
							this.StockRefreshTimeLeft = 60;
						}
						else
						{
							this.StockRefreshTimeLeft = 0;
							this._shopItem.gameObject.SetActive(true);
							this._outOfStockObj.SetActive(false);
							this.ChestIsReady = true;
							if (this._showChestPopup.Value && this._shopItem.CanBuy())
							{
								if (!this._isEmoteShop)
								{
									SteamMultiplayer.Instance.SendChestReady(this.ChestIsReady);
								}
								this._shopVisuals.SetActive(true);
								float seconds = this._isEmoteShop ? 2f : 1f;
								yield return new WaitForSeconds(seconds);
								while (!this._shopItem.CanBuy())
								{
									yield return new WaitForSecondsRealtime(60f);
								}
								this._shopItem.Buy();
							}
						}
					}
				}
				else if (this.StockRefreshTimeLeft <= 0 && !this._shopVisuals.activeInHierarchy && this._showChestPopup.Value && this._shopItem.CanBuy())
				{
					if (!this._isEmoteShop)
					{
						SteamMultiplayer.Instance.SendChestReady(this.ChestIsReady);
					}
					this._shopVisuals.SetActive(true);
				}
				yield return new WaitForSecondsRealtime(1f);
			}
			yield break;
		}
	}
}
```

## Behavior
- Normal chest claims **1 second** after becoming available
- Emote chest claims **2 seconds** after (staggered to avoid simultaneous claims)
- If no token is in inventory (`m_unQuantity == 0`), the timer resets to 60s
- If you can't afford the chest when ready, the claimer rechecks every 60s until you can
  - Caveat: if you start a session already under 1000 points, you may need to claim manually once you're back above the threshold
- The chest popup stays visible while waiting

## Troubleshooting
- **dnSpy compile errors** → game probably updated; check that `Shop`, `ShopItem.CanBuy()`, and `ShopItem.Buy()` still exist with matching signatures
- **Game won't launch** → restore your backup DLL
- **Patch disappeared after a game update** → reapply; Steam's "Verify integrity of game files" also reverts it
