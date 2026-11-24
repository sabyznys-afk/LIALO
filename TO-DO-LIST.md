# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### 🐍 Loading screen — Ouroboros had (PŘIPRAVENO, NEIMPLEMENTOVAT bez schválení)

**Stav:** První verze (`scripts/ui/snake_loading_screen.gd`, procedurálně kreslený had z kruhů) byla zamítnuta a **odpojena ze hry**. Skript i audio zůstávají v repu jen jako asset/reference.

**Hotové assety:**
- `assets/audio/sfx_loading_snake.mp3` — znělka loading screenu (prvních 15 s, fade-in/out).
- `assets/audio/bgm_battle_intense.mp3` — celá skladba (66 s), již zapojena jako *climax* vrstva bitevní hudby (intenzivní boj + boss) v `downpour_root.gd`.

**Zadání nové verze:**
1. **Had — detailní, děsivý, ručně kreslený 2D styl** (stejný styl jako 2D animace mečů / ancient kruhů, woodcut/ink linky):
   - Sprite sheet místo procedurálních kruhů: hlava (otevřená tlama, tesáky, rozeklaný jazyk, žhnoucí oči se štěrbinovou zornicí), článkované tělo se šupinami, ocas.
   - Tmavě červená paleta, černé inkoustové obrysy, šrafování, jizvy/staré šupiny.
   - Tělo jako řetěz segmentů (`Line2D`/`Polygon2D` s texturou nebo segmentové sprity) pro plynulé vlnění.
2. **Choreografie:**
   - Had se plíží zespodu/zboku ke středu obrazovky (sinusové vlnění, šustění).
   - Ve středu začne kroužit; kruh se postupně zmenšuje, až hlava dožene ocas.
   - **Ouroboros moment:** had se snaží sežrat vlastní ocas — chňapne (rozevřená tlama, záblesk), ocas uhne, opakuje se 2–3×, nakonec se zakousne a vytvoří uzavřený kruh → kruh se rozzáří a přejde do intra/menu.
3. **Pozadí — animace karet:** pomalu poletující / otáčející se karty (Žaludy, Srdce, Listy, Kule + speciální karty) v ručně kresleném stylu, jemný parallax, občas karta vzplane / rozpadne se do inkoustu; ztmavené, aby nekonkurovaly hadovi.
4. **Zvuk:** `sfx_loading_snake.mp3` (max 15 s) + syčení / chňapnutí jako SFX synchronizované s animací.
5. **Chování:** skip klikem/klávesou po ~3 s, automatický konec po dohrání choreografie, fade do splash screenu; v headless/testech přeskočit.
6. **Ověření:** `tools/verify_ci_headless.gd` musí projít; přidat skript do seznamu kompilace.

---

### ⚔ Multiplayer Overhaul (v0.9.1-mp2) — QA & Další vylepšení

**Co bylo právě nasazeno:**
- 100% Campaign 3D krčma sdílená pro MP (`scripts/battle/tavern_scene_builder.gd` + `mp_battle_table_3d.gd`) včetně klikatelných rekvizit, Suit Astrolabe, `deck_shoe.glb` a battle hudby.
- Opravena kamera klienta (`_built_my_seat`, prázdný avatar u lokálního sedadla — už žádné překrytí ruky s kartami).
- Nový Tavern Multiplayer Hall (`mp_lobby_overlay.gd`, odemčený přímo přes ceduli **VÍCE HRÁČŮ / MULTIPLAYER** v hlavním menu bez dev/experimental bannerů): jiskry & karty v pozadí, Radmin/Tailscale VPN detekce, `MpHistory` (`user://lialo_mp_history.json`) s W–L bilancí a Quick Rematch, 4-slotový stůl, přepínač atmosféry oken, lobby chat, in-session hlasování **⚔ SEND REMATCH** a **🏛 Return to Lobby** bez odpojení.

**Otevřené navazující úkoly:**
1. **Live 2–4P Playtest (Radmin VPN / Tailscale / LAN):** Ověřit v reálném zápase novou Campaign krčmu v MP, čistý pohled klienta bez překryvu kápě, klikatelné rekvizity, přepínání atmosféry oken, tlačítko **⚔ SEND REMATCH** a **🏛 Return to Lobby (Keep Room)** bez odpojení.
2. **Lobby vizuální doladění:** Přidat 3D/2D portréty MP postav (`CHAR_GUILLOTINE`, `CHAR_MONARCH`, `CHAR_JESTER`, `CHAR_MISTBLADE`) k výběru postav a případně klasické textové pole pro chat vedle rychlých emotů.
3. **Singleplayer test (`tools/verify_battle_redesign.gd`):** Opravit pre-existující selhání 5 assertů u `CinematicDirector` v singleplayeru (`battle_table_3d.gd`).
4. **Export Windows buildu (`build/windows/LIALO.exe`):** Po finálním otestování MP znovu vyexportovat `.exe`, aby obsahovalo `v0.9.1-mp2` i nové audio.
