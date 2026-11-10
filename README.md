<p align="center">
  <img src="GestaltX/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="GestaltX" width="112" height="112">
</p>

<h1 align="center">GestaltX</h1>

[![Version](https://img.shields.io/badge/version-1.0.4-blue)](https://github.com/huamidev/GestaltX)
[![Platform](https://img.shields.io/badge/iOS-27.x-black?logo=apple)](#compatibility)
[![SwiftUI](https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift)](https://github.com/huamidev/GestaltX)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

[English](README.md) · [简体中文](README_ZH-CN.md)

A MobileGestalt editor for iPhone and iPad. Developed by [huamidev](https://github.com/huamidev).

> [!NOTE]
> **This is an unofficial fork.** The upstream project is [huamidev/GestaltX](https://github.com/huamidev/GestaltX), and all credit for GestaltX belongs to its author. This fork follows the upstream tags and adds these changes:
>
> - **Reorganized backup, restore, import and export.** The Backups tab now handles all of these. See [Backups, import and export](#backups-import-and-export).
> - **Check Unofficial Settings.** A check in Tools lists values that are not official for this device and can stage fixes for them. See [Check unofficial settings](#check-unofficial-settings).
> - **CI.** The IPA is ad-hoc signed with the entitlements of the app and its share extension, so AltStore and SideStore can register the App Group when they re-sign it.
>
> Report issues with these changes in this repository, and all other issues in the [upstream repository](https://github.com/huamidev/GestaltX/issues).

## Features

| Category | Presets and tools |
| --- | --- |
| Display | Dynamic Island capability and layout, Always-On Display, AOD Vibrancy, high-luminance AOD, AOD flipbook, HDR photo display, wallpaper parallax, Liquid Glass low-power rendering, experimental PWM and DisplayPort flags |
| Device | Model name, boot/shutdown chime, charge limit, tap to wake, Camera Control settings, Action Button settings, Collision SOS, Audio Mix, Spatial FaceTime audio |
| iPad | Apple Pencil settings, Stage Manager capability, iPad app compatibility |
| Intelligence | Independent region-code options, Apple Intelligence capability flag, on-device Siri, Audio Intelligence, Personal Translator, Photos Clean Up, Handwriting Synthesis, always-listening Hey Siri, and sales-region options for activation attempts on China-mainland devices |
| Advanced | Apple internal feature flags, internal storage view, internal settings bundle, Security Research Device flag |
| Field editor | Read, search, add, edit, and remove `CacheExtra` fields; open a backup as a local document to edit it; String, Integer, Real, Boolean, Data, Date, Array, and Dictionary values |
| Changes | Automatic reading and manual re-read, staged before/after review, verified writes, per-preset restore |
| Backups | Automatic initial backup and a backup before every write, manual device backup, original-value records; import from Files or the share sheet; restore to this device, open as a local document, rename, export, and delete; export and import all backups in one file |
| Logs & respring | Actual exploit-stage logs and manual NeoSpring respring |

Usually, changing the region code is enough to try enabling AI; there is no need to change Sales Region. Selecting United States for Region Code sets `RegionCode` to `LL` and keeps the sales-region suffix. You can also choose China (Mainland), Hong Kong, Taiwan, Japan or the United Kingdom. Sales Region and Region Code can be applied together: the sales suffix follows Sales Region, while the code follows Region Code.

*If you previously changed Sales Region, restore your device’s original sales region and apply it first.*

Disabling a preset or using its Revert button restores the recorded original values and types. Keys that were originally absent are removed. If an older change has no original record, use Remove Added Fields only when you know those fields were added.

Presets modify capability flags; actual effects depend on the device and OS. China-mainland devices can use the Apple Intelligence and region options to attempt activation; availability also depends on the model, OS version, and Apple services.

## Compatibility

Supports **iOS / iPadOS 27.x**. **iOS / iPadOS 26.x is not supported for on-device MobileGestalt access.** Powered by [worse_query](https://github.com/forcequitOS/worse_query). SystemGroup access requires iOS 27; available features depend on the device and OS. Local plist editing is also supported.

Signing requires a certificate and provisioning profile with at least one usable App Group. Sign the app and its embedded share extension with at least one **common App Group**, and keep the extension when re-signing. Both processes detect their actual signed App Groups at runtime. Distributed IPAs carry ad-hoc signatures with these entitlements embedded so SideStore and AltStore can detect them when re-signing; they are not signed with a developer certificate.

## Backups, import and export

The **Backups** tab is the single place to back up, import, restore and export. Each action does one thing:

| Action | What it does |
| --- | --- |
| **Create Backup** | Saves this device's current MobileGestalt file, whatever document is open. GestaltX also backs up automatically on the first read and before every write. |
| **Import from Files** | Adds a plist to the backups list as **Imported**, after you confirm it. Importing never opens the file or writes it to the device, and staged edits are kept. |
| **Restore** | Writes a backup to this device. GestaltX reads the device file again first. The backup must belong to this device and use the same system cache layout (`CacheUUID`, `CacheVersion` and `CacheData` size), so a backup made before an iOS update is refused. The current file is backed up first and the write is read back and verified. Apply or discard staged changes before restoring, and restart the device afterward. |
| **Open** | Loads a backup as a local document to view or edit it in **MG Control**. Saving a local document changes only the copy in GestaltX: never the device file and never the backups list. |
| **Rename** | Swipe a backup or touch and hold it to give it a name. Only the name changes, never the backup itself. Exported files use the name. |
| **Export** | Shares a backup as its plain plist, exactly as saved. It can be imported again here or opened in other apps. |
| **Export All Backups** | Saves every backup (with its name), the original-value record and GestaltX settings in one file. To keep your backups when you delete GestaltX, export them first, then after reinstalling import the file with **Import from Files** or open it in GestaltX from Files. Existing backups are kept. The share sheet does not accept this file. |

**Export Plist** in Tools exports the open document as a plain plist, as it was last read or saved. Staged changes are never exported, so apply or discard them first.

### Importing

Tap **Import from Files** in Backups, or select a MobileGestalt plist in Files or another app, tap **Share** and choose **GestaltX**. The share extension passes the file to the app through the shared App Group; return to GestaltX if it does not open automatically. Files shared this way are checked at launch and whenever GestaltX returns to the foreground.

GestaltX exports and imports plain MobileGestalt plists. Nothing is encrypted, signed or verified, so files work in other apps and never depend on a key that could be lost.

GestaltX does not check where an imported file came from. **Make sure you know its source, and do not restore files from unknown sources.** Restoring still refuses a backup whose device identifiers differ from this device's or whose system cache layout is different.

Plists exported by earlier versions carry a device-bound proof. They are still accepted: GestaltX imports the plain plist inside. The key that earlier versions kept in the Keychain, including any copy in iCloud Keychain, is deleted.

Local file backups made by earlier versions can still be opened and exported, but they cannot be restored to the device.

An archive is not signed. Every backup is added with its name and type, and earlier archives are read the same way. The original-value record is restored only if no record exists yet and its device identifiers match this device.

## Check unofficial settings

**Check Unofficial Settings** in Tools lists values in the open document that are not official for this device. The check itself changes nothing. The device's real model identifier comes from the system (`hw.machine`), not from the MobileGestalt cache, so it is correct even if the cached product type was changed.

- **Not Official:** Apple internal and Security Research Device flags that are turned on. iPad-only features turned on on an iPhone. Features the model does not officially support, such as Dynamic Island on an iPhone 13, or Charge Limit on an iPhone 14 or an iPad released before 2024. A cached product type that differs from the real model.
- **Possibly Not Official:** A model name that differs from the real model (checked on iPhone only), Apple Intelligence turned on on a mainland China model, or a region code that does not match the sales-region suffix.
- **Not Checked:** Items with no reliable reference for this device. They are never reported. Models missing from the reference table are only checked for internal flags and consistency.

**Stage Fixes** stages the official value for each selected item: Boolean flags are turned off with their number type kept, iPad app compatibility returns to iPhone apps only, and the product type, model name or region code is corrected. Not Official items are selected by default; Possibly Not Official items must be selected. Fixes are only staged. Review and apply them like any other change, so a backup is created and the write is read back and verified.

The check cannot tell the factory region or sales region, because they are stored outside MobileGestalt. It also cannot judge keys that GestaltX presets do not cover.

## Language support

GestaltX follows your iOS language settings, with English as the default and fallback. Persian includes right-to-left layout support.

| Language | Locale |
| --- | --- |
| English | `en` |
| 简体中文 — Simplified Chinese | `zh-Hans` |
| 繁體中文（台灣）— Traditional Chinese (Taiwan) | `zh-Hant-TW` |
| 繁體中文（香港）— Traditional Chinese (Hong Kong) | `zh-Hant-HK` |
| Tiếng Việt — Vietnamese | `vi` |
| Русский — Russian | `ru` |
| فارسی — Persian | `fa` |
| 한국어 — Korean | `ko` |

## Credits

- [forcequitOS / Taj C — worse_query](https://github.com/forcequitOS/worse_query)
- [neonmodder123](https://github.com/neonmodder123)
- [skadz108](https://github.com/skadz108)
- [rooootdev — NeoSpring](https://github.com/rooootdev/neospring)
- [Nouvborne — Ketamine](https://github.com/Nouvborne/Ketamine)
- [PoomSmart — MGKeys](https://github.com/PoomSmart/MGKeys)
- [leminlimez — Nugget](https://github.com/leminlimez/Nugget)
- [rooootdev — mond](https://github.com/rooootdev/mond)
- [frs0n — GestaltEdit](https://github.com/frs0n/GestaltEdit)

## Disclaimer

For security research and educational purposes only. Use only on devices you own or are authorized to manage.

Back up your data before making changes. Modifying MobileGestalt may cause system instability or require a device restore. You are responsible for the changes you apply and the resulting risks.

## License

[GNU GPL v3](LICENSE) · Copyright © 2026 huamidev.

## Star History

<a href="https://www.star-history.com/#huamidev/GestaltX&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=huamidev/GestaltX&amp;type=Date&amp;theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=huamidev/GestaltX&amp;type=Date" />
    <img width="480" alt="GestaltX Star History" src="https://api.star-history.com/svg?repos=huamidev/GestaltX&amp;type=Date" />
  </picture>
</a>
