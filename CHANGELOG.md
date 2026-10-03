# Changelog

## [Unreleased]

### Changed

- **Breaking:** in Rails, BobRoss is now served from the middleware stack
  (`BobRoss::Middleware`, inserted after `ActionDispatch::Callbacks`) instead of
  a route. Image requests skip cookies, the session, flash, CSP, `Rack::Head`,
  `Rack::ConditionalGet` and `Rack::ETag`; with a cookie session store and
  `expire_after`, every image response previously set a new session cookie,
  which stops CDNs from caching it. Images no longer go through the router, so
  route constraints or session checks around the prefix no longer apply.
- **Breaking:** the Railtie requires Rails 8.0 or later. Settings are read from
  `credentials` only; `secrets` (removed in Rails 7.2) is no longer checked.
- `BobRoss::Middleware` can also be used in any Rack app:
  `use BobRoss::Middleware, prefix: '/images', server: BobRoss::Server.new(...)`.

### Fixed

- `BobRoss::Server` returns an empty body for every `HEAD` request, including
  error responses, and no longer leaves a file open for a `HEAD` with a `Range`.

- `BobRoss::Server` now uses lowercase response header names, as Rack 3
  requires. Mixed-case keys (e.g. `Cache-Control`) were invisible to middleware
  that reads `cache-control`, so when mounted in Rails, `Rack::ETag` added its
  own `cache-control: no-cache` and the configured `cache_control` never
  reached the client.

### Security

- Block libvips loaders that are unsafe for untrusted content by default on the
  libvips backend (`Vips.block_untrusted`; CVE-2026-66066). Unfuzzed loaders such
  as MATLAB (`matload`), ImageMagick, camera RAW, FITS and OpenEXR can otherwise
  be abused to read files off the server or attack unhardened parsers. Requires
  libvips >= 8.13 and ruby-vips >= 2.2.1. The block is applied when the libvips
  backend is loaded, so it is in effect even without `BobRoss.configure`.
  Configure exemptions with `allow:` (e.g. `['VipsForeignLoadSvg']`) or opt out
  with `safe: false` (reversible — a later configure re-blocks); in Rails use
  `config.bob_ross.safe` / `config.bob_ross.allow`.
- Load SVGs from a memory buffer rather than their file path. A buffer has no
  base URI, so librsvg cannot resolve any resource referenced by the SVG
  (relative or absolute), preventing a crafted SVG from reading sibling files
  (e.g. other uploads in a shared tempdir) into its output. Self-contained
  `data:` URIs continue to render.
