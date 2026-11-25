# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### ⚔ QA & Další vylepšení (po nasazení v0.192 + MP v0.9.1-mp2 + Ouroboros)

**Právě nasazeno a ověřeno v headless CI (18/18 skriptů + 9/9 testovacích sad):**
- **🐍 Ouroboros 2D Woodcut Loading Screen (`scripts/ui/snake_loading_screen.gd` + `assets/ui/ouroboros_*.png`):** Ručně kreslený dřevorytový had (zavřená/otevřená tlama s tesáky, šupinaté tělo, ostnatý ocas), 4-fázová choreografie (připlazení → stažení kruhu → 2× chňapnutí s uhnutím ocasu → 3. zakousnutí do Ouroboros pečeti), poletující hořící karty v pozadí, audio `sfx_loading_snake.mp3` + syčení/chňapnutí SFX, skip po 3 s, v headless režimu přeskočen.
- **⚙ Oprava sekání kamery v Nastavení (`scripts/lobby_options_3d.gd` + `scripts/downpour_root.gd`):** Exponenciální tlumení pro pozici i cíl pohledu kamery/světla (`_cam_cur_target`, `_spot_cur_target`), plynulá paralaxa nad knihou, hover debounce + SFX cooldown, lehké aktualizace v `_refresh_options_ui()`.
- **⏳ Časový limit tahu 30–45 s + Auto-Draw (`battle_table_3d.gd`, `mp_config.gd`, `mp_authority.gd`, `mp_battle_table_3d.gd`):** Výchozí 35 s (volitelné `30 / 35 / 45 s` v Nastavení), automatické líznutí po vypršení, diegetický HUD odpočet s eskalací barev a tikáním posledních 5 s.
- **✦ Rework Arzenálu na 8 hlavních relikvií (`lialo_catalog.gd`, `scoring_engine.gd`, `downpour_root.gd`):** 4 deck buildy × 2 signature relikvie (`Guillotine Aces`, `Mirror Monarch`, `Chaos Jester`, `Mistblade Shadow`) + bezpečná migrace starých profilů.
- **🛠 Deck Builder & 4-kartové „Bankai“ Awakening Kombo (`deck_builder_panel.gd`, `bankai_fx.gd`):** Nová vizuální záložka v Arzenálu synchronizovaná pro Kampaň i MP, konfigurace 4-kartové Bankai pečeti + tlačítko živé ukázky, Bleach-style cut-in animace, zvuková znělka, trvalá aura a build-specifické buffy v Kampani i MP.

**Zbývající otevřené úkoly:**
1. **Live Playtest (Kampaň + 2–4P MP přes Radmin VPN / Tailscale / LAN):**
   - Otestovat nový Ouroboros loading screen při startu, plynulost kamery v Nastavení, 30–45 s odpočet tahu + auto-draw, nový Deck Builder & 8 relikvií a spuštění 4-kartového Bankai komba v Kampani i MP.
   - Ověřit MP rematch (`⚔ SEND REMATCH`), `🏛 Return to Lobby (Keep Room)`, 3D portréty MP postav, textový chat v lobby a přepínání atmosféry oken.
2. **Export Windows buildu (`build/windows/LIALO.exe`):** Po finálním playtestu znovu vyexportovat `.exe` (vyžaduje nainstalované Godot 4.7.2 export šablony v `AppData/Roaming/Godot/export_templates/4.7.2.stable/`), aby obsahovalo všechny novinky v0.192, Ouroboros loading screen i 3D portréty + chat v lobby.
