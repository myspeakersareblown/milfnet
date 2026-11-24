# 1 Tap: Game Design (v0.1)

## The pitch

A fast Roblox sniper shooter. Everyone spawns with the same bolt-action sniper and a knife.

- **Headshot = dead.** Always. That's the "1 tap".
- **Body shot = 70.** The target is left on 30 HP, so you finish them with a second shot or a knife slash before they heal.
- **Knife = the rush option.** You run faster with it out, a slash does 50 and a **backstab one-taps**.

**The one rule we never break:** nothing you buy changes damage, accuracy or speed. Robux buys looks only (skins, effects, crates, passes). A fair game keeps players around, and players who stick around are the ones who keep buying skins.

---

## 1. Combat rules

| Thing | Value | Why |
|---|---|---|
| Health | 100 | |
| Sniper headshot | **100** | The 1 tap |
| Sniper body (torso, arms, legs) | **70** | Two body shots kill, and so does a body shot plus a knife slash |
| Knife slash | 50 | 70 + 50 > 100, so it finishes anyone you've tagged |
| Knife backstab | **100** | The knife gets its own 1 tap |
| Health regen | Starts 6 s after your last damage, then 15 HP/s | You get a short window to finish a tagged enemy. Wait too long and they're back to 100 |
| Respawn | 3 s | |
| Spawn protection | 2 s, or until you fire | |

Hats, hair and other accessories **can't be hit**. Shooting someone's hat never counts as a headshot. The server turns accessories off for hit detection when a character spawns.

### Sniper

- Bolt action: 1.1 s between shots, 5-round mag, 2.4 s reload, unlimited reserve ammo.
- Hitscan, so the bullet lands instantly. Bullet drop can come later if we build big maps.
- **Accuracy**
  - No-scope: 7° random cone. Possible, but mostly luck.
  - Scoped: perfect. Scoping in takes 0.2 s and accuracy improves over that time. That gives the game a **quickscope** skill window.
  - Walking adds 2°. Jumping or falling adds 9°.
- **While scoped:** FOV goes from 70 to 20, walk speed drops to 9 and mouse sensitivity drops. The scope comes down after every shot and goes back up after the bolt cycles if you're still holding scope (CS-style).
- A small camera kick on every shot.

### Knife

- Walk speed 20 with the knife out (16 normally).
- Slash: 50 damage, 0.5 s cooldown, 6-stud reach.
- Backstab: 100 damage. The server checks that the target is facing away from you.

### Feedback (this is where the game *feels* good)

- Hitmarker: white for a body shot, red for a headshot, bigger on a kill.
- A big **"1 TAP"** banner on headshot kills and **"BACKSTAB"** on backstabs. Streaks show as "1 TAP x3" and so on.
- Kill feed (top right) with HEADSHOT and BACKSTAB tags.
- Still to add: a headshot "ding" sound, a kill sound, a kill cam, streak announcer lines.

---

## 2. Game modes

| Mode | Players | How you win | Notes |
|---|---|---|---|
| **FFA** | 8–12 | First to 30 kills, or most kills after 6 min | Default mode and the easiest to drop into |
| **Duels** | 1v1 | Best of 9 rounds, one life per round | The competitive core and great for streamers. Ranked comes later |
| TDM | 5v5 | First team to 50 | |
| Headshots Only | any | Body shots do 0 | A weekend event |
| Knife Party | any | Knives only | A fun event |

**Launch with FFA + Duels.** Add the rest as events, since a new mode gives players a reason to come back.

## 3. Maps

- Medium size. Each map gets 2–3 long sightlines (sniper lanes) plus tight corners and flanks so the knife has a place.
- Low-poly or stylized art. It's cheaper to make, it runs on phones, and skins pop against it.
- Launch with 2 maps (ideas: *Rooftops* and *Dockyard*) and pick the next one by vote between rounds.
- Bullets stop on anything with `CanQuery = true`. For decoration bullets should pass through (grass, thin railings), set `CanQuery = false`.

---

## 4. How hits work (and why it's hard to cheat)

1. Your client raycasts from the camera and immediately shows the tracer and hitmarker prediction.
2. It sends the server **what it says it hit**: origin, direction, the part and the position.
3. The server re-checks everything and **calculates the damage itself**:
   - correct weapon equipped, alive, fire rate, ammo and reload (all tracked on the server)
   - the shot starts near your real head position
   - the hit point lies on the aim line and within range
   - the hit point is near where the target's part really is, with tolerance scaled by ping and target speed
   - **no wall in between**: the server casts its own ray between gun and hit point
   - not a teammate, not spawn-protected

This is "favor the shooter": if it looked like a hit on your screen, it counts, as long as it's physically possible. That matters a lot for snipers, because missing a shot you clearly hit is the #1 reason players quit shooters.

**What the client is never trusted with:** damage, ammo, fire rate, currency, crate results, inventory or purchases.

**What the server can't catch:** aimbots, because aim direction always comes from the client. For later:
- Flag statistical outliers (for example a headshot % far above normal at long range across many kills) for **review**. Don't auto-ban on stats alone.
- Server-side speed and teleport checks.
- A report button in the kill cam.

---

## 5. Progression & economy

### Currencies

| Currency | How you get it | What it buys |
|---|---|---|
| **Taps** (free) | Playing: 10 per kill, +5 per headshot, +25 for finishing a match, +50 for a win, daily login, challenges | Standard crates and some shop skins |
| **Gems** (premium) | Robux packs, the season pass, level-up rewards (small amounts) | Premium crates, the featured shop, the season pass |
| **Scrap** | Duplicate skins turn into Scrap | Crafting a skin of your choice |

Rough pacing: an average player gets about 125 Taps per FFA match, so a Standard Crate (750) every ~6 matches (about 35 min). That's enough to feel rewarding without killing Gem sales.

**Taps can never be bought with Robux, directly or through boosts.** That keeps the Taps crate clearly "earned". The VIP boost below applies to XP only for that reason.

### Levels and challenges

- XP from kills, headshots and wins. Your level shows on the leaderboard as a status flex.
- A reward every 5 levels: Taps, a Standard Crate, sometimes a few Gems.
- Daily and weekly challenges ("10 headshots", "3 backstabs", "win 2 Duels") pay Taps and XP. This is the main reason people come back every day.

---

## 6. Cosmetics & crates

### What you can skin

Sniper skins · knife skins · tracer colors · kill effects (confetti, lightning…) · scope reticles · kill sounds · emotes and knife inspect animations · titles and banners.

### Rarities and odds

| Rarity | Color | Standard Crate (750 Taps) | Season Crate (100 Gems) |
|---|---|---|---|
| Common | Grey-blue | 70% | 50% |
| Rare | Blue | 22% | 30% |
| Epic | Purple | 7% | 14% |
| Legendary | Gold | 1% | 5% |
| Mythic | Red | none | 1% |

Rarity is rolled first, then one item from that rarity's pool, each with equal chance. The game shows **exact per-item odds** (`CrateRoller.getOdds`).

### Crate rules

- **Show the odds for every item before anyone buys.** Roblox requires odds disclosure for paid random items (check the current Roblox policy before launch, since these rules change). We show odds on *every* crate, including the free one, because it builds trust.
- **Pity timer:** a Legendary or better is guaranteed at least once every 40 Season Crates.
- **Duplicates turn into Scrap, and Scrap crafts any skin you choose** (priced by rarity). This takes the sting out of bad luck.
- **Region rules:** some countries restrict paid random items. On join, call `PolicyService:GetPolicyInfoForPlayerAsync(player)`. If `ArePaidRandomItemsRestricted` is true, hide Gem crates for that player and show the direct-buy shop instead.
- **Only the server rolls crates.** The client only plays the opening animation for a result the server already decided.
- Rotating **season crates** create urgency. Old crate items stay craftable with Scrap.
- **No trading at launch.** It brings dupes, scams and extra policy checks (`IsPaidItemTradingAllowed`). Revisit after launch.

### How a skin is built in-game

Each skin is a model, mesh or SurfaceAppearance. On spawn, the server builds your Sniper and Knife tools from your equipped skins. Skins never touch the stats in `Config/Weapons.luau`.

---

## 7. Robux monetization

Prices are starting points. Tune them once real data comes in.

### Game passes (buy once)

| Pass | Price | What you get |
|---|---|---|
| **VIP** | 399 R$ | +25% XP (not Taps, see §5), VIP chat tag and name color, an exclusive VIP sniper skin |
| Finisher Pack | 199 R$ | Knife inspect animation + 3 knife finishers |
| Extra Loadouts | 99 R$ | Save 3 cosmetic loadouts and swap between them |

### Developer products (buy again and again)

| Product | Price | Notes |
|---|---|---|
| **Starter Pack** | 99 R$ | **One per account.** 500 Gems + a specific Epic skin. The best-value item in the game, shown after your 3rd match. A cheap great-value first purchase is what turns players into buyers |
| 100 Gems | 49 R$ | |
| 500 Gems | 199 R$ | |
| 1,200 Gems | 449 R$ | "Most popular" tag |
| 2,600 Gems | 899 R$ | "Best value" tag |

### Other income

- **Season Pass** for 950 Gems: about 50 tiers with a free track and a premium track. The premium track pays back around 1,000 Gems over the season, so people buy the next one too.
- **Featured shop** (direct buy, rotates daily): Epic 400 Gems, Legendary 1,200 Gems. This is for people who don't want crates and for players in restricted regions.
- **Private servers** at 100 R$/month. Very popular for Duels with friends.
- **Premium Payouts:** Roblox pays you for the time Premium members spend in your game, so longer sessions mean more Robux with no extra work.

---

## 8. Player data & purchases

- Use **ProfileStore** (by loleris) for player data. Its session locking stops item duplication when people hop between servers. Don't write your own DataStore code for this.
- Data shape:

```lua
{
	Taps = 0, Gems = 0, Scrap = 0,
	XP = 0, Level = 1,
	Inventory = { sniper_desert = true },          -- owned cosmetics
	Equipped = { SniperSkin = "default", KnifeSkin = "default", Tracer = "default" },
	Pity = { Season1Crate = 0 },                   -- crates since last Legendary+
	Stats = { Kills = 0, Deaths = 0, Headshots = 0, Wins = 0 },
	StarterPackBought = false,
	Purchases = {},                                -- recent receipt PurchaseIds (keep the last ~50)
}
```

- **Purchases must be handled in `MarketplaceService.ProcessReceipt`**, and it must be safe to run twice for the same purchase, because Roblox will retry:

```lua
MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and PlayerData.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
	if profile.Data.Purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given, don't double-grant
	end
	local grant = PRODUCTS[receipt.ProductId]
	if not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(profile)
	profile.Data.Purchases[receipt.PurchaseId] = os.time()
	-- Make sure this is saved before confirming (ProfileStore's docs have a receipt example).
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

- Never grant anything from `PromptProductPurchaseFinished`. That's just a UI signal.
- Use **AnalyticsService** to track the funnel: first kill → first crate → shop opened → first purchase. That tells you where players drop off.
- Fill in Roblox's **maturity & compliance questionnaire** before publishing. Keep it gore-free (no blood) so the game stays open to the widest audience.

---

## 9. Controls

| | PC | Mobile | Console |
|---|---|---|---|
| Fire / slash | Left click | Tap the screen | R2 |
| Scope | Hold right click | **Scope** button (toggle) | Hold L2 |
| Reload | R | **Reload** button (it also reloads on empty) | X |
| Swap weapon | 1 / 2 | Hotbar | Hotbar |

More than half of Roblox players are on phones, so mobile can't be an afterthought. Next mobile steps:
- A dedicated fire button
- A **scoped touch sensitivity slider** (the mouse sensitivity setting doesn't affect touch)
- Possibly light "aim friction" for touch and controller only (slowdown, never snapping)

---

## 10. Tech

- **Roblox Studio + Rojo.** The code lives in this repo and Rojo syncs it into Studio live. The map, models and UI art are made in Studio.
- Language: Luau. All tuning numbers live in `src/shared/Config/`.
- See `../README.md` for how to run it.

```
one-tap/
├── default.project.json        Rojo: maps folders into the game
├── src/shared/                 ReplicatedStorage.Shared (server + client)
│   ├── Config/Weapons.luau     sniper & knife stats
│   ├── Config/Combat.luau      health, regen, respawn, anti-cheat tolerances
│   ├── Config/Cosmetics.luau   rarities, skins, crates, odds
│   ├── DamageRules.luau        head = 100, body = 70, knife slash/backstab
│   └── CrateRoller.luau        weighted rolls + pity + odds display (server rolls only)
├── src/server/                 ServerScriptService.Server
│   ├── CombatServer.server.luau   validates every shot/swing, applies damage, kills
│   └── PlayerSetup.server.luau    leaderstats, health, spawn protection, hat hitboxes
├── src/client/                 StarterPlayerScripts.Client
│   ├── WeaponClient.client.luau   input, scope, spread, raycast, reload
│   ├── FeedbackClient.client.luau hitmarkers, kill feed, banners, other players' tracers
│   ├── Hud.luau                   scope overlay, crosshair, ammo, kill feed UI
│   └── Effects.luau               tracers, recoil
└── src/character/Health.server.luau  replaces Roblox's default regen
```

---

## 11. Roadmap

| # | Milestone | What's in it | Status |
|---|---|---|---|
| M0 | **Core combat** | Sniper + knife, 100/70 damage, server validation, scope/spread, reload, hitmarkers, kill feed, leaderstats | ✅ starter code in this repo |
| M1 | Playable prototype | Greybox map, FFA round loop (timer, kill target, end screen, map vote), spawn picking away from enemies | |
| M2 | Feel | Real sniper and knife models, viewmodel arms + animations, sounds, scope reticle art, kill cam, mobile fire button and sensitivity | |
| M3 | Data | ProfileStore, Taps, XP and levels, inventory, loadout screen, skins actually applied to weapons | |
| M4 | Shop | Crate opening (server roll, odds screen, pity, Scrap), Gem products + `ProcessReceipt`, game passes, Starter Pack, `PolicyService` checks | |
| M5 | Launch | Duels mode, 2nd map, anti-cheat hardening, analytics, icon, thumbnails, trailer clip, playtest with friends, publish, run a small sponsor/ad campaign | |
| M6 | Live ops | Season 1 pass + crate, weekly challenges, weekend events (Headshots Only, Knife Party), ranked Duels | |

---

## 12. Open questions (your call)

1. **First person or third person?** The starter is locked first person, since that's the simplest to aim and needs no character animation work. Third-person over-the-shoulder looks better for showing off skins but makes aiming and wall checks harder.
2. **Art style:** low-poly/stylized (recommended) or realistic?
3. **Launch modes:** are FFA + Duels the right pair?
4. **Trading:** wanted eventually? (Recommended: not at launch.)
5. **Team:** solo, or do you have a modeler for weapon skins? Skins are the product, so this decides how fast seasons can ship.
