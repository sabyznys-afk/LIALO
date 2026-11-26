# LIALO — Sdílený To-Do List (v0.195+)

Sdílený seznam úkolů a poznámek mezi námi v repozitáři.
- Přidávejte nové úkoly nebo vzkazy pro druhého přímo sem.
- **Jakmile je úkol hotový a ověřený, z tohoto souboru ho smažte.**

---

## ★ HLAVNÍ PRIORITA #0: Hand-Drawn 4.2s 1st-Person animace pro zbývající Power Cards (4 / 15 hotovo)

- **Hotové referenční animace (`scripts/battle/power_card_vfx_showcase.gd`):**
  - `SPEC_STORM`, `SPEC_VAMPIRE`, `SPEC_PHOENIX`, `SPEC_CHRONOS` — všechny 4 jsou připnuté nahoře v Lobby Dev Inspectoru (`F9`) v pohledu 1. osoby (~4.2 s, kreslený woodcut inkoustový styl) a zapojené v `BattleTable3D`.
- **Zbývajících 11 Power Cards k dodělání ve stejném 4.2s kresleném 1st-person standardu:**
  1. `SPEC_MIRROR` — praskající 3D zrcadlová brána před soupeřem, zdvojení odrazu zahrané karty.
  2. `SPEC_ALCHEMIST` — zlatý transmutační kruh, bublající alchymistická baňka, zlatý déšť jisker nad rukou.
  3. `SPEC_ORACLE` — obří otvírající se třetí oko nad stolem, runové paprsky odkrývající karty soupeře.
  4. `SPEC_MIDAS` — exploze zlatých mincí a krystalizace soupeřovy strany stolu ve zlato.
  5. `SPEC_JESTER` — chaotický vír karet a masek, zdvojený výboj na všechny relikvie na stole.
  6. `SPEC_HEX` — fialové stíny a inkoustové řetězy svazující soupeře + voodoo jehly.
  7. `SPEC_MAGNET` — magnetický vír přitahující karty z balíčku v zářících obloucích do ruky hráče.
  8. `SPEC_SHIELD` — masivní 3D železná bašta a dva rotující runové štíty obklopující hráče.
  9. `SPEC_GAMBLER` — 3D obří zlaté kostky letící přes stůl s jiskrami multiplikátoru `×2 / ×3`.
  10. `SPEC_PLAGUE` — mrazivá vánice, ledové krystaly vyrůstající kolem soupeře a zamrznutí tahu.
  11. `SPEC_CROWN` — sestoupení levitující zlaté koruny se svatozáří paprů pro každou figuru v ruce.

---

## Kontrola & případné úpravy relikvií (Návrh z v0.195)
- `RelicMeshFactory` a `Catalog.TABLE_RELICS` byly přepracovány na ručně kreslené woodcut 3D stolní relikvie (`Tavern Ale Tankard`, `Loaded Bone Dice`, `Arcane Slate Rune`, `Crimson Blood Goblet`, `Executioner's Whetstone`, `Fate Hourglass`, `Guild Coin Purse`, `Graveyard Toll Bell`, `Alchemist's Ember Censer`, `Phoenix Ember Reliquary`).
- Po kontrole ve hře / v `F9` Dev Inspectoru upravit tvary, barvy nebo efekty podle zpětné vazby.

---

### 🔧 Zbývající build úkol
1. **Export Windows buildu (`build/windows/LIALO.exe`):** Po doladění finálních animací a relikvií vyexportovat `.exe`.
