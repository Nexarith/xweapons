# xweapons

A weapon expansion mod for Luanti that introduces two new weapon classes: **Battleaxes** and **Maces**. Each weapon features unique abilities designed for PvP and survival gameplay.

---

## Features

- Battleaxes with a temporary Strength ability
- Maces with unique aerial combat mechanics
- Three mace archetypes: Mobility, Damage, and Control
- Cooldowns with HUD timers
- Particle and status effects
- Multiplayer compatible

---

## Battleaxes

Battleaxes are powerful melee weapons that can temporarily increase their damage output.

### Ability

**Sneak + Right Click**

Activates **Strength** for **10 seconds**.

While Strength is active:

- Deals bonus damage on every hit
- Displays a HUD timer
- Creates a particle trail
- 70-second cooldown

### Battleaxe Tiers

| Material | Damage |
|----------|-------:|
| Wood | 3 |
| Stone | 5 |
| Bronze | 7 |
| Steel | 7 |
| Mese | 8 |
| Diamond | 9 |
| Ember | 11 |

---

## Maces

Maces focus on aerial combat. Their ability launches the player upward, allowing powerful slam attacks against enemies.

### Ability

**Sneak + Right Click**

- Launches the player into the air
- Landing a hit while airborne deals increased damage based on the mace tier and the target's armor
- Missing the attack applies **Fatigue Slowness** for 5 seconds
- 90-second cooldown

---

## Mace Archetypes

### Mobility

- Wood
- Steel
- Bronze

Successful slam attacks knock enemies back.

### Damage

- Gold
- Diamond
- Ember

Higher damage output with a chance to deal additional damage.

**Ember Mace**
- Chance to ignite enemies (requires `fire_plus`).

### Control

- Crystal
- Void

**Crystal Mace**
- Chance to slow enemy movement.

**Void Mace**
- Applies Void Crush, reducing movement speed and preventing jumping for a short duration.

---

## Mace Tiers
| Tier | Archetype | Damage | Launch Boost | Special Ability |
|------|-----------|:------:|:------------:|-----------------|
| Wood | Mobility | 3–4 | +11.0 | Knockback on successful slam |
| Steel | Mobility | 4–6 | +13.0 | Knockback on successful slam |
| Bronze | Mobility | 5–7 | +14.8 | Knockback on successful slam |
| Gold | Damage | 7–9 | +16.5 | Chance to deal bonus damage |
| Diamond | Damage | 9–12 | +19.5 | Chance to deal bonus damage |
| Ember | Damage | 11–14 | +22.0 | Bonus damage + Ignite (`fire_plus`) |
| Crystal | Control | 6–8 | +24.5 | Chance to slow target |
| Void | Control | 5–7 | +28.0 | Void Crush |

---

## Dependencies

### Required

- 3d_armor

### Optional

- fire_plus (for the Ember Mace's burn effect)
- playerphysics (for improved movement modifier compatibility)

---

## Installation

1. Download or clone this repository.
2. Place the `xweapons` folder into your Luanti `mods` directory.
3. Enable the mod in your world.
4. Launch the game.

---

## License

See the repository license for details.

---

## Credits

Created by **Nexarith**.
