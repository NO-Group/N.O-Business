# Design system

The interface is dark, dense enough for desk work and legible on a phone. It
takes its colour from the N.O Business mark and uses that colour sparingly:
surfaces are near-black navy, text is cool white, and the bright brand hues
mark what can be acted on or what needs attention.

All of it is defined in two files:

- [`tokens.dart`](../app/lib/core/design_system/tokens.dart): colours,
  gradients, spacing, radii, shadows, motion, breakpoints, type scale.
- [`theme.dart`](../app/lib/core/design_system/theme.dart): the Material 3
  theme built from those tokens (buttons, inputs, dialogs, chips, menus).

Screens never hard-code a colour, size or text style. If a value is missing,
it is added to the tokens first.

## Colour

| Token | Value | Use |
| --- | --- | --- |
| `background` | `#050817` | Window background |
| `backgroundRaised` | `#080D22` | Navigation surfaces |
| `surface` | `#0B1230` | Cards, sheets |
| `surfaceHigh` | `#111A40` | Inputs, hovered rows, chips |
| `border`, `borderStrong` | `#1B2650`, `#2B3A75` | Hairlines; focus and emphasis |
| `cyan` | `#00EFFF` | Links, selected navigation, informational accents |
| `cobalt` | `#075BFF` | Primary actions (with violet) |
| `violet` | `#761BFF` | Primary actions, secondary data series |
| `magenta` | `#F000E8` | Brand gradient only |
| `emerald` | `#00E9A8` | Success, money received |
| `warning` | `#FFB84D` | Low stock, drafts, items needing attention |
| `danger` | `#FF5470` | Overdue, destructive actions, errors |

Text contrast, measured against the lightest surface each style appears on
(`surfaceHigh`), using the WCAG 2 formula:

| Style | Value | Ratio |
| --- | --- | --- |
| `textPrimary` | `#F5F7FF` | 15.8 : 1 |
| `textSecondary` | `#A3ADC6` | 7.5 : 1 |
| `textMuted` | `#7A86A8` | 4.7 : 1 |
| White on `cobalt` / `violet` (button label) | | 5.3 : 1 / 6.2 : 1 |

All meet AA for body text. Status is never conveyed by colour alone: badges
carry a word, and overdue or low-stock figures carry a caption.

The four-colour brand gradient is reserved for the mark and one hero accent
per screen. The primary button uses the quieter cobalt-to-violet gradient.
Glow is allowed on at most one element in a view.

## Type

Manrope (bundled, SIL Open Font License) in five weights. Figures are tabular
wherever numbers are compared in a column.

| Style | Use |
| --- | --- |
| `display`, `headline` | Auth and onboarding headings, page titles |
| `title`, `subtitle` | Card and section headings, row titles |
| `body`, `bodySmall` | Content and supporting text |
| `label`, `overline` | Field labels, captions, small caps group headers |
| `metric`, `numeric` | Dashboard figures; amounts in lists |

PDFs use DejaVu Sans, also bundled, because it covers currency symbols such
as ₦ that many fonts lack.

## Space, shape and motion

- Spacing follows a 4-point scale: 2, 4, 8, 12, 16, 24, 32, 48.
- Radii: 8 (controls), 12 (inputs, small cards), 16 (cards), 24 (sheets and
  dialogs), pill (badges).
- Depth comes from borders and surface steps first. One shadow style exists
  for floating layers.
- Motion is short: 120 ms for state changes, 200 ms for layout, ease-out.

## Layout

| Width | Navigation | Content |
| --- | --- | --- |
| under 600 | Bottom bar with the first destinations and a "More" sheet | Single column, sheets open from the bottom |
| 600 to 1023 | Icon rail | One or two columns |
| 1024 and up | Sidebar with labelled groups | Up to 1280 wide; detail pages use a main column and a side panel |

The same destination list drives all three, so a module is never reachable
on one form factor and missing on another. Destinations a role cannot open
are not shown, and the routes themselves show a "no access" state if reached
anyway.

## Components

In [`core/design_system/components/`](../app/lib/core/design_system/components):

| Component | Purpose |
| --- | --- |
| `PageScaffold` | Title, subtitle, actions and optional back button for every page |
| `ResponsiveGrid`, `TwoPane` | Column layouts that collapse on narrow windows |
| `DetailLoader` | Loading, missing and error handling for a single record page |
| `NobCard`, `SectionCard` | Surfaces, with an optional header and edge-to-edge content |
| `ListPanel`, `RowGroup`, `ListRow`, `RowIcon`, `TrailingAmount` | Lists of records |
| `MetricTile` | A headline figure with context |
| `StatusBadge` | A status word with a tone |
| `PrimaryButton`, `DangerButton` | The main and the destructive action, with a busy state |
| `SearchField`, `PasswordField`, `LabeledValue`, `FormMessage` | Form parts |
| `LoadingView`, `EmptyState`, `ErrorState`, `NoAccessState`, `AsyncView` | The states every data view must handle |
| `showNobSheet`, `SheetScaffold`, `confirmAction`, `showNobSnack` | Sheets, confirmations and feedback |
| `BrandMark` | The logo |

Rules the screens follow:

- Every view that loads data handles loading, empty, error (with retry) and
  no-permission states.
- Destructive actions ask for confirmation and say what will be lost.
- Actions a role cannot perform are hidden rather than shown disabled.
- Errors shown to users are sentences written for them. Database and network
  details go to the log, not the screen.
- Forms validate before submitting and show server refusals next to the
  submit button.

## Not yet done

No screen has been reviewed on a device, so this system has not had a visual
pass: spacing, truncation and touch-target sizes need checking in use. There
is no light theme.
