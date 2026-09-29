# Last Stand Tycoon: Idea

> **Tonight's monsters are tomorrow's menu.**
> Run a diner by day, hold it by night.

## Original idea (from the author)

Thể loại Hybrid-Casual: Arcade Idle (quản lý tài nguyên, nâng cấp căn cứ) + Squad RPG/Tower Defense
(chiến đấu bảo vệ thành trì). Vòng lặp: Chiến đấu → Thu hoạch thịt → Giao dịch đổi thịt lấy vàng
với NPC xếp hàng → Mở rộng/nâng cấp. Joystick ảo một ngón, "hành động khi đứng yên", chòi canh +
hàng rào gỗ, thẻ tướng (ví dụ Pháp sư) tạo yếu tố bất ngờ.

## Pitch

A one-thumb, portrait, 3D low-poly web game. You run a roadside diner at the edge of monster-filled
wilds. At night, monsters attack in 3 waves; your hero, towers, fences and two adventurer guards
hold the line, and every monster poofs into a cartoon steak. At dawn you pick a hero card, then
spend the day hauling steaks from the freezer to the counter, selling to travelers and turning gold
into towers and fences. Stand on the "Close up" sign when you are ready for the next night.

Reference feel (mechanics only, no assets or names): My Little Universe, Alien Invasion: RPG Space.

## Purpose and v0.1 scope

- **Real commercial test, web only for v0.1** (itch.io, phone and desktop browser).
- **v0.1 gate:** 5 friends each play at least one full day and night; at least 3 ask for more,
  unprompted. Only after that: Android/iOS, store rules, ads or IAP.
- Designed for retention: short sessions, quit anytime, non-punishing failure.
- Engine: Godot 4.7, GDScript, Compatibility renderer, portrait 720×1280.
- Timeline: about 4–6 weeks solo.

## Design pillars

1. **Satisfying growth:** things pile up and the diner visibly grows.
2. **One-thumb flow:** floating virtual joystick, no buttons for core actions; stand still to
   interact.
3. **Pressure you can plan for:** nights threaten the diner; your build choices decide if you hold.

## Core loop: one day/night cycle is the unit of play

**Night (the last stand)**
- Exactly 3 waves. A 10-second breather starts once a wave is fully dead; dawn comes the moment
  wave 3 is cleared. Stronger defenses mean a shorter night.
- Hero, towers and guards auto-attack. Killed monsters drop steaks; the hero can pick them up.
- No building or selling at night; travelers leave.
- Enemy targeting: a fence in the way, then a guard hero in reach, then the diner. Towers are never
  targeted. A knocked-out hero respawns at the diner door after 3 seconds.
- Night 1 is winnable with the hero alone; first combat within 30 seconds of starting.
- UI: 3 moon icons for night progress (no timer) and an edge arrow showing where the next wave
  comes from.

**Dawn (the natural place to stop)**
- Every steak left outside goes into the freezer (no spoilage in v0.1).
- Base and standing buildings heal to full. Destroyed fences are gone; rebuilding costs gold.
- Pick 1 of 3 hero cards. This is the day's decision moment.

**Day (the tycoon)**
- Haul steaks from the freezer to the counter, sell to queued travelers, collect gold, and spend it
  on towers and fences (the only gold sink). No day timer.
- Start the night by standing still on the "Close up" sign. It pulses when nothing is left to do.
- No cooking, seating, orders or serving minigame: the day is only haul, sell, build.

## Hero cards

- Pool of 7 card types: 5 upgrades (hero damage, attack speed, move speed, carry capacity, gold per
  steak) and 2 adventurers (Archer, Tank), who eat at the diner and stay to fight.
- Adventurers guard 2 fixed posts near the diner. The first offer is always Archer + Tank + one
  upgrade.
- Duplicates are never wasted: upgrades stack, and a duplicate adventurer levels that hero up.
  Max level 5 per card.
- Picks are permanent (no roguelite runs); waves scale with the day number.

## Failure and mercy

- If the diner falls, the night ends and the game reloads the start of that night, back in the day.
  Quitting mid-night costs exactly the same.
- Each failed retry makes enemies weaker (HP and damage 15% lower per failure, floor 40%), shown
  only as a flavor line such as "The monsters look tired tonight."

## Save

- One local save in the browser (plus a backup), written automatically: at night start, at dawn,
  after the card pick, after each build, and every few seconds during the day when something
  changed. At most the current night and a few seconds of the day can be lost.

## Tone and art

- Bright, comedic, cartoon steaks, no gore.
- 3D low-poly with CC0 packs: Kenney (Food, Castle, Tower Defense kits) and Quaternius (animated
  monsters and characters). Every asset's license is logged when it is first used.
- English only in v0.1; all text is translatable, and the font must cover Vietnamese diacritics.

## Later (not in v0.1)

Mobile apps, ads, IAP, gacha; Mage, Chef and follower heroes; moving guard heroes; extra waves on
later days; spoilage; offline earnings; a second resource; second map, bosses, cloud save,
localization.
