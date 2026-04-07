# Visual Identity Guide

Modern Aero glass design language for the WLM Flutter application — inspired by Windows Live Messenger 2009, Windows 7 Aero, and Frutiger Aero aesthetics updated for contemporary screens.

---

## 1. Color Palette

### Primary Blues (Title Bars & Accents)
| Token | Hex | Usage |
|-------|-----|-------|
| Deep Navy | `#1A4978` | Title bar gradient start, dark accent |
| Aero Blue | `#3A8CC4` | Primary button background, title bar mid |
| Sky Highlight | `#5CAEE0` | Title bar highlight band |
| Ocean Mid | `#2F7CB5` | Title bar gradient end |

### Background Gradients
| Context | Colors | Stops |
|---------|--------|-------|
| Main window / sky | `#53B8EA → #7ECDF2 → #B0DFF5 → #DBEFF8` | 0 / 0.18 / 0.45 / 1.0 |
| Chat window | `#4AAFE4 → #7CC8F0 → #BFDFF5 → #E8F2FA` | 0 / 0.12 / 0.30 / 0.55 |
| Default header scene | `#6BB8E8 → #8ECDF0 → #B8D9ED → #E4F0F8` | 4 stops top-to-bottom |

### Surface & Text
| Token | Hex | Usage |
|-------|-----|-------|
| Dialog Background | `#F4F8FB` | Popup dialog body |
| Dark Text | `#243E57` | Primary body text |
| Muted Text | `#4A6A84` | Secondary labels |
| Group Header | `#4A7A9C` | Contact list group names |
| Link Blue | `#1A5C8A` | Footer links, tappable text |

---

## 2. Glass & Frosted Effects

All frosted glass surfaces use `BackdropFilter` with `ImageFilter.blur`.

| Component | Blur σ | Background | Border |
|-----------|--------|------------|--------|
| Profile card | 20 | White 55% → 40% → 50% gradient | White 65%, 1.2px |
| Contact list | 18 | White 78% → 92% gradient | White 40%, 1px |
| Search bar | 12 | White 45% solid | White 50%, 1px |
| Login card | — | White 55% → 40% → 50% gradient | White 65%, 1.2px |

### Implementation Pattern
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(14),
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.white.withOpacity(0.55),
          Colors.white.withOpacity(0.40),
          Colors.white.withOpacity(0.50),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
      ),
    ),
  ),
),
```

---

## 3. Border Radius

| Context | Radius |
|---------|--------|
| Glass cards (profile, login) | 14–16 px |
| Dialog windows | 14 px |
| Contact list container | 12 px |
| Input fields | 8 px |
| Buttons (pill) | 20 px |
| Buttons (standard) | 8 px |
| Chat area containers | 4–8 px |
| Search bar (pill) | 18 px |

---

## 4. Typography

- **Font stack**: `['Segoe UI', 'Tahoma', 'Arial']`
- All text uses `fontFamilyFallback` to match Windows system fonts.

| Element | Size | Weight | Color | Extras |
|---------|------|--------|-------|--------|
| User display name | 16 | Bold (700) | White | Shadow: white, blur 3 |
| PSM (status message) | 13 | Normal | White 90% | Shadow: white, blur 2 |
| Group headers | 12 | Bold (700) | `#4A7A9C` | Uppercase, letter-spacing 0.8 |
| Contact name | 13 | Semi-bold (600) | `#1A2E3E` | — |
| Dialog title | 14 | Semi-bold (600) | White | — |
| Body text | 12–14 | Normal | `#243E57` | — |
| Sign-in title | 20 | Normal | `#2D5A92` | — |
| Status text (connecting) | 17 | Medium (500) | White | Shadow: black 33%, blur 6 |

---

## 5. Title Bar Glass Band

Used on the main window, chat window, and dialog headers.

```
Gradient: Linear, horizontal
Colors: #1A4978 → #3A8CC4 → #5CAEE0 → #2F7CB5
Stops:   0.0      0.40      0.55      1.0
Top border: white 20% (0x33FFFFFF), 1px
```

---

## 6. Shadows

| Context | Color | Blur | Offset |
|---------|-------|------|--------|
| Glass card drop shadow | `#1A4978` 12% | 16 | (0, 6) |
| Contact header shadow | black 8% | 4 | (0, 2) |
| Text shadow (on gradient bg) | white / black 33% | 2–6 | (0, 1) |

---

## 7. Component Patterns

### Dialog Windows
- Background: `#F4F8FB`
- Shape: `RoundedRectangleBorder(borderRadius: 14)`
- Border: white 60%
- Header: 4-stop gradient matching title bar
- Header border radius: top-left + top-right 14px

### Buttons
- **Primary (Sign in, OK)**: `ElevatedButton`, background `#3A8CC4`, white text, rounded 20px (pill) or 8px
- **Secondary (Cancel)**: `TextButton`, color `#4A6A84`
- **Dialog helper**: Gradient `#F4F8FB → #DAE6F0`, border `#B0C8D8`, rounded 8px

### Input Fields
- Height: 34–36px
- Fill: white
- Border: `#B0C8D8`, rounded 8px
- Focus border: `#5E8FB3`
- Hint text: italic, `#5D6C76`

### Contact List Groups
- Expand/collapse: Material `Icons.keyboard_arrow_down` / `Icons.chevron_right`
- Header text: uppercase, 12px bold, letter-spacing 0.8, color `#4A7A9C`

---

## 8. Loading / Connecting Screen

- Background: Same 4-stop sky gradient as main window
- Animation: 5 orbiting white dots in a circle (radius ~34% of container)
  - Each dot pulses between 3–5px radius
  - Staggered delay per dot (1/5 phase offset)
  - Full orbit: 2400ms
  - Opacity ranges 45%–100%
- Status text: white, 17px medium weight, subtle black shadow

---

## 9. Spacing Conventions

| Context | Value |
|---------|-------|
| Glass card padding | 20px horizontal, 20–24px vertical |
| Glass card margin | 14–16px |
| Dialog content padding | 14–16px horizontal |
| List item padding | 8–12px |
| Section spacing | 10–16px |
| Footer height | 42px (login), 4px (chat) |

---

## 10. Design Principles

1. **Translucency over opacity** — Prefer `BackdropFilter` glass over solid colored boxes.
2. **Soft borders** — Use `Colors.white.withOpacity(0.4–0.65)` instead of hard colored borders.
3. **Gradient depth** — Use 4-stop gradients (not 2) for richer dimensionality.
4. **Rounded everything** — No sharp corners; minimum 4px radius, prefer 8–16px.
5. **Light on light** — White translucent layers on blue gradient backgrounds create the Aero look.
6. **Consistent font stack** — Always include `fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial']`.
7. **Minimal shadows** — Subtle drop shadows only; avoid heavy elevation effects.
