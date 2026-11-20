# Airron's Quest asset license list

Every asset in this repo comes from **Airron's Fall** (Airron Kennedy's own game, repo `airronkennedy/arena-survival-game`)
or is generated from that art by `tools/build_af_assets.py`. Nothing from earlier test builds remains: the old
placeholder sprites, tiles, buildings, UI packs, boss sheet, 3D character renders and the old font were deleted from the repo.
Last reviewed 2026-11-20 (kingdom art pass added).

| Asset | Files | Source | License / ownership |
|---|---|---|---|
| Keeper (hero) sprites, 42 | `assets/af/heroes/*.png` | Airron's Fall `public/assets/heroes/` | Owned by Airron Kennedy (original Airron's Fall art, AI-assisted; see the Airron's Fall ledger) |
| Foe, elite and boss sprites, 17 | `assets/af/foes/*.png` | Airron's Fall `public/assets/foes/`, `ashling/ash-brute/ash-elite.webp`, `final-boss.png` | Owned by Airron Kennedy |
| Area backdrops, grounds, props | `assets/af/areas/*` | Airron's Fall `public/assets/areas/` | Owned by Airron Kennedy |
| Item and ability icons | `assets/af/icons/*` | Airron's Fall `public/assets/icons/` | Owned by Airron Kennedy |
| Title key art, victory/defeat backdrops, app icons, favicon | `assets/af/ui/*` | Airron's Fall `src/assets/title`, `src/assets/screens`, `public/` | Owned by Airron Kennedy |
| Chest prop | `assets/af/props/ember-chest.png` | Airron's Fall | Owned by Airron Kennedy |
| Music ("Vigil of the Silent Stars") | `assets/af/audio/run-theme.mp3` | Airron's Fall `public/assets/run-theme.mp3` (original, synthesized in code) | Owned by Airron Kennedy |
| Generated atlases (terrain, buildings, VFX, UI frames), silhouettes | `assets/af/gen/*`, `assets/af/sil/*` | Made by `tools/build_af_assets.py` from the art above, or drawn in code | Owned by Airron Kennedy |
| Fonts: Cinzel, Rajdhani, Cormorant Garamond | `fonts/*.woff2` | Same subsets Airron's Fall ships | SIL Open Font License 1.1 (commercial use allowed); text in `fonts/OFL-fonts.txt` |
| Kingdom sprites, 53 (Grok sheets): `assets/kingdom/{tree_oak,tree_pine,tree_willow,bush,shrine,cave_mouth,ruin,cairn,well,market_stall,fence,throne,pillar,banner,brazier,barrels}.png` (props sheet); `bld_{store,inn,cottage,townhouse,smithy,chapel,gatehouse,tower,farmhouse}.png` (buildings sheet); `{tuft_tall,tuft_short,flowers_white,flowers_blue,flowers_red,pebbles,boulder,mushrooms,log,stump,reeds,lilypad,lamp_post,signpost,hay_bale,planter}.png` (details sheet); `{window_stained,sconce,armor_stand,candelabra,banquet_table,bookshelf,knight_statue,urn_plant,rug_round,stairs,chandelier,weapon_rack}.png` (castle sheet) | Original. Four sprite sheets generated with Grok Bot's image generator (Grok Imagine) on 2026-11-20 from neutral text prompts (no game, franchise or company names; no third-party images). The only reference images were our own Airron's Fall art (`assets/af/gen/castle_blue.png`, `house_red.png`, `heroes/bramwell.png`) and the first kingdom sheet. Cut by `tools/art/kingdom_cut.py` (chroma key, crop, 3x median downsample, 1 px outline), then re-signed with `tools/art/c2pa_attach.py` (raw sheet = `parentOf`). Raw sheets with their generator C2PA manifests are in `art-src/kingdom/raw/` (Godot-ignored, not shipped) | Owned by the project; AI-assisted. Cleared for commercial release on Steam and iOS (Grok's terms allow commercial use). Credit line "Art created with Grok" is in the kingdom menu. Steam AI disclosure: pre-generated AI content |
| Kingdom ground textures, 10: `assets/kingdom/tiles/{grass,forest_floor,highland,sand,road,cobble,flagstone,wall,cliff,carpet}.png` | Original, generated procedurally by our own script `tools/art/kingdom_tiles.py` (tileable noise and hand-written rules, no source images), 2026-11-20 | Owned by the project. Not AI-generated. Cleared for commercial release |
| Kingdom shaders: `shaders/kingdom_ground.gdshader`, `kingdom_post.gdshader`, `wind_sway.gdshader`, `iris.gdshader` | Original code, 2026-11-20 | Owned by the project |
| Sound effects | none (synthesized in `scripts/sfx.gd`) | Code | Owned by Airron Kennedy |

For the AI-assisted art terms and disclosure wording, follow `docs/ASSET_LICENSES.md` in the Airron's Fall repo.

## No Airron's Fall equivalent yet
- Animated sprite sheets: Airron's Fall art is single-pose, so units bob, lunge and flash instead of playing frame animations.
- Overworld buildings, bridges and terrain edges are generated from Airron's Fall ground and prop art rather than hand-drawn tiles.
