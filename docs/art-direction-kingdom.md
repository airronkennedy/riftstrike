# Art direction: Emberhold kingdom (town, castle, overworld)

## Reference study (technique and mood only)
- **What "FF Resonance" is:** *Final Fantasy Resonance* (Square Enix / Lancarse, released Oct 22, 2026). It's the series' first "HD-2D" game: pixel-art sprites and pixel textures in a 3D-lit world, with "dynamic camera angles", tilt-shift depth of field, bloom and turn-based battles. Sources: the Steam page and the Square Enix press release.
- **The wider look we're after:** modern pixel turn-based games in the same vein (HD-2D titles; also *Sea of Stars* and *Chained Echoes* for top-down 2D). They share these techniques:
  - depth from blur and parallax
  - strong warm and cool light with glow
  - dense hand-placed clutter
  - living water and foliage
  - per-area colour moods
  - soft shadows
  - small ambient life
  - ornate but readable UI frames
- **The IP rule:** these references inform technique and mood only.
  - Never copy, trace or prompt with any franchise's characters, names, logos or art.
  - Never put game or company names in image prompts.
  - Every asset here is original or Grok-generated from neutral text prompts plus our own Airron's Fall art as the style reference.

## Techniques and where they live
| Technique | Our version | File |
|---|---|---|
| Tilt-shift depth of field | The screen's top and bottom bands blur (12-tap) and the middle band stays sharp. UI is on a higher layer, so it stays crisp | `shaders/kingdom_post.gdshader` |
| Bloom / glow | A cheap bright-pass glow on windows, fires and candles, folded into the same post pass (Compatibility renderer, so no WorldEnvironment glow) | `kingdom_post.gdshader` |
| God rays | Slanted, slowly drifting light shafts, with strength per area (strongest in the castle and Gloamwood) | `kingdom_post.gdshader` (`rays`) |
| Colour grading per area | Tint, saturation, contrast and warmth, plus a CanvasModulate tint and torch strength. Gloamwood blends in its own grade while you walk through it | `KingdomMaps.GRADES`, `_blend_grade()` |
| Rich dynamic lighting | PointLight2D on the hero's torch, braziers, lamp posts, sconces, candelabras and stained windows, with gentle flicker. Dark CanvasModulate indoors so lights read | `kingdom.gd` `_add_light()` |
| Layered parallax and foreground occluders | Darkened tree canopies (town and overworld) and chandeliers (castle) drawn in front of the world. They move faster than the camera and fade when over the hero | `KingdomView.Foreground` |
| Dense hand-placed detail | Seeded per-tile scatter of tufts, wildflowers, pebbles, mushrooms, stumps, bushes, reeds and lily pads, plus hand-placed props (stalls, wells, lamps, fences, barrels, planters, hay) | `_scatter_details()`, map `props` |
| Water shimmer and animated tiles | Depth tint from distance to land, moving sparkle, animated shoreline foam and wet sand at the waterline | `shaders/kingdom_ground.gdshader` |
| Terrain polish | Tileable pixel textures with noisy, pixel-stepped borders between grass, forest, highland, sand and road; lit cliff and wall faces with a contact shadow below; slow cloud shadows outdoors | `kingdom_ground.gdshader`, `assets/kingdom/tiles` |
| Wind sway | A vertex shader bends the tops of trees, bushes, grass, flowers, reeds and banners | `shaders/wind_sway.gdshader` |
| Soft drop shadows | Stacked ellipses pushed toward the lower right (key light from upper left) under every actor and prop | `KingdomView.soft_shadow()` |
| Ambient life | Butterflies near flowers, fireflies in Gloamwood, a bird flock with ground shadows, chimney smoke, embers, dust and motes | `KingdomView.Life`, `_add_smoke()`, `_setup_particles()` |
| Dialog and banner UI in the Airron's Fall style | Carved AF frame, speaker portrait, typewriter text (tap to finish), a bouncing gold arrow, and a Cinzel area banner with gold rules and an ember diamond | `kingdom.gd` `_open_dialog()`, `KingdomView.Ornament` |

## Reduced motion
The menu toggle or `?calm=1` freezes water, foam, clouds, god-ray drift and sway (`motion = 0`). It also hides particles, smoke and ambient life, stops light flicker, idle bob and camera look-ahead, uses a fade instead of the iris, and shows text instantly. Blur, grading and lighting stay, because they don't move.

## Style rules for new kingdom art
- Same look as `assets/af`:
  - chunky pixel art with a dark 1 px outline
  - warm ash-brown and stone with mossy desaturated greens
  - ember orange and gold accents
  - 3/4 top-down view
- Generate in batches as sheets: a grid on a flat magenta key, with our AF sprites or an earlier kingdom sheet as the style reference. Then cut the sheets with `tools/art/kingdom_cut.py`, re-sign them with `tools/art/c2pa_attach.py`, and add a row to `docs/ASSET_LICENSES.md`.
