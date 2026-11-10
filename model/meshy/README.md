# Meshy → radar trailer 3D

Run these **on your PC** (needs a Meshy API key from https://www.meshy.ai/).

## Single photo

```bash
export MESHY_API_KEY=msy_your_key_here
./run_meshy_image_to_3d.sh /path/to/trailer_front.png
```

## Multiple angles (better)

```bash
export MESHY_API_KEY=msy_your_key_here
./run_meshy_multi_image.sh front.png side.png back.png
```

Output GLB/OBJ lands in `meshy/output/`.

Then:
1. Import into Blender
2. Scale to ~1.2 m wide
3. Follow Sollumz export steps → `radar_speed_trailer.ydr` + `.ytyp`
4. Drop into `radar_trailer/stream/` and set Config.Model
