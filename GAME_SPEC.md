# DEFUSE - Game Specification

## Game Overview

DEFUSE is a portrait-oriented hypercasual arcade game for Android.

The objective is simple:
Tap and defuse bombs before they explode.

The game is designed to be extremely easy to understand while becoming increasingly intense through grid expansion, additional active bombs, and decreasing timers.

The overall visual style is premium, clean, minimal, and polished.

---

# Core Gameplay

The player is presented with a grid of bombs.

Only active bombs can explode.

The player taps active bombs before their timer expires.

Every successful defusal increases the score.

Wrong taps have NO penalty.

The player has three lives.

Whenever a bomb explodes:

• one life is lost
• localized explosion animation plays
• explosion sound plays

After losing all three lives:

Game Over.

---

# Bomb Behaviour

Bombs have three states.

## Idle

Uses supplied bomb PNG.

No animation.

---

## Armed

Uses supplied PNG animation sequence.

The bomb DOES NOT flash.

Instead the bomb gradually fills with red.

The red fill indicates remaining time.

As the timer approaches zero, the supplied animation naturally communicates urgency.

---

## Explosion

If not defused:

Play supplied explosion animation.

Play supplied explosion sound.

Explosion remains localized.

Neighboring bombs must remain clearly visible.

---

# Difficulty Progression

Difficulty is based ONLY on successful defusals.

Not score.

Not elapsed time.

Progression:

Stage 1
Grid: 2x2
Active bombs: 1
Timer: 3.8s
Advance after 10 successful defusals.

Stage 2
Grid: 2x2
Active bombs: 2
Timer: 3.5s
Advance after 25 total successful defusals.

Stage 3
Grid: 3x3
Active bombs: 2
Timer: 3.2s
Advance after 45 total successful defusals.

Stage 4
Grid: 3x3
Active bombs: 3
Timer: 3.0s
Advance after 70 total successful defusals.

Stage 5
Grid: 4x4
Active bombs: 3
Timer: 2.8s

Terminal difficulty.

No further increases.

The timer remains constant during each stage.

It only changes when entering the next stage.

Display a short stage transition popup whenever the stage changes.

---

# Scoring

Every successful bomb defusal:

+1 Score

Score resets after every game.

Best Score is permanently saved.

---

# Gems

The game uses Gems.

NOT Coins.

The supplied UI mockups still display Coins.

This is ONLY placeholder artwork.

Every occurrence of Coins must become Gems.

Random bombs may contain one Gem.

Defusing that bomb awards one Gem.

Collected Gems are permanently saved.

---

# Lives

Player starts with 3 lives.

Every bomb explosion removes one life.

Wrong taps do nothing.

No penalties for tapping inactive bombs.

---

# Bomb Skins

Default Bomb

Alarm Clock

Plasma Bomb

Future skins should require minimal additional code.

Gameplay must remain identical regardless of skin.

---

# Audio

Use supplied assets.

bomb.wav

bomb_pop.wav

explode.wav

Never replace supplied sounds.

---

# UI

The supplied UI mockups are the SINGLE SOURCE OF TRUTH.

They are NOT inspiration.

Do NOT redesign them.

Do NOT reinterpret them.

Recreate them as accurately as possible.

---

# Save Data

Save permanently:

Best Score

Total Gems

Selected Skin

Settings

---

# Performance

Target:

60 FPS

Portrait only.

Android.

---

# Coding Philosophy

Readable over clever.

Modular.

Small scripts.

Well documented.

Beginner friendly.

Every important function should explain:

What it does.

Why it exists.

When it is called.