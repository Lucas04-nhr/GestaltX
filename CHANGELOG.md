# Changelog

English | [简体中文](CHANGELOG_ZH-CN.md)

## [1.0.4] - 2026-11-10

Build `11101436`.

### Added

- WAPI preset under **Device → Presets**: disable the WAPI regulatory flag or
  restore the recorded original value. The cached Boolean is resolved from the
  device's own MobileGestalt image instead of a hard-coded slot (#30).
- Per-device originals for the WAPI flag. The value survives edits, app
  restarts, journal migration, and is restored together with the other cached
  options (#30).
- New display presets: high-luminance Always-On Display, AOD flipbook and its
  entry count, HDR photo display, wallpaper parallax control, and experimental
  PWM and DisplayPort capability flags.
- New device presets: Collision SOS, Audio Mix, and Spatial FaceTime audio.
- New intelligence presets: on-device Siri, Audio Intelligence, Personal
  Translator, Photos Clean Up, Handwriting Synthesis, and always-listening Hey
  Siri. These remain capability flags; hardware and region still decide what
  actually runs.
- Korean localization, bringing the app to eight supported languages (#24).
- CI now builds an ad-hoc signed IPA automatically and uploads it as an
  artifact; tag and release runs also attach it to the matching release.

### Changed

- Additional Options and the WAPI row are shown directly in
  **Device → Presets**. The hidden ten-tap unlock on the About version string
  was removed.
- Restore and open actions are disabled while the current document has staged
  edits. Save or discard them first instead of silently losing the changes
  (#37).
- Version bumped to 1.0.4 (`CURRENT_PROJECT_VERSION` 11101436). README version
  badges and the build date were updated.
- All new user-facing strings are localized in the eight supported languages
  (English, Simplified Chinese, Traditional Chinese for Taiwan and Hong Kong,
  Vietnamese, Russian, Persian, and Korean) (#30, #38).

### Fixed

- Device access now falls back across every signed App Group instead of
  trusting the first one. This fixes the `MobileGestalt access was denied`
  error on builds signed with a certificate that carries multiple App Groups
  (#47).
- Field editing preserves exact 64-bit integers, including unsigned values
  above `Int64.max`. Read-back comparison no longer aliases `UInt64.max` with
  `-1` (#31).
- Opening a field and applying it unchanged no longer re-parses its display
  text, preserving sub-millisecond `Date` precision and nested values in
  arrays and dictionaries (#34).
- Malformed `ArtworkTraits` values are no longer replaced or lost when a model
  name or Dynamic Island layout preset is applied. The UI explains that the
  field must be fixed in MG Control first (#38).
- Device backup restores reject a different `CacheUUID`, `CacheVersion`, or
  `CacheData` length before any write, instead of restoring an incompatible
  cache layout (#32).
- Saved backups are verified against their recorded size and SHA-256 digest
  before reuse. Legacy backups without a digest remain readable (#33).
- Shared plist imports reject FIFOs, sockets, directories, and symlinks instead
  of blocking on them, while still accepting regular files (#35).
- File Provider imports coordinate their reads, so placeholders are
  materialized and concurrent changes cannot corrupt the read (#39).
- Cancelling the share extension now resumes a stalled provider continuation
  and cancels the underlying `Progress`, instead of hanging the extension
  (#36).
- Rejecting or confirming one shared plist no longer leaves later queued
  imports waiting for another foreground event. Invalid entries are skipped
  and the queue continues in order (#40).
- Backup restore now validates the saved layout before creating a recovery
  backup or journal entry, so a rejected restore has no side effects (#32).

### Security

- Backup integrity uses a persisted SHA-256 digest. A same-size replacement
  with another valid plist is detected (#33).
- Inbox scans and imports open files with `O_NOFOLLOW` and require a regular
  file descriptor, preventing named-pipe and symlink tricks (#35).

**Full Changelog**: https://github.com/huamidev/GestaltX/compare/v1.0.3...v1.0.4

[1.0.4]: https://github.com/huamidev/GestaltX/releases/tag/v1.0.4
