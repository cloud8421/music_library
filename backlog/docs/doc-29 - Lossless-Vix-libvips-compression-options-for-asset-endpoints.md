---
id: doc-29
title: Lossless Vix/libvips compression options for asset endpoints
type: other
created_date: "2026-05-27 08:28"
tags:
  - research
  - assets
  - vix
  - libvips
  - lossless
---

# Lossless Vix/libvips compression options for asset endpoints

## Scope

This note covers image assets served through `MusicLibraryWeb.AssetController`:

- `/assets/:transform_payload`
- `/public/assets/:transform_payload`
- `/api/v1/assets/:transform_payload`

Static compiled files under `/assets/app.css`, `/assets/app.js`, etc. do not use Vix/libvips. They are served by `Plug.Static`, with gzip enabled in production when code reloading is disabled.

## Current behaviour

`MusicLibrary.Assets.Image` currently writes transformed images with Vix defaults:

```elixir
Image.write_to_buffer(image, ".jpg")
Image.write_to_buffer(image, ".webp")
```

Relevant libvips defaults:

- JPEG output uses lossy JPEG encoding (`Q: 75` by default).
- WebP output is lossy unless `lossless: true` is set.
- Saver metadata defaults keep EXIF, XMP, IPTC, ICC, and other metadata.
- `AssetController.pick_format/1` chooses WebP when the request `Accept` header contains `image/webp`; otherwise it chooses JPEG.

Strictly lossless compression is therefore not possible for all current dynamic asset responses without changing the fallback format strategy, because JPEG saves are inherently lossy.

## Important constraint: resize vs compression

Width transforms use `Operation.thumbnail_buffer/2`, which resamples pixels. Resizing is not bit-for-bit preservation of the original asset. The flags below avoid additional lossy codec compression of the transformed pixels; they do not make resizing itself reversible.

For untransformed assets, serving the original stored bytes is the only bit-for-bit lossless option.

## Useful non-lossy flags

### WebP lossless

Best candidate for browser-targeted lossless compression:

```elixir
Image.write_to_buffer(image, ".webp",
  lossless: true,
  effort: 6,
  keep: [:VIPS_FOREIGN_KEEP_ICC]
)
```

Notes:

- `lossless: true` is the required flag.
- `effort: 6` is the maximum WebP compression effort documented by libvips; it trades CPU time for smaller output.
- `keep: [:VIPS_FOREIGN_KEEP_ICC]` strips EXIF/XMP/IPTC/other metadata while retaining the ICC colour profile. If metadata must also be preserved, omit `keep` or use `[:VIPS_FOREIGN_KEEP_ALL]`.
- Avoid `near-lossless: true`; despite the name, it preprocesses pixels and is not strictly lossless.
- Avoid `target-size`, `mixed`, low `alpha-q`, or lossy WebP presets when strict losslessness is required.

### PNG lossless

Suitable as a strict lossless fallback when WebP is unavailable:

```elixir
Image.write_to_buffer(image, ".png",
  compression: 9,
  filter: [:VIPS_FOREIGN_PNG_FILTER_ALL],
  keep: [:VIPS_FOREIGN_KEEP_ICC]
)
```

Notes:

- `compression: 9` increases DEFLATE effort without changing pixels.
- `filter: [:VIPS_FOREIGN_PNG_FILTER_ALL]` enables adaptive PNG row filters, which are lossless and often reduce size.
- Avoid `palette: true`, lowering `bitdepth`, `Q`, or `dither`; those can quantize or otherwise change pixel data.

### JPEG: only metadata/Huffman optimisation is safe, but the result is still JPEG-lossy

If JPEG output remains necessary, the only useful non-quality-oriented saver option is Huffman table optimisation:

```elixir
Image.write_to_buffer(image, ".jpg",
  "optimize-coding": true,
  keep: [:VIPS_FOREIGN_KEEP_ICC]
)
```

Optional:

```elixir
interlace: true
```

Notes:

- `"optimize-coding": true` computes optimal Huffman tables. It can reduce file size without intentionally changing quality settings.
- `interlace: true` creates progressive JPEGs. This is not inherently lossy, but may increase size for small thumbnails.
- This does not make JPEG output lossless. JPEG encoding remains lossy.
- Avoid changing `Q`, `"subsample-mode"`, `trellis-quant`, `quant-table`, or similar JPEG options for this requirement; they affect quality/compression tradeoffs.

### Thumbnail generation

This avoids upscaling small source images:

```elixir
Operation.thumbnail_buffer(cover_data, size,
  size: :VIPS_SIZE_DOWN
)
```

Notes:

- `:VIPS_SIZE_DOWN` prevents enlargement when the requested width is larger than the source.
- This can reduce bytes and avoid interpolation blur.
- It changes current semantics for requests that ask for a width larger than the stored image.

## AVIF/HEIF note

libvips also exposes `heifsave_buffer/2` with `lossless: true`, and AVIF can be selected by an `.avif` suffix or HEIF compression options. Example shape:

```elixir
Image.write_to_buffer(image, ".avif",
  lossless: true,
  effort: 9,
  keep: [:VIPS_FOREIGN_KEEP_ICC]
)
```

This may be useful later, but it requires adding AVIF negotiation and checking production libvips/libheif codec support. WebP lossless is the safer near-term option.

## Recommendation

For strict non-lossy compression of dynamic image responses:

1. Use lossless WebP for clients that accept WebP.
2. Use PNG as the non-WebP fallback if strict losslessness is required.
3. Do not use JPEG for strict lossless transformed output. JPEG can only be mildly optimised with `"optimize-coding": true`; it remains lossy.
4. Keep ICC metadata unless colour-profile changes are acceptable.
5. Consider `size: :VIPS_SIZE_DOWN` for thumbnails if preventing upscaling is acceptable.

A conservative implementation would add format-specific saver options in `MusicLibrary.Assets.Image`, then change `AssetController.pick_format/1` so the strict-lossless path returns either `image/webp` with `lossless: true` or `image/png`, not JPEG.
