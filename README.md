# export-mode-7-layer
Aseprite script for exporting an SNES Mode 7 layer binary

As described on [page A-11 of the official SNES development manual](https://archive.org/details/SNESDevManual/book1/page/n205), a Mode 7 background layer is a 32KiB (32,768 byte) block of VRAM comprised of the following binary format:

```
byte 0 1 2 3 4 ...
------------------
     n c n c n ...
```
where
- `n` = the NAME (or tilemap) data, each byte referring to an 8x8 tile in the tileset made from the CHR data, ultimately creating a 128x128 tile background; and
- `c` = the CHR (or graphical) data; 8bpp color data where each pixel refers to one color in the 256-color palette in VRAM. This goes line by line _one tile at a time_.

As such, your Aseprite project must meet certain criteria in order to export in said format:
- there must be at least one tilemap layer.
- that layer's tileset must be an 8x8 grid.
- the background NAME (tilemap) layer must be 128 tiles (1,024px) wide.
- 
