---
name: MacClean
description: Native-inspired browser prototype for deliberate storage inspection.
colors:
  blue: "#245fcc"
  blue-hover: "#194fae"
  text: "#24272c"
  muted: "#626970"
  line: "#e4e6e9"
  surface: "#f6f7f9"
  canvas: "#e8e9eb"
  workspace: "#ffffff"
  sidebar: "#f0f1f3"
  navigation-selected: "#dce6f6"
  navigation-text: "#204e9c"
  finding-selected: "#edf3ff"
  green: "#286848"
  rebuildable-background: "#edf5ef"
  amber: "#8c5d13"
  review-background: "#faf1e1"
  protected-text: "#7a5155"
  protected-background: "#f6ebed"
  focus: "#80aaf0"
  developer-storage: "#5079bd"
  application-storage: "#8b9fc2"
  personal-storage: "#b5c4dc"
  system-storage: "#aeb3bb"
typography:
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "29px"
    fontWeight: 650
    lineHeight: 1.2
    letterSpacing: "-.8px"
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "18px"
    fontWeight: 620
    letterSpacing: "-.3px"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "12px"
  path:
    fontFamily: "ui-monospace, SFMono-Regular, monospace"
    fontSize: "12px"
rounded:
  tag: "4px"
  control: "7px"
  note: "8px"
  history: "10px"
  summary: "12px"
  dialog: "15px"
spacing:
  small: "10px"
  medium: "16px"
  large: "20px"
  section: "24px"
  wide: "38px"
components:
  button-primary:
    backgroundColor: "{colors.blue}"
    textColor: "{colors.workspace}"
    rounded: "{rounded.control}"
    padding: "9px 13px"
  button-primary-hover:
    backgroundColor: "{colors.blue-hover}"
  button-secondary:
    backgroundColor: "{colors.workspace}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "9px 13px"
  button-link:
    textColor: "{colors.blue}"
    padding: "3px 0"
  search-field:
    backgroundColor: "{colors.workspace}"
    rounded: "{rounded.control}"
    padding: "10px 12px"
  navigation-selected:
    backgroundColor: "{colors.navigation-selected}"
    textColor: "{colors.navigation-text}"
    padding: "11px 12px"
  risk-rebuildable:
    backgroundColor: "{colors.rebuildable-background}"
    textColor: "{colors.green}"
    rounded: "{rounded.tag}"
    padding: "3px 6px"
    typography: "{typography.label}"
  risk-review:
    backgroundColor: "{colors.review-background}"
    textColor: "{colors.amber}"
    rounded: "{rounded.tag}"
    padding: "3px 6px"
  risk-protected:
    backgroundColor: "{colors.protected-background}"
    textColor: "{colors.protected-text}"
    rounded: "{rounded.tag}"
    padding: "3px 6px"
  storage-summary:
    rounded: "{rounded.summary}"
    padding: "25px 26px"
  finding-selected:
    backgroundColor: "{colors.finding-selected}"
    padding: "17px 10px"
  review-dialog:
    backgroundColor: "{colors.workspace}"
    rounded: "{rounded.dialog}"
    padding: "28px 32px"
    width: "min(680px, calc(100% - 30px))"
---

# Design System: MacClean

## Overview

**Creative North Star: "Native inspector workspace"**

A native-inspired inspector workspace: a quiet sidebar, white work surface, restrained blue selection, and system typography. Information is compact enough for developer inventories while paths, consequences, and unavailable actions remain legible.

This records the implemented browser prototype, not a production framework or native implementation decision. Decorative illustration and decorative metaphors are excluded by the approved direction.

**Key Characteristics:**
- Persistent navigation and a stable details inspector.
- Flat inventory rows with limited tonal selection.
- Itemized review with visible protection and recovery information.

## Colors

The palette uses subdued neutrals, operational blue, and soft semantic status tones.

### Primary
Blue identifies primary actions, links, checkbox accents, and the narrow active-row edge. Its darker hover companion belongs to primary buttons. Selected navigation and findings use pale blue surfaces rather than saturated blocks.

### Neutral
White forms the workspace and ordinary controls. Sidebar gray separates navigation; the darker outer canvas frames the centered app at wide widths. Text, muted text, and thin dividers establish hierarchy without heavy borders. The declared surface token is currently unused; it is retained as an existing source token, not a new prescribed surface.

### Status and storage
Green marks rebuildable findings and successful outcomes. Amber identifies findings requiring review and pending outcomes. Muted red marks protected or in-use findings. These colors always accompany text. The storage allocation bar and its legend share developer, application, personal, and system colors; these are category colors, not risk grades.

## Typography

The system font stack applies throughout. Paths use the dedicated monospaced stack. The hierarchy uses the headline, title, body, and label tokens above; finding names narrow to (13px) and remain semibold. Headings avoid uppercase styling. Paragraphs use a maximum measure of (72ch). Sizes use tabular numerals; overview opportunity sizes are (18px), inspector sizes (24px), and system metrics (27px). Dialog titles are (23px).

## Layout

The app is centered with a maximum width of (1800px) and a full-height flex shell. The sticky desktop sidebar is (216px) wide. A (68px) toolbar sits over a main area capped at (1430px), with desktop padding of (35px 38px 28px). Results use a flexible list of at least (340px), a (280px) inspector, and a (26px) gap. The inspector is sticky at (24px) from the viewport top. Ordinary inventory rows use bottom dividers, not separate card shells.

At widths up to (1100px), the sidebar narrows to (185px); main padding becomes (27px 25px), and results use a minimum (290px) list, a (240px) inspector, and a (16px) gap. At widths up to (800px), navigation becomes a horizontally scrolling strip, sidebar machine and engine details disappear, and the toolbar hides the breadcrumb. The inspector moves below the list with a top divider. Main padding becomes (25px 20px); headlines shrink to (26px). The overview footer becomes one column and metrics become two columns.

The selection bar is fixed beneath the workspace, aligned with the sidebar edge and, beyond (1800px), the centered shell. It spans the viewport on narrow screens, where its Clear selection button is hidden. Workspace bottom padding of (86px) reserves room. Review dialogs have a maximum height of (88vh), viewport-aware width, and narrow-screen padding of (23px).

## Elevation & Depth

Most surfaces remain flat. Thin borders and pale fills distinguish navigation, rows, and the inspector. The active segmented control has a small shadow; modal review and temporary notifications use stronger shadows. No frosted glass or background blur is implemented.

- Active segment: `0 1px 3px #25354b1f`.
- Review dialog: `0 18px 75px #00000040`, with a `#25324555` backdrop.
- Notification: `0 5px 22px #0002`.
- Active finding: `inset 2px 0 var(--blue)`; this is an alignment cue rather than elevation.

## Shapes

Compact controls use gently rounded corners. Tags are more square, while summary containers and dialogs have progressively softer corners, as recorded in the frontmatter. Dividers are (1px). The storage bar clips its segments within (5px) corners; legend swatches are small rounded squares. Navigation icons are outlined (18px) vectors with (1.6px) strokes. The brand is a small blue outlined square tilted by (-10deg), without an image asset.

## Components

### Buttons and fields
Primary buttons use white text on blue; secondary buttons use white surfaces and a thin gray border. Link buttons omit the border and fill. Hover transitions change background over (.15s). Disabled buttons use (0.5) opacity and a disallowed cursor. Buttons, inputs, and selects receive a (3px) focus outline in the focus color with a (3px) offset. Search fields flex within a wrapping filter row, alongside a native tool selector.

### Navigation and segmented controls
The active navigation item combines blue-tinted fill, darker blue text, semibold weight, and current-page semantics. Segmented controls sit on a pale gray track; their active option is white, subtly lifted, and blue-texted. Narrow navigation hides icons while retaining text.

### Findings and inspector
A finding has an independent selection checkbox, an inspection button, a text risk tag, and a right-aligned size. Inspection and selection are distinct. Protected and in-use checkboxes are disabled. The inspector shows the selected finding's reason, path, planned handler, and removal method, with an add/remove selection action only when usable. Long paths wrap anywhere. Search and tool filtering also apply to container results, including Docker, Podman, Colima, OrbStack, Rancher Desktop, and Lima, without introducing a separate visual language.

### Storage summary and opportunities
The bordered storage summary uses a horizontal proportional allocation bar and a wrapping text legend. Opportunity rows use a small icon tile, title and subtitle, size, and chevron. They support pointer activation and Enter or Space activation. This prototype does not add a custom focus rule for the opportunity row itself.

### Selection, review, and feedback
Selections persist across navigation and filters in memory. The fixed bar summarizes count and candidate size, then opens a native browser modal dialog with each action's consequences. The acknowledgment checkbox gates the simulated cleanup action. Completed, failed, and skipped outcomes are separated in the result and history. Exclusions and selections reset on reload. The scan progress animation runs for (1.5s), and reduced-motion preferences disable animations and transitions while setting scan progress to full width. Notifications use a polite live region.

### Mole engine management
The lower sidebar adds a Mole engine destination using the existing navigation treatment. Its labeled native scenario selector reuses filter controls. The engine status card reuses the storage summary shell, caption, divided metadata rows, monospaced executable path, and right-aligned actions. It shows installed, missing, update-available, unavailable-check, and verification-failure scenarios without new colors or typography.

Detection and update actions reuse disabled button states and scan progress. Installation and upgrade reviews reuse the modal, review rows, and primary action. Each card and review identifies the operation as simulated. Missing or unverified engines disable Mole-owned finding selection and provide an inspector explanation. Changing the preview scenario clears selection. These views introduce no new visual identity or production integration; the real lifecycle requirements remain in FUNCTIONALITY.md.

## Do's and Don'ts

- Do preserve the sample-data label and explicit action consequences.
- Do pair risk colors with readable status text.
- Do keep sizes aligned with tabular numerals and allow paths to wrap.
- Do preserve selection across filters and sections; changing the engine preview scenario clears selection.
- Do not imply that candidate file sizes equal recovered disk space.
- Do not turn inventory rows into decorative cards.
- Do not use age alone to visually imply that data is disposable.
- Do not add decorative illustration or a new typeface to this prototype.
