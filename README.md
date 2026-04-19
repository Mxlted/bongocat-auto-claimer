# Bongo Cat Auto Chest Claimer
Auto-claims Bongo Cat chests via a DLL patch.
> Working as of March 2026

## Requirements
- [dnSpy](https://github.com/dnSpy/dnSpy) (64-bit .NET)
- Bongo Cat on Steam

## How to Apply
1. Open `Steam\steamapps\common\BongoCat\BongoCat_Data\Managed\Assembly-CSharp.dll` in dnSpy
2. Navigate to `Assembly-CSharp.dll → BongoCat → Shop → TimerUpdate()`
3. Right-click → **Edit Method (C#)**
4. Replace the entire method with the code below
5. **File → Save Module → OK** and replace the original DLL

## Method

```csharp
private IEnumerator TimerUpdate()
{
    for (;;)
    {
        if (this._outOfStockObj.activeSelf)
        {
            this.StockRefreshTimeLeft--;
            PlayerPrefs.SetInt(this._shopTimeKey, this.StockRefreshTimeLeft);
            this._stockRefreshText.text = string.Format("{0:mm':'ss}", TimeSpan.FromSeconds((double)this.StockRefreshTimeLeft));

            SteamItemDetails_t chestToken = this._isEmoteShop
                ? CatInventory.Instance.EmoteChestToken
                : CatInventory.Instance.ChestToken;

            if (this.StockRefreshTimeLeft <= 0)
            {
                if (chestToken.m_unQuantity == 0)
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
                            SteamMultiplayer.Instance.SendChestReady(this.ChestIsReady);

                        this._shopVisuals.SetActive(true);

                        // Emote chest waits 2s, normal chest waits 1s
                        float claimDelay = this._isEmoteShop ? 2f : 1f;
                        yield return new WaitForSeconds(claimDelay);

                        // Keep checking every 60s until the player can afford it
                        while (!this._shopItem.CanBuy())
                            yield return new WaitForSecondsRealtime(60f);

                        this._shopItem.Buy();
                    }
                }
            }
        }
        else if (this.StockRefreshTimeLeft <= 0 && !this._shopVisuals.activeInHierarchy
              && this._showChestPopup.Value && this._shopItem.CanBuy())
        {
            if (!this._isEmoteShop)
                SteamMultiplayer.Instance.SendChestReady(this.ChestIsReady);

            this._shopVisuals.SetActive(true);
        }

        yield return new WaitForSecondsRealtime(1f);
    }
}
```

## Notes
- Normal chest claims after **1 second**, emote chest claims after **2 seconds** - a 1 second stagger to avoid simultaneous claims
- If no token is in inventory (`m_unQuantity == 0`) the timer resets to 60 seconds and checks again
- If you have fewer than 1000 points when the chest is ready, the claimer will re-check every 60 seconds until you have enough and then buy automatically - however if you start a session already under 1000 points you may need to claim the chest manually once you reach 1000
- The chest popup stays visible while waiting for enough points
- If the game updates, find the new `TimerUpdate()` in dnSpy and reapply
