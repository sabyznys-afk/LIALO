# Sem vkladaj ručne kreslené assety z grafického tabletu (.png)

Engine `BattleTable3D` v Godote automaticky hľadá a načíta tvoje kresby z týchto ciest (ak súbor ešte neexistuje, použije čistý 3D placeholder):

1. **Karty (`D:\downpour-godot\assets\cards\`)** — rozmer napr. `500 × 700 px` (`.png`):
   - Formát názvu: `<FARBA>_<HODNOTA>.png`
   - Farby: `CERVEN`, `ZELEN`, `ZALUD`, `GULA`
   - Hodnoty: `7`, `8`, `9`, `10`, `D` (Dolník), `H` (Horník), `K` (Kráľ), `E` (Eso)
   - Príklady:
     - `CERVEN_7.png` (Červená Sedma)
     - `GULA_8.png` (Guľová Osmička)
     - `ZELEN_E.png` (Zelené Eso)

2. **Stôl (`D:\downpour-godot\assets\table\`)**:
   - `wood.png` — textúra drevenej dosky 3D stola.

3. **Rukavice / Skiny rúk (`D:\downpour-godot\assets\gloves\`)**:
   - Textúry alebo 2D/3D modely rukavíc pre jednotlivé historické sady (`pirati.png`, `stredovek.png`, `mafia.png`...).
