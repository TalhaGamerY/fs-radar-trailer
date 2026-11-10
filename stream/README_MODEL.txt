CUSTOM MODEL (finish on your PC)
================================

This folder has the source mesh:
  radar_speed_trailer.obj
  radar_speed_trailer.mtl

FiveM needs binary:
  radar_speed_trailer.ydr
  radar_speed_trailer.ytyp

STEPS (15–30 min):
1. Install Blender 3.6+ and Sollumz addon
   https://github.com/Sollumz/Sollumz

2. File → Import → Wavefront (.obj)
   Select radar_speed_trailer.obj
   If sideways: select all, R X 90 until wheels on ground / solar on top
   Scale so trailer is ~1.2m wide (about player hip height for deck)

3. Select mesh → Sollumz Tools → Convert to Drawable
   Rename root object: radar_speed_trailer  (lowercase)

4. File → Export → Codewalker XML  (or Export RAGE Assets)
   Enable "Export with ytyp"

5. Open CodeWalker → convert .ydr.xml + .ytyp.xml to binary
   OR use Sollumz native export if available

6. Copy into THIS folder:
   stream/radar_speed_trailer.ydr
   stream/radar_speed_trailer.ytyp

7. config.lua:
   Config.Model = `radar_speed_trailer`
   (paste offsets from CONFIG_WHEN_STREAMED.lua)

8. fxmanifest.lua — uncomment:
   data_file 'DLC_ITYP_REQUEST' 'stream/radar_speed_trailer.ytyp'

9. ensure radar_trailer
   /radarcreate

UNTIL THEN: resource uses prop_consign_02a + scripted LED board (fully playable).
