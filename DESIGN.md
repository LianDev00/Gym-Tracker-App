---
version: "alpha"
name: "Gym Tracker — Anatomic Dot Matrix"
description: "Anatomical dot-matrix interface for a workout tracker. The hero element is a human figure (male or female) composed of a dot field, with muscle groups that change color and pulse based on the exercises being performed in the current session. Dark mode, emerald palette, glass surfaces, retro-futurist and meditative."
colors:
  primary: "#064E3B"
  secondary: "#022C22"
  tertiary: "#059669"
  neutral: "#020604"
  background: "#020604"
  surface: "#064E3B"
  text-primary: "#ECFDF5"
  text-secondary: "#A7F3D0"
  border: "#059669"
  accent: "#064E3B"
  muscle-idle: "#064E3B"
  muscle-secondary: "#059669"
  muscle-active: "#10B981"
  muscle-dominant: "#ECFDF5"
  muscle-recovering: "#022C22"
  silhouette-outline: "#065F46"
typography:
  display-lg:
    fontFamily: "Geist"
    fontSize: "72px"
    fontWeight: 100
    lineHeight: "72px"
    letterSpacing: "-0.025em"
  body-md:
    fontFamily: "Geist"
    fontSize: "12px"
    fontWeight: 100
    lineHeight: "19.5px"
  label-md:
    fontFamily: "JetBrains Mono"
    fontSize: "12px"
    fontWeight: 200
    lineHeight: "16px"
rounded:
  md: "0px"
spacing:
  base: "8px"
  sm: "1px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  gap: "8px"
  card-padding: "32px"
  section-padding: "32px"
components:
  button-primary:
    backgroundColor: "{colors.secondary}"
    textColor: "#D1FAE5"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "12px"
  card:
    backgroundColor: "#030906"
    rounded: "{rounded.md}"
    padding: "32px"
---

## Overview

The hero of the interface is an **anatomical figure** built from a regular grid of dots, masked by a body silhouette and partitioned into muscle-group regions. Each region reflects training state in real time, turning the figure into a live readout of the session.

- **Composition cues:**
  - Layout: Grid
  - Content Width: Bounded
  - Framing: Glassy
  - Grid: Strong
  - Hero: Centered anatomic dot-figure

## Colors

Dark mode with emerald accent. The palette extends the original system with **muscle-state semantic colors** so the body figure reads as data, not decoration.

### Base palette
- **Primary (#064E3B):** Main accent and emphasis color.
- **Secondary (#022C22):** Supporting accent for secondary emphasis.
- **Tertiary (#059669):** Reserved accent for supporting contrast moments.
- **Neutral (#020604):** Background and supporting chrome.

### Muscle state palette
Each region of the body figure renders one of these states. Colors are ordered by visual weight (dim → bright) so the eye is drawn to the dominant muscle of the session.

| State        | Color     | Meaning                                                   |
|--------------|-----------|-----------------------------------------------------------|
| `idle`       | `#064E3B` | Not trained today. Base dot color, ~40% opacity.          |
| `recovering` | `#022C22` | Trained recently (last 24–48h). Dimmer than idle.         |
| `secondary`  | `#059669` | Engaged as support muscle in current session.             |
| `active`     | `#10B981` | Currently being trained (set in progress).                |
| `dominant`   | `#ECFDF5` | Primary muscle group of the session. Brightest, pulsing.  |

### Gradients
- `bg-gradient-to-b from-emerald-900/30 to-transparent`
- `radial-gradient` from `emerald-900/20` to transparent (used behind the figure for depth halo)

## Typography

Unchanged from base system. Geist for display + body, JetBrains Mono for technical labels (muscle names, set/rep counts).

- **Display (`display-lg`):** Geist, 72px, weight 100, line-height 72px, letter-spacing -0.025em.
- **Body (`body-md`):** Geist, 12px, weight 100, line-height 19.5px.
- **Labels (`label-md`):** JetBrains Mono, 12px, weight 200, line-height 16px. Use for muscle group tags and numeric overlays on the figure.

## Layout

Grid composition, 8px base rhythm, bounded content width. The body figure occupies the centered hero slot; muscle-group legends and stats sit in surrounding cards.

- **Layout type:** Grid
- **Content width:** Bounded
- **Base unit:** 8px
- **Scale:** 1px, 8px, 10px, 12px, 14.4px, 24px, 32px, 40px
- **Section padding:** 32px, 80px
- **Card padding:** 32px

## Elevation & Depth

Glass surfaces, hairline gradient borders, soft blur. The body figure sits on a transparent surface — depth comes from the dot fade, not from a card behind it.

- **Surface style:** Glass
- **Borders:** 1px #059669; 1px #064E3B; 1px #065F46
- **Blur:** 4px

## Body Figure System

The figure is the centerpiece of the dashboard. It must be **legible at a glance** as a human body, and **scannable** as session state.

### Views
- **Front view** (default): chest, abs, biceps, quads, front delts, hip flexors, anterior calves.
- **Back view**: lats, traps, triceps, glutes, hamstrings, lower back, rear delts, posterior calves.
- The user can toggle / swipe between views, or display both side-by-side on wide screens.

### Gender variants
Two silhouette presets — `figure-male` and `figure-female` — share the same muscle-group taxonomy and region IDs. Only the silhouette outline and proportions differ; the dot grid, masks, and color logic are identical. User picks once in onboarding; selection persists in profile.

### Muscle groups (region IDs)

These IDs are the contract between the painter, the data model, and the session layer. They are introduced as a **new enum `MuscleGroup`**, parallel to the existing `MuscleCategory`. The two coexist:

- `MuscleCategory` — coarse (Pecho, Espalda, Hombros, …). Drives list filtering and grouping in the existing UI. **Unchanged.**
- `MuscleGroup` — granular. Drives the figure and per-exercise muscle attribution. **New.**

Each region has polygon coordinates defined per view. Some regions are visible from both views (`shoulders_lateral`, `traps`, `forearms`, `calves`) and carry polygons for each.

| Region ID            | Anatomical name              | Front view | Back view |
|----------------------|------------------------------|:----------:|:---------:|
| `chest`              | Pectorals                    | ✓          |           |
| `shoulders_front`    | Anterior deltoid             | ✓          |           |
| `shoulders_lateral`  | Lateral / medial deltoid     | ✓          | ✓         |
| `shoulders_rear`     | Posterior deltoid            |            | ✓         |
| `biceps`             | Biceps brachii               | ✓          |           |
| `triceps`            | Triceps brachii              |            | ✓         |
| `forearms`           | Forearm flexors / extensors  | ✓          | ✓         |
| `abs`                | Rectus abdominis             | ✓          |           |
| `obliques`           | External obliques            | ✓          |           |
| `traps`              | Trapezius                    | ✓ (upper)  | ✓         |
| `lats`               | Latissimus dorsi             |            | ✓         |
| `mid_back`           | Rhomboids, mid trap          |            | ✓         |
| `lower_back`         | Erector spinae               |            | ✓         |
| `quads`              | Quadriceps                   | ✓          |           |
| `adductors`          | Hip adductors                | ✓          |           |
| `hamstrings`         | Hamstrings                   |            | ✓         |
| `glutes`             | Gluteus maximus / medius     |            | ✓         |
| `calves`             | Gastrocnemius / soleus       | ✓ (side)   | ✓         |

### MuscleCategory ↔ MuscleGroup rollup

The existing coarse category resolves to one or more granular regions. When the UI groups exercises by `MuscleCategory`, the figure can still light up all the matching regions.

| MuscleCategory | MuscleGroup(s)                                            |
|----------------|-----------------------------------------------------------|
| `pecho`        | `chest`                                                   |
| `espalda`      | `lats`, `mid_back`, `lower_back`, `traps`                 |
| `hombros`      | `shoulders_front`, `shoulders_lateral`, `shoulders_rear`  |
| `biceps`       | `biceps`, `forearms`                                      |
| `triceps`      | `triceps`, `forearms`                                     |
| `piernas`      | `quads`, `hamstrings`, `adductors`, `calves`              |
| `gluteos`      | `glutes`                                                  |
| `core`         | `abs`, `obliques`, `lower_back`                           |
| `cardio`       | — (figure stays in `idle` / `recovering`)                 |

### Region states

Each region holds one `MuscleState` value at any time. State for the whole figure is a single map:

```
Map<MuscleGroup, MuscleState>
```

States, in priority order (later wins if a muscle qualifies for multiple):
1. `idle`
2. `recovering`
3. `secondary`
4. `active`
5. `dominant`

### Data model

The figure is driven by data, not by hardcoded scenes. Three additions to the existing model:

```dart
enum MuscleGroup { /* the 18 region IDs above */ }

enum MuscleRole { dominant, secondary }

class Exercise {
  // ...
  final MuscleCategory muscleCategory;          // existing — coarse, drives list filtering
  final Map<MuscleGroup, MuscleRole> muscles;   // new — granular, drives the figure
}
```

DB: a new join table `exercise_muscles (exercise_id, muscle_group, role)`. Preset exercises ship with seed data; custom exercises get a small picker UI (out of scope for this document).

`MuscleCategory` is **not deprecated** — it stays as the category for list grouping and filters. `MuscleGroup` is parallel and granular, used wherever per-muscle precision matters (the figure, volume analytics, recovery tracking). The rollup table above is the bridge between the two.

### Exercise → muscle mapping

The figure does not know about exercises directly. The session layer resolves each exercise to its `Map<MuscleGroup, MuscleRole>` and reduces those across the session into the figure's state map. Reference patterns (full seed lives in code, not here):

| Exercise           | Dominant            | Secondary                                |
|--------------------|---------------------|------------------------------------------|
| Bench press        | `chest`             | `shoulders_front`, `triceps`             |
| Overhead press     | `shoulders_front`   | `shoulders_lateral`, `triceps`, `traps`  |
| Lateral raise      | `shoulders_lateral` | `shoulders_front`, `traps`               |
| Face pull          | `shoulders_rear`    | `mid_back`, `traps`                      |
| Pull-up            | `lats`              | `biceps`, `shoulders_rear`, `mid_back`   |
| Barbell row        | `mid_back`          | `lats`, `biceps`, `shoulders_rear`       |
| Deadlift           | `lower_back`        | `hamstrings`, `glutes`, `traps`          |
| Squat              | `quads`             | `glutes`, `hamstrings`                   |
| Hip thrust         | `glutes`            | `hamstrings`                             |
| Bicep curl         | `biceps`            | `forearms`                               |
| Tricep extension   | `triceps`           | `forearms`                               |
| Calf raise         | `calves`            | —                                        |

## Dot Matrix Rendering

The figure replaces the original WebGL/Three.js soil-map. Same visual language (dot field, breathing pulse, retro-futurist) but reframed as anatomy.

### Visual recipe
- **Field:** regular grid of dots, ~6–8px spacing on mobile, scaled up for tablets.
- **Mask:** dots are only drawn where they fall inside the body silhouette polygon.
- **Coloring:** each dot inherits the color of the muscle-group region it falls in. Dots outside any region (neck, head, hands, feet — non-trained zones) use `idle` at very low opacity.
- **Edge softness:** dots near the silhouette edge get reduced opacity so the figure has a soft anti-aliased boundary instead of a hard polygon edge.
- **Outline:** optional 1px stroke of `silhouette-outline` (#065F46) around the silhouette to anchor the form.

### Motion
- **Global breathing pulse:** all dots modulate brightness ±10% on a slow sine, period ~3.5s. Same feel as the original "slow breathing pulse."
- **Dominant pulse:** the `dominant` region pulses brighter (±25%) on a faster cycle (~1.2s) to draw the eye.
- **State transitions:** when a region changes state, interpolate color over **300ms** with `cubic-bezier(0.4, 0, 0.2, 1)` (matches the existing motion tokens).
- **Active set:** while a set is in progress, the active region adds a brief flash on each rep tick (~150ms ease-out).

### Interaction
- **Tap a region** → opens that muscle group's stats (volume, last trained, top exercises).
- **Long-press** → preview state across last 7 days (subtle ghost overlay).
- **Pointer parallax:** very subtle drift (≤2px) on hover/tilt, retained from the original design intent.

## Flutter Implementation

Notes for translating the above into Dart. Not prescriptive — adjust to the project's existing structure.

### Core widgets
- `BodyFigure` — public widget. Props: `view` (front/back), `gender`, `Map<MuscleGroup, MuscleState> states`, `onRegionTap`.
- `BodyFigurePainter extends CustomPainter` — does the actual rendering.
- `BodyMask` — silhouette + per-region polygons. Stored as data, not SVG, so hit-testing and dot masking share the same source of truth.

### Recommended approach
1. Define each muscle region as a `List<Offset>` polygon in **normalized coordinates (0..1)**, one set per `(view, gender)`.
2. In `paint()`:
   - Compute scaled polygons for the current canvas size.
   - Build a dot grid covering the bounding box.
   - For each dot: point-in-polygon test against silhouette → keep or skip; if kept, find which region it belongs to → pick color from `states[region]`.
   - Apply pulse modulation based on an `Animation<double>` driven by an `AnimationController` (repeat).
3. Hit testing: implement `hitTest` on the widget by reusing the same polygon data. No need for a separate gesture layer.

### Why not SVG
`flutter_svg` works for static silhouettes, but you'd lose dot-matrix aesthetics and hit-testing per region gets awkward. CustomPainter keeps the dot field, masking, hit testing, and animation in one place.

### Why not Rive
Overkill for state-driven coloring. Rive is great for rigged animations; here the "animation" is a color map plus a pulse. Stay in CustomPainter unless you later want skeletal motion.

## Components

### Buttons
- **Primary:** background #022C22, text #D1FAE5, radius 0px, padding 12px, border 1px solid rgba(6, 95, 70, 0.4).

### Cards and Surfaces
- **Card surface:** background #030906, border 1px solid rgb(1, 4, 2), radius 0px, padding 32px.

### Body Figure card
- Glass surface with the figure centered, no internal padding (figure goes edge to edge inside the card's content area).
- Optional 1px gradient border shell (see Elevation & Depth).
- Below the figure: a horizontal legend of the 5 muscle states, using `label-md` typography.

### Iconography
- **Treatment:** Linear.
- **Sets:** Solar.

## Do's and Don'ts

### Do
- Do drive the figure from a single `Map<MuscleGroup, MuscleState>` — never hardcode region colors in widgets.
- Do keep silhouette + region polygons in **normalized coordinates** so the figure scales without re-authoring.
- Do treat `MuscleGroup` and `MuscleCategory` as parallel enums with a one-to-many rollup; don't collapse them into one.
- Do attribute every exercise to its `Map<MuscleGroup, MuscleRole>` — the figure must never read `MuscleCategory` directly.
- Do reuse the 5-state palette exactly as defined; new states require a design review.
- Do keep the global breathing pulse subtle — it's ambient, not an attention-grabber.

### Don't
- Don't use SVG sprites for the figure body — the dot-matrix aesthetic is core to the design language.
- Don't introduce per-exercise colors. Color encodes **state**, not exercise type.
- Don't draw region labels on top of the figure by default. Labels appear on tap, not always-on.
- Don't add a third gender silhouette without first abstracting proportions into tokens.
- Don't animate region color changes faster than 300ms — it reads as flicker.

## Motion

Controlled, interface-led. Same tokens as the base system; the body figure adheres to these.

**Motion Level:** moderate
**Durations:** 150ms, 300ms, 700ms
**Easings:** ease, cubic-bezier(0.4, 0, 0.2, 1)
**Hover Patterns:** color, stroke
**Figure-specific:** breathing pulse 3.5s sine (global), dominant pulse 1.2s sine, rep flash 150ms ease-out, state transition 300ms.
