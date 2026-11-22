# LIALO — Fujara Studios

**Historical Prší Roguelike & Deckbuilder by Fujara Studios** (Godot Engine 4.7+, GL Compatibility).

---

## Unified King-Style 2D Hand-Drawn Sword Card Animation System

All played cards in **LIALO** — across **Single-Player (Player & AI Rival/Boss)**, **Special (`SPEC_*`) Cards**, **all card ranks (`7, 8, 9, 10, D, H, K, E`)**, **all editions (`NORMAL, KNIGHT, MAGE, THIEF, MERCHANT`)**, and **4-Player Multiplayer** — use the unified 3D world-space **2D hand-drawn King Sword animation** (`SwordCardAnimator`).

### How It Works
- **`scripts/sword_card_animator.gd` (`SwordCardAnimator`)** drives a 4-beat physical diorama rig (`_SwordVfxRig`) over `BattleTable3D` / `MpBattleTable3D` using dual-sided (`cull_disabled`) quads so every seat sees the animation cleanly:
  1. **Beat 1 (`0.00s – 0.20s`)**: Mist-unsheathe rise & shoulder wind-up with blade sheen sweep.
  2. **Beat 2 (`0.20s – 0.32s`)**: Tip-first arc whip cleave + `45ms` Sakuga hitstop flash + table camera punch.
  3. **Beat 3 (`0.32s – 0.80s`)**: Blade planted into carved table rune sigils (`ImpactSigilOuter` / `ImpactSigilInner`) with steel vibration, crossed cel slash arcs (`SlashCanopy`, `SlashCross`, `SlashFeltSkim`), ink sparks, and diegetic energy orbs flying to the scoring side.
  4. **Beat 4 (`0.80s – 1.26s`)**: Organic woodcut ink/mist erosion dissolve.
- **Palettes & Blades**:
  - **King Royal Sword (`sword_blade_royal.png`, `is_knight_mist = false`)** is the default for all cards (`NORMAL`, `MERCHANT`, `MAGE`, `THIEF`, `SPEC_*`, and `K` King cards), with `royal_shift = 1.0` and tailored glow/mist tinting by edition, suit (`CERVEN`, `GULA`, `ZELEN`, `ZALUD`), or special card accent.
  - **Mistblade (`sword_blade_mist.png`)** is preserved for `KNIGHT` edition cards (`edition == "KNIGHT"` or `is_knight_mist = true`).
- **Shaders & Sprite Sheets**:
  - `shaders/sword_blade_cutout.gdshader` — 12 fps hand-drawn line boil, rune glow, sheen sweep, and organic mist dissolve.
  - `shaders/sword_cel_sprite.gdshader` — cel sprite-sheet animator (`grid_size`, `frame_index`, `royal_shift`, woodcut grain, ink preservation).
  - `assets/vfx/sword_card/` — `sword_blade_royal.png`, `sword_blade_mist.png`, `slash_cel_sheet.png`, `mist_veil_sheet.png`, `impact_sigil_sheet.png`, `ink_sparks_sheet.png`.
  - `assets/audio/` — `sfx_anim_sword_unsheathe.mp3`, `sfx_anim_sword_slash.mp3` (with procedural WAV fallback).

### Card Play Integration Points
- `scripts/blender_vfx_animator.gd`: `BlenderVfxAnimator.play_card_effect_anim(...)` delegates directly to `SwordCardAnimator.play_sword_card_score_anim(...)`.
- `scripts/battle_table_3d.gd`: `_spawn_signature_play_vfx(...)`, `_execute_balatro_stagger_timeline(...)`, `_play_selected_cards_3d(...)`, `_run_ai_turn_3d(...)`, and `_run_rival_turn_with_cinematic(...)` run the tabletop card slam + 2D hand-drawn sword cleave for all player, special, and rival cards.
- `scripts/cinematic_director.gd`: `_trigger_tybw_climax_fx()` also spawns a `SwordCardAnimator` strike at climax impact when invoked directly.
- `scripts/mp/mp_authority.gd` & `scripts/mp/mp_battle_table_3d.gd`: Every multiplayer `CARD_PLAY` emits `has_sword = true` and plays `SwordCardAnimator.play_sword_card_mp_strike(...)`.

---

## Setup & Running Instructions (English)

### Prerequisites
- **Godot Engine 4.7+** (verified on **Godot Engine v4.7.2.stable**, `gl_compatibility` renderer, `1366×768` viewport, main scene `res://scenes/main.tscn`).
- Windows (or Linux/macOS with Godot 4.7+ installed on your `PATH`).

### 1. Clone the Repository
```bash
git clone https://github.com/sabyznys-afk/LIALO.git
cd LIALO
```

### 2. Run the Game
- **Quick Launch (Windows):** Double-click `Spusti_Hru.bat` (adjust the `Godot.exe` path inside the `.bat` if your Godot binary is not at `C:\Users\arnos\Godot\Godot.exe`).
- **Command Line:**
  ```bash
  "C:\Users\arnos\Godot\Godot.exe" --path .
  ```

### 3. Open in Godot Editor
- **Quick Open (Windows):** Double-click `Otvor_Godot_Editor.bat`.
- **Command Line:**
  ```bash
  "C:\Users\arnos\Godot\Godot.exe" -e --path .
  ```

### 4. Export a Release Build (Windows Desktop)
- **Quick Export:** Double-click `Exportuj_Hru.bat` (outputs to `build/windows/LIALO.exe`, using `export_presets.cfg`).
- **Command Line:**
  ```bash
  "C:\Users\arnos\Godot\Godot.exe" --headless --export-release "Windows Desktop" "build/windows/LIALO.exe" --path .
  ```

### 5. Run Headless Verification Suites
```bash
"C:\Users\arnos\Godot\Godot.exe" --headless --path . -s "res://tools/verify_blender_vfx.gd"
"C:\Users\arnos\Godot\Godot.exe" --headless --path . -s "res://tools/verify_cinematic_system.gd"
```

### 6. Customizing the 2D Sword Card Animation
- **Swap or edit hand-drawn artwork:** Replace the PNGs in `assets/vfx/sword_card/` (`sword_blade_royal.png`, `slash_cel_sheet.png`, `impact_sigil_sheet.png`, `mist_veil_sheet.png`, `ink_sparks_sheet.png`), keeping the same sprite-sheet grid dimensions (`6×4` for slash, `4×4` for mist/sigil/sparks).
- **Adjust timing, scale, or colors:** Edit `TOTAL_DUR`, `_update_sword_blade`, `_update_slashes`, and the palette block in `_SwordVfxRig.configure` inside `scripts/sword_card_animator.gd`.

---

## Návod na spustenie a úpravu (SK / CZ)

### Požiadavky
- **Godot Engine 4.7+** (overené na **Godot Engine v4.7.2.stable**, `gl_compatibility` renderer).

### Klonovanie, spustenie a export
1. Naklonujte repozitár:
   ```bash
   git clone https://github.com/sabyznys-afk/LIALO.git
   cd LIALO
   ```
2. **Spustenie hry:** Spustite `Spusti_Hru.bat` (prípadne upravte cestu k `Godot.exe` v `.bat` súbore, ak máte Godot inde než v `C:\Users\arnos\Godot\Godot.exe`).
3. **Otvorenie v editore:** Spustite `Otvor_Godot_Editor.bat`.
4. **Export pre Windows:** Spustite `Exportuj_Hru.bat` (výstup sa vytvorí v `build/windows/LIALO.exe`).
5. **Úprava 2D kreslenej animácie meča:**
   - Kreslené sprite sheety a čepele sa nachádzajú v `assets/vfx/sword_card/`.
   - Logika animácie, časovanie 4 fáz (tasenie, seknutie s hitstopom, zabodnutie s runami a rozplynutie v atramente) a farebné palety pre jednotlivé karty/farby sú v `scripts/sword_card_animator.gd`.
