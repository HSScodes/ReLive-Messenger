# Microsoft Assets That Must Be Replaced for Open-Source Release

> **Purpose:** Every file listed below was extracted from Microsoft's Windows Live
> Messenger 2009 (WLM) binaries or ships under Microsoft's proprietary license.
> Before publishing this project on GitHub as open-source, each asset must be
> recreated from scratch in Nano Banana (or sourced from a compatible license).

---

## Legend

| Column | Meaning |
|--------|---------|
| **Asset** | Current filename in the repo |
| **Used In Code** | Whether Dart code directly references it |
| **Purpose / Description** | What it looks like / what it's used for |
| **Priority** | 🔴 High (app won't work without it) · 🟡 Medium · 🟢 Low (bundled but unused) |

---

## 1. Fonts (21 files) — `assets/fonts/`

All are **Microsoft Segoe UI** — proprietary, cannot be redistributed.

| Asset | Weight / Style | Used In Code | Priority |
|-------|---------------|--------------|----------|
| `segoeui.ttf` | Regular 400 | ✅ pubspec.yaml + app.dart | 🔴 |
| `segoeuib.ttf` | Bold 700 | ✅ pubspec.yaml | 🔴 |
| `segoeuii.ttf` | Italic | ✅ pubspec.yaml | 🔴 |
| `segoeuil.ttf` | Light 300 | ✅ pubspec.yaml | 🟡 |
| `segoeuisl.ttf` | SemiLight 300 | ✅ pubspec.yaml | 🟡 |
| `segoeuiz.ttf` | Bold Italic 700 | ✅ pubspec.yaml | 🟡 |
| `seguili.ttf` | Light Italic 300 | ✅ pubspec.yaml | 🟡 |
| `seguisb.ttf` | SemiBold 600 | ✅ pubspec.yaml | 🟡 |
| `seguisbi.ttf` | SemiBold Italic 600 | ✅ pubspec.yaml | 🟡 |
| `seguisli.ttf` | SemiLight Italic 300 | ✅ pubspec.yaml | 🟡 |
| `segoepr.ttf` | Segoe Print | ❌ | 🟢 |
| `segoeprb.ttf` | Segoe Print Bold | ❌ | 🟢 |
| `segoesc.ttf` | Segoe Script | ❌ | 🟢 |
| `segoescb.ttf` | Segoe Script Bold | ❌ | 🟢 |
| `seguibl.ttf` | Black | ❌ | 🟢 |
| `seguibli.ttf` | Black Italic | ❌ | 🟢 |
| `seguiemj.ttf` | Segoe UI Emoji | ❌ | 🟢 |
| `seguihis.ttf` | Segoe UI Historic | ❌ | 🟢 |
| `seguisym.ttf` | Segoe UI Symbol | ❌ | 🟢 |
| `SegUIVar.ttf` | Segoe UI Variable | ❌ | 🟢 |
| `SegoeIcons.ttf` | Segoe MDL2 Assets (icons) | ❌ | 🟢 |

**Replacement:** Use **Open Sans**, **Noto Sans**, or **Inter** as an open-source substitute. These have similar metrics to Segoe UI. The 10 declared weights/styles in pubspec.yaml all need a matching file.

---

## 2. Sounds (14 files) — `assets/sounds/`

All extracted from WLM 2009 install directory.

| Asset | Format | Used In Code | Purpose | Priority |
|-------|--------|--------------|---------|----------|
| `type.wav` | WAV | ✅ sound_service.dart | Typing indicator tick | 🔴 |
| `type.mp3` | MP3 | ✅ sound_service.dart (fallback) | Typing indicator tick | 🔴 |
| `nudge.wav` | WAV | ✅ sound_service.dart | Nudge vibration sound | 🔴 |
| `newemail.wav` | WAV | ✅ sound_service.dart | New message notification | 🔴 |
| `online.wav` | WAV | ✅ sound_service.dart | Contact came online | 🔴 |
| `newalert.wma` | WMA | ✅ sound_service.dart | New alert sound | 🔴 |
| `type.wma` | WMA | ❌ | WMA copy of type sound | 🟢 |
| `nudge.mp3` | MP3 | ❌ | MP3 copy of nudge | 🟢 |
| `nudge.wma` | WMA | ❌ | WMA copy of nudge | 🟢 |
| `newemail.wma` | WMA | ❌ | WMA copy of newemail | 🟢 |
| `online.wma` | WMA | ❌ | WMA copy of online | 🟢 |
| `outgoing.wma` | WMA | ❌ | Outgoing call ring | 🟢 |
| `phone.wma` | WMA | ❌ | Phone ring sound | 🟢 |
| `vimdone.wma` | WMA | ❌ | Video message done | 🟢 |

**Replacement:** Create short sound effects with similar character. The typing click, nudge buzz, chime, and online ding are each ~0.5–2 seconds.

---

## 3. UI Images — Extracted from `msgsres.dll` (actively used in code)

These are the **highest priority** — the app directly loads them.

| Asset | Variable Name | Used In | Purpose / Description | Priority |
|-------|--------------|---------|----------------------|----------|
| `carved_png_9812096.png` | `_assetAvatarFrame` | login, main_window, chat, avatar_widget, notification | Green/blue avatar picture frame border | 🔴 |
| `carved_png_9801032.png` | `_assetAvatarUser` | login, main_window, chat, avatar_widget | Default user silhouette (no avatar set) | 🔴 |
| `carved_png_9375216.png` | `_assetStatusOnline` / `_assetBuddyGreen` | login, main_window | Green circle — "Online" status icon | 🔴 |
| `carved_png_9387680.png` | `_assetStatusBusy` | login, main_window | Red circle — "Busy" status icon | 🔴 |
| `carved_png_9380960.png` | `_assetStatusAway` | login, main_window | Yellow/orange — "Away" status icon | 🔴 |
| `carved_png_9394296.png` | `_assetStatusOffline` | login, main_window | Grey — "Appear Offline" status icon | 🔴 |
| `carved_png_10968848.png` | `_assetDropdownArrow` / `_assetArrow` | login, main_window | Small dropdown arrow for combo boxes | 🔴 |
| `carved_png_436872.png` | `_assetBottomGlassBar` | login | Translucent glass bar at bottom of login | 🔴 |
| `carved_png_9727920.png` | `_assetHelpIcon` | login | Blue question-mark help icon | 🔴 |
| `carved_png_9797544.png` | `_assetCheckboxOff` | login | Unchecked checkbox graphic | 🔴 |
| `carved_png_10738400.png` | `_assetCheckboxOn` | login | Checked checkbox graphic | 🔴 |
| `carved_png_9835392.png` | `_assetToolbarC` / `_assetWlmIcon` | main_window, chat | WLM butterfly/icon for toolbar | 🔴 |
| `carved_png_10808928.png` | `_assetGroupArrow` | main_window | Expand/collapse arrow for contact groups | 🔴 |
| `carved_png_11071608.png` | `_assetAddContact` | main_window | "Add contact" icon in toolbar | 🔴 |
| `carved_png_9432408.png` | `_assetNudgeIcon` | chat | Nudge button icon (shaking lines) | 🔴 |
| `carved_png_427616.png` | `_assetChromeBar` | chat | Window chrome/toolbar gradient bar (dark) | 🔴 |
| `carved_png_433248.png` | `_assetChromeBarLight` | chat | Window chrome/toolbar gradient bar (light) | 🔴 |
| `carved_png_9543256.png` | `_assetBuddySprite` | connecting_screen | Animated buddy sprite sheet (1536×36) for loading animation | 🔴 |
| `carved_png_10810632.png` | `_assetLogo` | connecting_screen | Windows Live Messenger logo | 🔴 |
| `carved_png_10983152.png` | (back button arrow) | win7_back_button | Windows 7 Aero back-arrow button image | 🔴 |

**Total actively used UI PNGs: 20** (emoticon sprite sheet excluded — handled separately)

---

## 4. Scene Images (22 files) — `assets/images/scenes/`

Display picture scene backgrounds, loaded dynamically via `content.xml`.

| Asset | Display Name | Priority |
|-------|-------------|----------|
| `0001.png` | Daisy Hill | 🟡 |
| `0002.jpg` | Bamboo | 🟡 |
| `0003.jpg` | Cherry Blossoms | 🟡 |
| `0004.png` | Violet Springtime | 🟡 |
| `0005.png` | Flourish | 🟡 |
| `0006.png` | Dawn | 🟡 |
| `0007.png` | Field | 🟡 |
| `0008.png` | Mesmerizing Brown | 🟡 |
| `ButterflyPattern.png` | Butterfly Pattern | 🟡 |
| `CarbonFiber.jpg` | Carbon Fiber | 🟡 |
| `DottieGreen.png` | Dottie Green | 🟡 |
| `Graffiti.jpg` | Graffiti | 🟡 |
| `MesmerizingWhite.png` | Mesmerizing White | 🟡 |
| `Morty.png` | Morty | 🟡 |
| `Robot.jpg` | Robot | 🟡 |
| `Silhouette.jpg` | Silhouette | 🟡 |
| `zune_01.jpg` | Zune 01 | 🟡 |
| `zune_02.jpg` | Zune 02 | 🟡 |
| `zune_03.jpg` | Zune 03 | 🟡 |
| `zune_04.jpg` | Zune 04 | 🟡 |
| `zune_05.jpg` | Zune 05 | 🟡 |
| `zune_06.jpg` | Zune 06 | 🟡 |

**Replacement:** Create original scene backgrounds. Dimensions should match the originals (~96×96 crop area for profile pics).

---

## 5. User Tiles / Default Avatar Images (31 files) — `assets/images/usertiles/`

Default display pictures bundled with WLM 2009, loaded dynamically via `content.xml`.

| Asset | Display Name | Format | Priority |
|-------|-------------|--------|----------|
| `basketball.png` | Basketball | PNG | 🟡 |
| `bonsai.png` | Bonsai | PNG | 🟡 |
| `chef.png` | Chef | PNG | 🟡 |
| `chess.png` | Chess | PNG | 🟡 |
| `daisy.png` | Daisy | PNG | 🟡 |
| `doctor.png` | Doctor | PNG | 🟡 |
| `dog.png` | Dog | PNG | 🟡 |
| `electric_guitar.png` | Electric Guitar | PNG | 🟡 |
| `executive.png` | Executive | PNG | 🟡 |
| `fish.png` | Fish | PNG | 🟡 |
| `flare.png` | Flare | PNG | 🟡 |
| `gerber_daisy.png` | Gerber Daisy | PNG | 🟡 |
| `golf.png` | Golf | PNG | 🟡 |
| `guest.png` | Guest | PNG | 🟡 |
| `guitar.png` | Guitar | PNG | 🟡 |
| `kitten.png` | Kitten | PNG | 🟡 |
| `leaf.png` | Leaf | PNG | 🟡 |
| `morty.png` | Morty | PNG | 🟡 |
| `music.png` | Music | PNG | 🟡 |
| `robot.png` | Robot | PNG | 🟡 |
| `seastar.png` | Seastar | PNG | 🟡 |
| `shopping.png` | Shopping | PNG | 🟡 |
| `sports.png` | Sports | PNG | 🟡 |
| `surf.png` | Surf | PNG | 🟡 |
| `tennis.png` | Tennis | PNG | 🟡 |
| `soccer.gif` | Soccer | GIF (animated) | 🟡 |
| `fall.gif` | Fall | GIF (animated) | 🟡 |
| `spring.gif` | Spring | GIF (animated) | 🟡 |
| `summer.gif` | Summer | GIF (animated) | 🟡 |
| `winter.gif` | Winter | GIF (animated) | 🟡 |

**Replacement:** Create new themed avatar illustrations. Same dimensions (~96×96).

---

## 6. Background Images (5 files) — `assets/images/backgrounds/`

Chat window background images from WLM 2009.

| Asset | Display Name | Priority |
|-------|-------------|----------|
| `car.jpg` | Car | 🟡 |
| `fish.jpg` | Fish | 🟡 |
| `hearts.jpg` | Hearts | 🟡 |
| `lavender.jpg` | Lavender | 🟡 |
| `planets.jpg` | Planets | 🟡 |

---

## 7. Standalone Image — `assets/images/`

| Asset | Purpose | Priority |
|-------|---------|----------|
| `win7_back_button.png` | Windows 7 Aero-style glass back button | 🟡 |

---

## 8. Extracted DLL Resources NOT Directly Used in Code — `assets/images/extracted/`

These were bulk-extracted from WLM DLLs and are bundled via pubspec.yaml directory
declarations but **not** directly referenced in any `.dart` file. They should be
removed from the repo entirely for open-source release.

### `msgsres/` — ~180+ files (only 21 used — see Section 3)

Remaining ~160 files are carved PNGs, BMPs, and ICOs not referenced in code.
These include extra UI sprites, dialog icons, and debug sheets.

### Other extracted DLL directories (all unused in code):

| Directory | Files | Contents |
|-----------|-------|----------|
| `uxcore/` | 1 ICO | Application icon |
| `livetransport/` | 1 ICO | Application icon |
| `msidcrl40/` | 1 ICO | Application icon |
| `PresenceIM/` | 1 ICO | Application icon |
| `rtmpltfm/` | 3 ICOs | Application icons |
| `uccapi/` | 2 ICOs | Application icons |
| `uccapires/` | 1 ICO | Application icon |
| `uxcontacts/` | 1 ICO | Application icon |
| `vvpltfrm/` | 1 ICO | Application icon |
| `wmv9vcm/` | 1 ICO | Application icon |
| `msgrapp.14.0.8117.0416/` | empty | — |
| `msgsc.14.0.8117.0416/` | empty | — |
| `msgslang.14.0.8117.0416/` | empty | — |
| `msgswcam/` | empty | — |
| `msimg32/` | empty | — |
| `msvsui/` | empty | — |
| `psmsong.14.0.8117.0416/` | empty | — |
| `reroute/` | empty | — |
| `sqmapi/` | empty | — |
| `uxcalendar/` | empty | — |
| `wldcore/` | empty | — |
| `wldlog/` | empty | — |
| `wmaecdmort/` | empty | — |
| `custsat/` | empty | — |
| `liveNatTrav/` | empty | — |

**Action:** Delete all unused extracted directories and the ~160 unused files from `msgsres/`.

---

## 9. UI Logic XML — `assets/ui_logic/`

| Asset | Purpose | Priority |
|-------|---------|----------|
| `msgsres/carved_ui_10824088.xml` | WLM internal UI layout definition | 🟢 |
| `msgsres/carved_ui_10824088_1.xml` | WLM internal UI layout definition | 🟢 |
| `msgsres/carved_ui_9355216.xml` | WLM internal UI layout definition | 🟢 |
| `msgsres/carved_ui_9355216_1.xml` | WLM internal UI layout definition | 🟢 |
| `ui_logic_index.md` | Index file | 🟢 |

**Action:** These are reference files only. Remove from the final release.

---

## Summary — What to Recreate in Nano Banana

| Category | Total Files | Must Replace | Can Delete |
|----------|------------|-------------|------------|
| **Fonts** | 21 | 10 (declared in pubspec) | 11 unused |
| **Sounds** | 14 | 6 (used in code) | 8 unused formats |
| **UI Icons (msgsres)** | ~180 | **21** (used in code) | ~160 unused |
| **Scenes** | 22 | 22 (loaded dynamically) | 0 |
| **User Tiles** | 31 | 31 (loaded dynamically) | 0 |
| **Backgrounds** | 5 | 5 (loaded dynamically) | 0 |
| **Standalone images** | 1 | 1 | 0 |
| **Extracted DLL ICOs** | 12 | 0 | 12 |
| **UI Logic XML** | 5 | 0 | 5 |
| **content.xml files** | 3 | 0 (can be regenerated) | 3 |
| **Empty directories** | 15 | 0 | 15 |
| **TOTAL** | **~309** | **~96** | **~213** |

### Priority Order for Nano Banana Recreation

1. **🔴 21 UI icon PNGs** — App literally won't render without these (avatar frame, status dots, toolbar icons, emoticon sprite sheet, loading animation, logo, chrome bars)
2. **🔴 6 sound effects** — Core UX sounds (type, nudge, new message, online, alert)
3. **🔴 10 font files** — Or swap the font family to an open-source alternative
4. **🟡 22 scenes + 31 user tiles + 5 backgrounds + 1 back button** — Feature-complete but app works without them
5. **🟢 Everything else** — Delete from repo before publishing
