# Changelog

## [Unreleased]

### Security

- Block libvips loaders that are unsafe for untrusted content by default on the
  libvips backend (`Vips.block_untrusted`; CVE-2026-66066). Unfuzzed loaders such
  as MATLAB (`matload`), ImageMagick, camera RAW, FITS and OpenEXR can otherwise
  be abused to read files off the server or attack unhardened parsers. Requires
  libvips >= 8.13 and ruby-vips >= 2.2.1. Configure exemptions with `allow:`
  (e.g. `['VipsForeignLoadSvg']`) or opt out entirely with `safe: false`; in
  Rails use `config.bob_ross.safe` / `config.bob_ross.allow`. Standalone servers
  that never call `BobRoss.configure` are secured by `BobRoss::Server.new`.
- Load SVGs from a memory buffer rather than their file path. A buffer has no
  base URI, so librsvg cannot resolve any resource referenced by the SVG
  (relative or absolute), preventing a crafted SVG from reading sibling files
  (e.g. other uploads in a shared tempdir) into its output. Self-contained
  `data:` URIs continue to render.

### Added

- `BobRoss::PDFPlugin` accepts a `:resolution` transformation to rasterize a PDF
  page at a given DPI (`mutool draw -r`) instead of sizing to fit — useful when a
  page needs to be rendered at a known density and then cropped.