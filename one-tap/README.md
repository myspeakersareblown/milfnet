# 1 Tap (Roblox)

A sniper-only Roblox shooter. **A headshot always kills, a body shot does 70**, and the knife finishes the job (a backstab one-taps). Crates, skins and Robux purchases are cosmetic only and never change stats.

- **Design doc:** [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- **Every tuning number:** [`src/shared/Config/`](src/shared/Config)

> None of this has been run in Studio yet. Expect to fix a few errors in the Output window on the first playtest.

## What's in the game so far

- **Combat:** a bolt-action sniper (scope, quickscope window, spread when moving or jumping, recoil, reload) and a knife (slash 50, backstab 100). The server double-checks every hit.
- **Rounds:** free-for-all, first to 30 kills or the most kills after 6 minutes. Warmup while waiting for players, a map vote between rounds and a results screen. Players spawn away from enemies.
- **Maps:** three greybox test maps (Yard, Alley, Towers) are generated automatically. Your own maps replace them (see below).
- **Progression:** saved data, XP and levels, Taps for kills, headshots, backstabs and wins, rewards for leveling up, and a level badge on the leaderboard.
- **Cosmetics:** sniper and knife skins (color and material until real models exist), tracer colors (including rainbow), and kill effects (Confetti, Lightning, VIP Crown).
- **Shop (B):**
  - crates with the odds on the card and a full odds list
  - a CS-style opening reel
  - a guaranteed Legendary or better at least every 40 Season crates
  - duplicates turn into Scrap
  - a daily featured shop
  - Gem packs, a one-time Starter Pack and a VIP pass
- **Locker (L):** equip skins, or craft any skin with Scrap.
- **Daily (J):** a 7-day login streak and 3 daily challenges, all rewarded automatically.
- **Settings (K):** scoped mouse sensitivity, field of view, sound volume, and switches for kill effects and other players' tracers.
- **Roblox rules:** crates bought with Gems are hidden in regions that restrict paid random items, and Robux purchases are never granted twice.

## Setup checklist (when you're on PC)

1. **Install Rojo.** The easy way is [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` in `one-tap/`, then `rojo plugin install` to add the Studio plugin.
2. **Sync the code:** run `rojo serve` in `one-tap/`. In Studio, open a new **Baseplate** place, open the Rojo plugin and click **Connect**.
3. **Test alone:** set `minPlayers = 1` in `src/shared/Config/Match.luau`. Otherwise rounds wait for 2 players. Set it back to 2 before you publish.
4. **Target practice:** use **Avatar → Rig Builder → R15** to place dummies. Dummy kills count in the kill feed but give no rewards.
5. **Multiplayer test:** use **Test → Clients and Servers → 2 players**.
6. **Saved data in Studio:**
   1. Publish the place.
   2. Turn on **Game Settings → Security → Enable Studio Access to API Services**.
   Without this, data runs in OFFLINE mode (a warning appears in Output) and nothing saves.
7. **Robux items:**
   1. After publishing, go to the Creator Dashboard → your experience → **Monetization**.
   2. Create the VIP game pass and these developer products: Starter Pack, 100/500/1200/2600 Gems.
   3. Paste their IDs into `src/shared/Config/Products.luau`.
   Test purchases in Studio are free.
8. **Sounds:** paste audio asset IDs into `src/shared/Config/Sounds.luau`. The sniper shot is empty right now, and it matters most.
9. **Your own maps** (optional): put Models in **ServerStorage → Maps**. Each one needs a `Spawns` folder of invisible parts and can have an optional `DisplayName` attribute. The generated maps sit at y = 200 in the sky, so they never overlap your Baseplate.

## Controls

| | PC | Mobile | Console |
|---|---|---|---|
| Fire / slash | Left click | Tap the screen | R2 |
| Scope | Hold right click | Scope button (toggle) | Hold L2 |
| Reload | R | Reload button (also reloads on empty) | X |
| Swap weapon | 1 / 2 | Hotbar | Hotbar |
| Shop / Locker / Daily | B / L / J | Buttons on the left | none yet |
| Settings | K | Button under your profile | none yet |
| Map vote (between rounds) | V frees the mouse, then click | Tap a map | none yet |

## Before you launch

- Set `minPlayers` back to 2.
- Fill in the IDs in Products and Sounds.
- Replace the grey placeholder weapons with real models, and keep `CanQuery = false` on weapon parts.
- Check Roblox's current rules on paid random items (crates) and fill in the maturity questionnaire.
- Make an icon, thumbnails and a short gameplay clip.
