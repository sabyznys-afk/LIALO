# LIALO — Sdílený To-Do List

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## Otevřené úkoly

### Progresivní odemykání speciálních karet a relikvií (Kampaň -> Multiplayer)

Cíl: hráč postupně získává speciální karty (`SPEC_*`), pasivní relikvie (`REL_*`) a 3D stolní relikvie (`TRELIC_*`) průchodem kampaně i nákupy v krčmovém obchodě a poté si svou odemčenou sbírku skládá do osobního balíčku v multiplayeru.

- [ ] **Fáze 1 — Trvalá kolekce a žebříček odemykání přes 5 ér** (`scripts/lialo_catalog.gd`)
  - Oddělit trvalou meta-kolekci (`unlocked_power_cards`, `unlocked_relics`, `unlocked_table_relics`, `mp_loadout`) od inventáře konkrétního runu v `lialo_profile.cfg`, zachovat zpětnou migraci stávajících savů a omezit čerstvý profil na startovní sadu (`SPEC_ORACLE`, `SPEC_HEX`, `REL_GREED`, `TRELIC_GOLD_SCALES`).
  - Zavést deterministický žebříček `CAMPAIGN_UNLOCK_LADDER` napříč všemi 5 érami × 3 stádii (`antika`, `rim`, `stredovek`, `objavy`, `prohibicia` až po mytický `SPEC_CHRONOS`) + pomocné funkce `unlock_power_card()`, `unlock_relic()`, `unlock_table_relic()`, `get_unlock_source_label()` a `claim_stage_unlocks()`.

- [ ] **Fáze 2 — Kampaňové odemykání, obchod a odznaky v Arzenálu** (`scripts/downpour_root.gd`)
  - V `_on_match_won_details()` přidělovat odemknutí za vyhrané stádium (případně objevitelský hod při opakování vyčištěné éry) a zobrazit ve shrnutí vítězství nový pruh **"NEW UNLOCK — USABLE IN CAMPAIGN & MULTIPLAYER"**.
  - Filtrovat nabídku obchodu v `Catalog.generate_shop_offers()` podle dosažené éry (`reached Eras + 1`) a při koupi v `_buy_shop_offer()` položku natrvalo odemknout i pro multiplayer.
  - V obrazovce Arzenál / Kolekce označit všechny `SPEC_*`, `REL_*` a `TRELIC_*` stavem **Unlocked (MP Ready)** nebo **Locked** s popiskem, jaká éra/boss je odemyká.

- [ ] **Fáze 3 — Multiplayerový Campaign Vault Loadout a pravidla férovosti** (`scripts/mp/mp_lobby_overlay.gd`, `scripts/mp/mp_config.gd`, `scripts/mp/mp_network.gd`, `scripts/mp/mp_dev_entry.gd`)
  - V lobby přidat výběr **"Campaign Vault Loadout"** nad kampaňovým profilem: až **3× Special Card (`SPEC_*`, max 1 Mythic)**, **2× 3D Tabletop Relic (`TRELIC_*`)** a **2× Passive Relic (`REL_*`)** + automatický přenos `equipped_sword` z kampaně a uložení do `mp_loadout`.
  - Přidat přepínač pravidel hostitele mezi **`Campaign Vault`** (vlastní odemčené karty a relikvie v rámci limitu 3/2/2) a **`Balanced Arena`** (rovné přednastavené sady pro nováčky).
  - Na hostiteli i síťové vrstvě (`MpNetwork`) validovat a čistit příchozí `deck_cfg` podle slotových limitů a zobrazovat vybavené položky u jednotlivých sedadel.

- [ ] **Fáze 4 — Plné spouštění všech 15 `SPEC_*`, 10 `TRELIC_*` a pasivních `REL_*` v multiplayeru** (`scripts/mp/mp_authority.gd`, `scripts/mp/mp_battle_table_3d.gd`, `scripts/mp/mp_config.gd`)
  - Doplnit `MpConfig.build_custom_deck()` a rozšířit `MpAuthority._apply_power_card_effect()` o zbývajících 9 `SPEC_*` karet (`SPEC_MIRROR`, `SPEC_ALCHEMIST`, `SPEC_PHOENIX`, `SPEC_MIDAS`, `SPEC_MAGNET`, `SPEC_SHIELD`, `SPEC_GAMBLER`, `SPEC_PLAGUE`, `SPEC_CROWN`).
  - Sjednotit `MpConfig.get_mp_item_info()`, spawnovat v `MpBattleTable3D` všech 10 kampaňových `TRELIC_*` přes `RelicMesh.create_relic_node()` (s animacemi a rozbitím po 3 použitích) a napojit jejich herní efekty v `MpAuthority.handle_use_item()`.
  - Předávat `passive_relics` do `ScoreEng.calculate_hand_score()` (s MP stropem násobitele) a napojit jejich pasivní bojové efekty (`REL_IRON_BOOT`, `REL_FANG`, `REL_HEX_DOLL`, `REL_GREED`).

- [ ] **Fáze 5 — Automatizované headless ověření** (`tools/verify_progression_mp.gd`)
  - Ověřit startovní sadu čerstvého profilu, migraci staršího savu, deterministické odemykání z kampaně i obchodu, slotové zámky v `MpLobbyOverlay`, sanitizaci v `MpAuthority` a exekuci všech 15 `SPEC_*`, 10 `TRELIC_*` a `REL_*` efektů bez chyb.
