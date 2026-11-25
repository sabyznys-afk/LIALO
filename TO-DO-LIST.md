# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### ⚔ QA & Další vylepšení (po nasazení v0.192 + MP v0.9.1-mp2 + Ouroboros)

**Právě nasazeno a ověřeno v headless CI (18/18 skriptů + 9/9 testovacích sad):**
- **🦅 Fujira Studios Intro (`scripts/downpour_root.gd`):** Při startu hry běží čistě jen intro Fujira Studios se znělkou (`sfx_splash_fujara.wav`), zmenšenou horou (`0.78×`) a 3D přilétajícím alpským orlem s mávajícími křídly (místo kamzíků).
- **🐍 Ouroboros 2D Woodcut Loading Screen (`scripts/ui/snake_loading_screen.gd` + `assets/ui/ouroboros_*.png`):** Ultra-detailní `1024×256` dřevorytová textura šupinatého těla (7 řad kýlovitých šupin, hřbetní hřeben, břišní štítky, jizvy) se spojitým UV mapováním; spouští se při každém načítání (vstup do Kampaně, start souboje v Kampani i start Multiplayer zápasu).
- **🔊 Čisté bitevní audio (`downpour_root.gd`, `bankai_fx.gd`, `snake_loading_screen.gd`):** Odstraněny jednoduché opakující se tóny/pípance (`bgm_battle_tavern.wav`, `turn_player`, `error`, `btn_card_tick` a všechny jednoduché procedurální sin-tóny) — v boji hraje pouze komplexní orchestrální/intenzivní hudba (`bgm_battle_calm/epic/intense.mp3`) a plnohodnotné SFX.
- **⚙ Oprava sekání kamery v Nastavení (`scripts/lobby_options_3d.gd` + `scripts/downpour_root.gd`):** Exponenciální tlumení pro pozici i cíl pohledu kamery/světla (`_cam_cur_target`, `_spot_cur_target`), plynulá paralaxa nad knihou, hover debounce + SFX cooldown, lehké aktualizace v `_refresh_options_ui()`.
- **⏳ Časový limit tahu 30–45 s + Auto-Draw (`battle_table_3d.gd`, `mp_config.gd`, `mp_authority.gd`, `mp_battle_table_3d.gd`):** Výchozí 35 s (volitelné `30 / 35 / 45 s` v Nastavení), automatické líznutí po vypršení, diegetický HUD odpočet s eskalací barev a tikáním posledních 5 s.
- **✦ Rework Arzenálu na 8 hlavních relikvií (`lialo_catalog.gd`, `scoring_engine.gd`, `downpour_root.gd`):** 4 deck buildy × 2 signature relikvie (`Guillotine Aces`, `Mirror Monarch`, `Chaos Jester`, `Mistblade Shadow`) + bezpečná migrace starých profilů.
- **🛠 Deck Builder & 4-kartové „Bankai“ Awakening Kombo (`deck_builder_panel.gd`, `bankai_fx.gd`):** Nová vizuální záložka v Arzenálu synchronizovaná pro Kampaň i MP, konfigurace 4-kartové Bankai pečeti + tlačítko živé ukázky, Bleach-style cut-in animace, zvuková znělka, trvalá aura a build-specifické buffy v Kampani i MP.

**Zbývající otevřené úkoly:**
1. **Live Playtest (Kampaň + 2–4P MP přes Radmin VPN / Tailscale / LAN):**
   - Otestovat nový Ouroboros loading screen při startu, plynulost kamery v Nastavení, 30–45 s odpočet tahu + auto-draw, nový Deck Builder & 8 relikvií a spuštění 4-kartového Bankai komba v Kampani i MP.
   - Ověřit MP rematch (`⚔ SEND REMATCH`), `🏛 Return to Lobby (Keep Room)` a přepínání atmosféry oken.
2. **Lobby vizuální doladění:** Přidat 3D/2D portréty MP postav (`CHAR_GUILLOTINE`, `CHAR_MONARCH`, `CHAR_JESTER`, `CHAR_MISTBLADE`) k výběru postav a případně klasické textové pole pro chat vedle rychlých emotů.
3. **Singleplayer test (`tools/verify_battle_redesign.gd`):** Opravit pre-existující selhání 5 assertů u `CinematicDirector` v singleplayeru (`battle_table_3d.gd`).
4. **Export Windows buildu (`build/windows/LIALO.exe`):** Po finálním playtestu znovu vyexportovat `.exe`, aby obsahovalo všechny novinky v0.192 i Ouroboros loading screen.
