GestaltX — Third-Party Notices
Copyright (C) 2026 huamidev
https://github.com/huamidev

GestaltX application code is licensed under GNU GPL version 3. The worse_query component retains its GPL-3.0-or-later terms. The complete GPL v3 text is included with the app and in LICENSE. No warranty is provided.

1. worse_query
   Author: Taj C (forcequit / forcequitOS)
   Copyright (C) 2026 Taj C (forcequit)
   Source: https://github.com/forcequitOS/worse_query
   License: GPL-3.0-or-later, as stated in the source-file notices.
   Included: worse_query.m and worse_query.h.
   The original escape implementation and notices are preserved. GestaltX supplies its own application, document transactions and UI. The provisioned App Group identifier remains group.com.huami.gestultx.
   GestaltX modification dated 2026-11-10: serialized the escape operation to prevent simultaneous MobileGestalt and container-cache requests from swapping the App Group cache link concurrently.

2. NeoSpring / WebKit respring
   Original technique: neonmodder123 — https://github.com/neonmodder123
   Swift implementation: skadz108 — https://github.com/skadz108
   NeoSpring project: rooootdev — https://github.com/rooootdev/neospring
   GPL-licensed adaptation used as reference and incorporated here:
   Nouvborne/Ketamine — https://github.com/Nouvborne/Ketamine
   License: GNU GPL v3 (copy included in the app).
   Included/adapted: the respring HTML in NeoSpringView.swift and the earlier GestaltX respring implementation.
   GestaltX changes dated 2026-11-09: fixed raw-string closing-tag escaping and Web Crypto request length; added timeout, cancellation, nonpersistent WebKit data store and Simulator exclusion. NeoSpring itself is credited as a project/technique reference, not assigned a license it does not declare.

3. Research and workflow references (not bundled source)
   PoomSmart/MGKeys: https://github.com/PoomSmart/MGKeys
   leminlimez/Nugget: https://github.com/leminlimez/Nugget
   rooootdev/mond: https://github.com/rooootdev/mond
   frs0n/GestaltEdit: https://github.com/frs0n/GestaltEdit
   These projects informed key names and workflow design. GestaltX implements its own preset catalog, plist model, backups, transactions and interface; their application code, assets and noncommercial-licensed components are not included. Each upstream retains its own license and copyright.

4. pathleak / Erosion-CN container-cache workflow
   pathleak author: Taj C (forcequit). Copyright (C) 2026 Taj C (forcequit).
   Source: https://github.com/Kianuni/Erosion-CN/blob/main/Erosion/Exploits/pathleak.m
   License: GPL-3.0-or-later, as stated in the retained source-file notice.
   Included/adapted: GXContainerPaths.m. GestaltX changes dated 2026-11-10 restrict enumeration to application data containers, validate UUID path components, deduplicate results and add a bounded, cancellable scan.
   Workflow reference: https://github.com/Kianuni/Erosion-CN/blob/main/Erosion/Tweaks/CacheCleaner/CacheCleanerView.swift (GNU GPL v3; Erosion / lunginspector and Kianuni).
   GestaltX implements its own SwiftUI screen and directory-relative cleanup core. Unlike the reference, all three cache roots contribute to estimates, cleanup requires confirmation, links and special files are skipped, failures remain visible and deleted-file bytes are not presented as guaranteed disk-space savings.

GestaltX is not affiliated with Apple or any credited project. Upstream sandbox-escape OS support is not a guarantee that the MobileGestalt system cache is writable, or that capability flags produce working hardware features. A verified file write does not prove a feature works or that a respring succeeded.

GitHub mark: Primer Octicons (GitHub), MIT license.
Source: https://raw.githubusercontent.com/primer/octicons/main/icons/mark-github-16.svg
Full license: Primer-Octicons-MIT.txt in the application bundle.
GitHub names and marks remain GitHub trademarks.
