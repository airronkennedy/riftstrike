# Airron's Quest asset license list

Every asset in this repo comes from **Airron's Fall** (Airron Kennedy's own game, repo `airronkennedy/arena-survival-game`)
or is generated from that art by `tools/build_af_assets.py`. Nothing from earlier test builds remains: the old
placeholder sprites, tiles, buildings, UI packs, boss sheet, 3D character renders and the old font were deleted from the repo.
Last reviewed 2026-11-20.

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
| Sound effects | none (synthesized in `scripts/sfx.gd`) | Code | Owned by Airron Kennedy |

For the AI-assisted art terms and disclosure wording, follow `docs/ASSET_LICENSES.md` in the Airron's Fall repo.

## No Airron's Fall equivalent yet
- Animated sprite sheets: Airron's Fall art is single-pose, so units bob, lunge and flash instead of playing frame animations.
- Overworld buildings, bridges and terrain edges are generated from Airron's Fall ground and prop art rather than hand-drawn tiles.
