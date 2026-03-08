# Verba — Design System

## Brand Concept

**"Your voice never leaves the room."**

Verba exists at the intersection of two worlds: the organic imperfection of human voice and the crystalline precision of on-device machine processing. The brand resolves this tension with a single promise: the machine serves the voice, not the other way around.

If Discord's world is "your place to talk," Verba's world is **"your place to think out loud."**

## Design Principles

### 1. Proof over promise

Never claim what you can show. If you say "fast transcription," you've failed — instead, let the user see text appear in real-time. Every surface should carry evidence: a demo, a state change, a visual response. Words are the last resort.

Applies to: LP copy, onboarding flows, settings descriptions, feature announcements.

### 2. Nothing leaves this room

The entire experience should feel like a closed, warm, private space. No analytics badges, no tracking, no external embeds in contexts where privacy is the message. The design itself embodies the privacy promise.

Applies to: Architecture decisions (no telemetry), UI metaphors (contained spaces), LP design (no third-party scripts beyond fonts).

### 3. One person made this, and that's the point

Don't hide the solo developer — feature it. In a world of faceless SaaS companies, one human who built something careful is more trustworthy than a corporation with a privacy policy. The craft, the intentionality, the smallness — these are assets.

Applies to: Footer attribution, about sections, communication tone, changelog voice.

## Visual Language

### Color System

Two-accent narrative system — cool for machine, warm for voice:

| Token | Value | Usage |
|-------|-------|-------|
| `--bg` | `#0c0b0f` | Page background (warm plum-black, not cold blue) |
| `--bg-raised` | `#15141a` | Cards, elevated surfaces |
| `--bg-surface` | `#1c1b23` | Interactive elements, inputs |
| `--accent` (cool) | `#7c6cfc` | Buttons, links, tech elements — the "machine" |
| `--accent-light` | `#9b8aff` | Hover states, highlights |
| `--warm` | `#f0a060` | Voice-related moments, streaming text, active recording |
| `--text` | `#ede8e1` | Primary text (warm off-white, never pure white) |
| `--text-sub` | `#9a948a` | Secondary text |
| `--text-dim` | `#5a5650` | Muted labels, captions |
| `--green` | `#3dd68c` | Success, "ready" states |
| `--red` | `#f04747` | Recording indicator |
| `--orange` | `#fbbf24` | Processing, "formatting" states |

### Typography

Three typefaces in conversation:

| Role | English | Japanese | Purpose |
|------|---------|----------|---------|
| Display | Instrument Serif | Shippori Mincho 500 | Editorial, literary. "Words matter here." |
| Body | Inter | Noto Sans JP | Clean, readable, modern |
| Code/Tech | JetBrains Mono | JetBrains Mono | Model names, tech identifiers. Inline in body text. |

The serif display face is the single biggest differentiator from generic SaaS/AI tool design. It signals: this is a tool for language, not enterprise productivity.

**Japanese-specific rules:**
- `font-feature-settings: "palt" 1` on display headings (tightens punctuation spacing)
- Line-height: 1.35–1.4 for headings (vs 1.05 in English)
- Letter-spacing: 0.04em for display, 0.02em for body
- Headlines rewritten for Japanese rhythm, not translated

### Texture & Depth

- **Noise overlay**: SVG fractal noise at 3.5% opacity, `mix-blend-mode: overlay`. Eliminates the "pure CSS" feeling.
- **Warm shadows**: Bottom shadows use `rgba(60, 40, 20, 0.3)` instead of pure black.
- **Frosted glass**: Floating elements use `backdrop-filter: blur(24px) saturate(150%)` with gradient borders (lighter top, darker bottom).
- **Three visual planes**: Background → Content → Floating (nav, indicators, modals).

### Motion

**Philosophy: "Breathe, don't bounce."**

- Slow ease-in (600–800ms), quick ease-out (200ms)
- No stagger delays on card groups
- No bounce/spring on UI elements (too consumer-app)
- Waveform animations use sine-composite noise for organic feel
- The hero waveform compresses and fades on scroll — voice settling into text

### Iconography

- No emoji icons. Ever.
- Use minimal SVG line icons when needed
- Prefer showing product UI over abstract icons
- Privacy checkmarks use simple `✓` in colored circles, not shield icons

## Copy Voice

### Tone

A calm, competent friend who happens to be technical. Not a salesperson. Not a professor. Someone who built something useful and is showing it to you.

### Rules

- **Banned words**: revolutionary, seamless, leverage, cutting-edge, unlock, supercharge, AI-powered, just
- **Lead with the verb or result**, not the feature name
- **Short sentences for impact, long for explanation.** Never two long sentences in a row.
- **Person**: "Verba" as subject for product actions. "You" for user experience. "Your" for data possessives. Never "we."
- **Use periods aggressively.** Commas are for lists, not connecting independent thoughts.

### Example headlines

| Section | Copy | Why |
|---------|------|-----|
| Hero | Talk. It types. Nothing leaves your Mac. | Three short sentences. Function then identity. |
| Privacy | Your voice stays on your machine. | "Your" repeated. "Machine" is visceral. |
| Formatting | Raw speech in, clean text out. | Parallel structure, no adjectives. |
| Controls | Press a key. Start talking. | Two imperatives. Physical. |

## Applying to the Product

These principles extend beyond the LP into the macOS app:

### Color mapping

The app already uses a Discord-inspired dark theme (`DS.` tokens). Map the LP's two-accent system:
- `DS.blurple` → machine/tech actions (buttons, selected states)
- Warm amber → recording indicator, streaming text, voice-related feedback
- Background warmth: shift from pure cool-dark to slightly warm dark

### Typography in-app

- Keep SF Pro / system font for UI (macOS convention)
- Use the warm off-white `#ede8e1` instead of pure white for primary text
- Apply `--text-sub` and `--text-dim` equivalents for hierarchy

### Motion in-app

- Recording start: smooth fade-in, not a hard cut
- Streaming text: character-by-character appearance (already implemented)
- State transitions: 200–300ms ease, no bounce
- Floating indicator: frosted glass matches LP treatment

### Privacy as design

- No external network calls except explicit user actions (model download, update check)
- Settings that affect privacy should be visually distinct (not buried)
- "Works offline" should be discoverable, not just documented
