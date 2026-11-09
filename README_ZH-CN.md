<p align="center">
  <img src="GestaltX/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="GestaltX" width="112" height="112">
</p>

<h1 align="center">GestaltX</h1>

[![Version](https://img.shields.io/badge/version-1.0.3-blue)](https://github.com/huamidev/GestaltX)
[![Platform](https://img.shields.io/badge/iOS-27.x-black?logo=apple)](#兼容性)
[![SwiftUI](https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift)](https://github.com/huamidev/GestaltX)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

[English](README.md) · [简体中文](README_ZH-CN.md)

适用于 iPhone 和 iPad 的 MobileGestalt 编辑工具，由 [huamidev](https://github.com/huamidev) 开发。

> [!NOTE]
> **本仓库为非官方分支。** 上游项目为 [huamidev/GestaltX](https://github.com/huamidev/GestaltX)，GestaltX 的一切功劳归原作者所有。本分支跟随上游 tag，并加入以下改动：
>
> - **重新整理了备份、恢复、导入与导出。** 这些操作现在统一在“备份”页完成，详见[备份、导入与导出](#备份导入与导出)。
> - **检查非官方设定。** 在“工具”页列出不属于本机官方设定的值，并可暂存修正，详见[检查非官方设定](#检查非官方设定)。
> - **CI。** 使用 App 及其 Share Extension 的 entitlements 对 IPA 进行 ad-hoc 签名，以便 AltStore 和 SideStore 在重签时能够注册 App Group。
>
> 与上述改动相关的问题请在本仓库反馈，其他问题请反馈至[上游仓库](https://github.com/huamidev/GestaltX/issues)。

## 功能

| 分类 | 预设与工具 |
| --- | --- |
| 显示 | 灵动岛功能标记与布局、全天候显示、AOD 色彩、液态玻璃低性能渲染 |
| 设备 | 机型名称、开关机提示音、充电上限、轻点唤醒、相机控制设置、操作按钮设置 |
| iPad | Apple Pencil 设置、台前调度功能标记、iPad 应用兼容性 |
| 智能 | 独立的地区代码选项、Apple 智能功能标记及销售地区选项；国行设备可尝试开启 AI |
| 高级 | Apple 内部功能标记、内部存储视图、安全研究设备标记 |
| 字段编辑 | 读取、搜索、添加、编辑与删除 `CacheExtra` 字段；可将备份作为本地文稿打开并编辑；支持字符串、整数、浮点数、布尔值、数据、日期、数组和字典 |
| 更改管理 | 启动自动读取、手动重新读取、暂存更改前后对比、写入验证、逐项还原 |
| 备份 | 首次读取自动备份、每次写入前备份、手动备份本机文件、原值记录；从“文件”或分享面板核验导入；恢复到本机、作为本地文稿打开、重命名、导出和删除 |
| 日志与注销 | 实际漏洞利用过程日志、手动 NeoSpring 注销 |

通常只需修改地区代码即可尝试启用 AI，无需更改销售地区。“地区代码”选择“美国”时仅将 `RegionCode` 设为 `LL`，保留销售地区后缀，也可选择中国大陆、香港、台湾、日本或英国。销售地区与地区代码可以一起应用：后缀按销售地区设置，代码按地区代码设置。

*之前修改过销售地区的用户，请先改回设备原本的销售地区并应用。*

停用预设或点击该项“还原”，会恢复已记录的原值及类型；原本不存在的字段会被删除。旧版修改若缺少原值记录，请仅对确认是后来添加的字段使用“移除新增字段”。

预设修改的是功能标记，实际效果取决于设备与系统。国行设备可通过 Apple 智能与地区选项尝试启用 AI，实际可用性还取决于机型、系统版本及 Apple 服务。

## 兼容性

支持 **iOS / iPadOS 27.x**。**iOS / iPadOS 26.x 不支持本机 MobileGestalt 访问。** 基于 [worse_query](https://github.com/forcequitOS/worse_query)。SystemGroup 访问需要 iOS 27，功能可用性因设备与系统而异，同时支持本地 plist 编辑。

签名所用的证书及描述文件必须提供至少一个可用的 App Group。主应用和内置分享扩展必须签入至少一个**相同的 App Group**，重签时请保留分享扩展。两者均会在运行时读取实际签名中的 App Group。

## 备份、导入与导出

备份、导入、恢复和导出都在“**备份**”页完成，每个操作只做一件事：

| 操作 | 作用 |
| --- | --- |
| **创建备份** | 保存本机当前的 MobileGestalt 文件，与当前打开的是哪个文稿无关。此外，GestaltX 会在首次读取时和每次写入前自动备份。 |
| **从“文件”导入** | 核验 plist 后，将其以“**已导入**”的形式加入备份列表。导入不会打开该文件，也不会写入本机，暂存的更改会保留。 |
| **恢复** | 将备份写入本机。GestaltX 会先重新读取本机文件。备份必须属于本机，且系统缓存布局（`CacheUUID`、`CacheVersion` 和 `CacheData` 长度）一致，因此 iOS 更新前的备份会被拒绝。写入前会先备份当前文件，写入后读回验证。恢复前请先应用或放弃暂存的更改，完成后请重启设备。 |
| **打开** | 将备份作为本地文稿载入，以便在“**MG 控制**”中查看或编辑。保存本地文稿只会更改 GestaltX 内的副本，不会更改本机文件，也不会更改备份列表。 |
| **重命名** | 在备份上左滑或长按即可命名。只会更改名称，不会更改备份内容；导出的文件也会使用这个名称。 |
| **导出** | 将备份作为文件分享。本机备份导出时附带本机凭证，之后可在本机重新导入。 |

“工具”页的“**导出 plist**”会导出当前文稿最近一次读取或保存时的内容，并附带本机凭证。暂存的更改不会被导出，请先应用或放弃。

### 导入核验

在“备份”页点击**从“文件”导入**，或在“文件”及其他 App 中选中 MobileGestalt plist，点击**分享**，再选择 **GestaltX**。分享扩展会通过共同的 App Group 将文件交给主应用；如未自动打开，请返回 GestaltX。应用会在启动和回到前台时检查分享过来的文件。

只有附带本机 GestaltX 导出凭证，或含有至少两个与本机一致的唯一设备标识的文件才会被接受。无法核验的文件均会被拒绝，之前导入的文件也不会被当作本机身份依据。

部分原始 plist 不含唯一设备标识，请先在本机通过 GestaltX 导出一份副本。校验密钥只保存在本机钥匙串，不随文件导出。

旧版本生成的本地文件备份仍可打开和导出，但不能恢复到本机。

## 检查非官方设定

“工具”页的“**检查非官方设定**”会列出当前文稿中不属于本机官方设定的值。检查本身不会做任何修改。本机的真实机型标识符由系统（`hw.machine`）直接提供，不来自 MobileGestalt 缓存，所以即使缓存中的产品类型被改过，也能得到正确结果。

- **非官方**：已开启的 Apple 内部标记和安全研究设备标记；在 iPhone 上开启的 iPad 专属功能；机型官方不支持的功能，例如 iPhone 13 上的灵动岛；缓存中与真实机型不一致的产品类型。
- **可能非官方**：与真实机型不一致的机型名称，以及与销售地区后缀不一致的地区代码。
- **未检查**：在本机上没有可靠参考依据的项目，这些项目不会被报告。参考表中没有的机型只检查内部标记和一致性。

点击“**暂存修正**”会为勾选的项目暂存官方值：布尔标记改为关闭并保留原有数字类型，iPad 应用兼容改回仅 iPhone 应用，产品类型、机型名称或地区代码改为正确的值。“非官方”的项目默认勾选，“可能非官方”的项目需要手动勾选。修正只会暂存，需要像其他更改一样确认后再应用，因此写入前会自动备份，写入后会读回验证。

此检查无法判断出厂时的地区代码和销售地区，因为它们保存在 MobileGestalt 之外；也无法判断 GestaltX 预设未涵盖的键。

## 语言支持

GestaltX 跟随 iOS 的语言设置，默认及回退语言为英语。波斯语已适配从右向左布局。

| 语言 | 语言代码 |
| --- | --- |
| English（英语） | `en` |
| 简体中文 | `zh-Hans` |
| 繁體中文（台灣） | `zh-Hant-TW` |
| 繁體中文（香港） | `zh-Hant-HK` |
| Tiếng Việt（越南语） | `vi` |
| Русский（俄语） | `ru` |
| فارسی（波斯语） | `fa` |

## 鸣谢

- [forcequitOS / Taj C — worse_query](https://github.com/forcequitOS/worse_query)
- [neonmodder123](https://github.com/neonmodder123)
- [skadz108](https://github.com/skadz108)
- [rooootdev — NeoSpring](https://github.com/rooootdev/neospring)
- [Nouvborne — Ketamine](https://github.com/Nouvborne/Ketamine)
- [PoomSmart — MGKeys](https://github.com/PoomSmart/MGKeys)
- [leminlimez — Nugget](https://github.com/leminlimez/Nugget)
- [rooootdev — mond](https://github.com/rooootdev/mond)
- [frs0n — GestaltEdit](https://github.com/frs0n/GestaltEdit)

## 免责声明

本项目仅供安全研究与学习交流，请仅在本人持有或已获授权的设备上使用。

修改前请备份数据。修改 MobileGestalt 可能导致系统不稳定，严重时需要恢复设备。使用者须自行承担所选修改及其带来的风险。

## 许可证

[GNU GPL v3](LICENSE) · Copyright © 2026 huamidev。
