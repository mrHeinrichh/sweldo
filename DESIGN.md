# Sweldo design guide

The reference for every screen in the web app (`src/`) and the Flutter app (`sweldo_flutter/`).
Both clients render the same design; they differ only in how they reach Freighter. When this guide
and a screen disagree, fix the screen in both clients.

## Principles

Sweldo follows the spirit of Apple's Human Interface Guidelines: clarity, deference and depth.

1. **One job per screen.** Every screen, sheet or step answers one question. When a form needs
   scrolling to finish, split it into steps instead.
2. **Content is the interface.** Names, amounts and paydays carry the page. Chrome stays quiet:
   few borders, one accent per view, no decoration that doesn't explain something.
3. **Plain words for everyone.** Someone who has never used crypto should understand every label.
   Say what happens ("Lock payroll on Stellar", "Claim"), never how the system works inside.
4. **Generous space, confident type.** Large headings with tight tracking, short lines, room
   around every group. Hierarchy comes from size and weight, not from colour.
5. **Depth with purpose.** 3D, tilt and shadow belong to objects you could hold (the phone, a
   payout ticket, a rubber stamp), never to text or panels.
6. **Motion answers people.** Transitions show where you went: steps slide in the direction you
   move, a claimed payout flips to its receipt, a stamp lands when something is final. The only
   unprompted motion is the demo payroll printing in on the home page.
7. **Respect everyone.** 44pt touch targets, visible keyboard focus, AA contrast, reduced motion
   honoured everywhere.

## Don't

These read as templated or "AI-made" and are off-brand for Sweldo:

- Crypto clichés: coins, rockets, moons, blockchain cubes, neon, cyberpunk, holograms.
- Gradient blobs, glassmorphism, glows, sparkles, confetti, emoji in the interface.
- All-caps eyebrow labels, gradient text, one highlighted word in a headline.
- The SaaS card kit: every block in an identical rounded card with the same soft shadow.
- Meta strings joined with middle dots, arrows appended to button labels.
- Controls that exist only to demo the app (for example a "Shuffle" button). Demo data should
  simply be there.
- Lorem ipsum or fake numbers that don't add up. Every sample payroll splits evenly.

## Tokens

Defined once per client: `src/styles/tokens.css` and `sweldo_flutter/lib/core/theme/`.

| Role | Token | Value |
| --- | --- | --- |
| Page | `paper` | `#F2F5F0` |
| Alternate rows | `greenbar` | `#E1EBDD` |
| Surfaces | `sheet` | `#FCFDFB` |
| Rules and borders | `rule` | `#D2DBCF` |
| Text | `ink` / `ink-muted` / `ink-faint` | `#14213A` / `#52607A` / `#7D8799` |
| Actions, stamps | `stamp` / `stamp-deep` / `stamp-wash` | `#5B3CC4` / `#452C9E` / `#EDE8FB` |
| Money that's ready | `payday` / `payday-wash` | `#1C7449` / `#DCEFE2` |
| Problems | `danger` / `caution` | `#B3261E` / `#8F5207` |

**Type.** Archivo for the interface, IBM Plex Mono only for keys and hashes people compare
character by character, Manrope ExtraBold only in the "sweldo." wordmark.
Scale: 12 caption, 14 body small and labels, 16 body, 21 title, 24 amount, 36 headline,
48 to 60 display. Headlines run 800 weight with negative tracking.

**Space.** 4, 8, 12, 16, 24, 32, 48, 64. **Radius** follows hierarchy: 6 paper, 10 fields and
buttons, 14 panels, 22 sheets. **Motion:** 160ms quick, 280ms standard, 480ms deliberate,
ease-out-cubic to enter, ease-in-out-cubic to move.

**Breakpoints** follow Tailwind: `sm` 640, `md` 768, `lg` 1024 (desktop layout), `xl` 1280.

## Signature elements

Use these sparingly; each one means something.

- **Greenbar paper** with tractor-feed holes: any list that *is* a pay schedule.
- **Punch slots:** empty while locked, ringed when payday comes, filled violet once claimed.
- **The violet stamp:** only for something final (Claimed, Locked, Converted).
- **The iPhone frame:** whenever the product is shown on a phone.

## Patterns

**Stepped flows.** A form that would scroll becomes steps (the payroll form is *Team*,
*Schedule*, *Review and lock*).

- Progress sits at the top and doubles as navigation.
- Each step opens with a question as its title ("Who are you paying?").
- A footer holds Back and Continue. Continue names the next step.
- People can move freely between steps. The last step lists anything missing, with a way back
  to fix it, and holds the one primary action.
- Changing step scrolls the form's top into view and slides the new step in from the side
  you're moving toward.

**Required fields** say so beside their label. Errors appear once a field is left, or when
someone tries to continue; the first field to fix takes focus. A field with an error shakes once
and its message slides in beneath it. An employee's wallet can't be the connected wallet: that's
flagged as soon as the address is complete, and locking stays blocked until it's fixed.

**Sample data.** Forms open with fresh, realistic sample values every time the page is entered:
names, pay and a schedule. Wallet addresses are never invented, and an address someone typed is
kept.

**Notices** sit next to the action that caused them, say what happened and what to do next,
and never apologise.

**Sheets and dialogs.** Dialogs on wide screens, bottom sheets on phones. A sheet that is
signing something can't be dismissed by tapping outside it.

## Copy

- Sentence case everywhere. Active verbs on buttons; the result keeps the same word
  ("Lock payroll" leads to "Payroll locked").
- Write for the person getting paid: "Your pay is in your wallet", not "Claim transaction
  confirmed".
- Numbers carry units: "4 payouts of 110 XLM".
- Errors explain the fix: "Add a wallet address for each employee."

## Marketing visuals

Posters and announcements follow the same rules: one idea, one hero, lots of air.
For image generators:

> A premium product announcement for Sweldo, a payroll app that lets anyone get paid on payday.
> Apple keynote calm: one real iPhone with the Sweldo app on screen, soft studio light, a single
> light neutral background (#F2F5F0), a left-aligned headline in a tight neo-grotesque in deep
> navy (#14213A), violet (#5B3CC4) and payroll green (#1C7449) only inside the app. Restraint
> over decoration; it should feel like apple.com, not a crypto ad.

Avoid: crypto symbols, coins, neon, holograms, gradient blobs, glassmorphism, sparkles, emoji,
stock people, hands, multiple phones, distorted devices, garbled text, all-caps labels.

## Before shipping a screen

- It does one job, and its title says what that job is.
- It reads cleanly without the accent colour.
- It works at 390pt and 1440px, with keyboard only, and with reduced motion.
- The web build and the Flutter build match side by side.
