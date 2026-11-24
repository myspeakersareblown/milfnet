# 1 Tap (Roblox)

A sniper-only Roblox shooter. **A headshot always kills, a body shot does 70**, and the knife finishes the job (a backstab one-taps). Cosmetics, crates and Robux purchases are for looks only and never change stats.

- **Design doc (start here):** [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)
- **Tuning numbers:** [`src/shared/Config/`](src/shared/Config)

## Run it in Studio

You need [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/), which syncs the code from this folder into Studio.

1. Install Rojo. The easy way is [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` inside `one-tap/` (it reads `rokit.toml`). Then run `rojo plugin install` to add the Studio plugin.
2. In `one-tap/`, run `rojo serve`.
3. In Studio, open a new **Baseplate** place, open the Rojo plugin and click **Connect**.
4. Build a quick test area: a few big parts as cover and a couple of SpawnLocations. For targets, use **Avatar → Rig Builder → R15** to drop in dummies and practise headshots vs body shots.
5. Press **Play**. For real multiplayer testing, use **Test → Clients and Servers → 2 players**.

## What's in here

| Path | Ends up in | What it does |
|---|---|---|
| `src/shared/Config/` | ReplicatedStorage.Shared.Config | Weapon stats, combat rules, cosmetics + crate odds |
| `src/shared/DamageRules.luau` | ReplicatedStorage.Shared | Head = 100, body = 70, knife slash 50 / backstab 100 |
| `src/shared/CrateRoller.luau` | ReplicatedStorage.Shared | Weighted crate rolls, pity timer, odds display (the server is the only one that rolls) |
| `src/server/` | ServerScriptService.Server | Validates every shot/swing, applies damage, kill feed, leaderstats, spawn protection |
| `src/client/` | StarterPlayerScripts.Client | Input, scope, spread, reload, HUD, tracers, hitmarkers |
| `src/character/Health.server.luau` | StarterCharacterScripts.Health | Replaces Roblox's default regen (no healing until 6 s after taking damage) |

The sniper and knife are placeholder grey parts (`default.project.json`, under StarterPack). Swap in real models later and keep `CanQuery = false` on weapon parts so bullets can't hit guns.
