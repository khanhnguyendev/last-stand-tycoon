# Audio review (S5 Task 1)

## Chosen without listening

Every sound and both music tracks were picked without hearing them (D-211). The picks are by pack and file name,
measured length and loudness (`ffprobe` duration, `ffmpeg volumedetect` peak and mean), and, for the jingles, a pitch
contour from an STFT peak tracker. To swap a line, edit its entry in `art/audio/audio_manifest.gd` (and copy the file into
its `assets/` folder; the validator fails on an audio file the manifest does not name). `volume_db` is
`round_to_0.5(class target - mean)`, clamped so `peak + volume_db <= -1.0`. Class targets: repeated -24 dB, single -18 dB,
music -26 dB; each entry's mean after `volume_db` is within 3 dB of its target.

| id | file | duration (s) | peak (dB) | mean (dB) | volume_db | reason |
|---|---|---|---|---|---|---|
| throw | kenney-rpg-audio/knifeSlice2.ogg | 0.57 | 0.0 | -19.1 | -5.0 | name fits a thrown knife |
| hit | kenney-impact-sounds/impactPunch_medium_000.ogg | 0.43 | -1.1 | -17.2 | -7.0 | punch on a Boar |
| poof | kenney-impact-sounds/impactSoft_heavy_000.ogg | 0.51 | -0.9 | -17.4 | -6.5 | soft thud for the kill poof |
| pickup | kenney-interface-sounds/pluck_001.ogg | 0.10 | 0.0 | -20.4 | -3.5 | short pluck |
| take | kenney-interface-sounds/drop_003.ogg | 0.19 | -1.1 | -19.6 | -4.5 | freezer take |
| stock | kenney-impact-sounds/impactPlate_heavy_001.ogg | 0.35 | -0.9 | -17.4 | -6.5 | plate on the counter |
| coin | kenney-casino-audio/chips-stack-4.ogg | 0.23 | -1.2 | -26.8 | 0.0 | chip clink per sale (swapped in, see below) |
| collect | kenney-rpg-audio/dropLeather.ogg | 0.42 | -0.1 | -18.7 | -1.0 | leather pouch drop for cash in hand (swapped in, see below) |
| build_tick | kenney-impact-sounds/impactWood_light_000.ogg | 0.27 | -1.1 | -22.3 | -1.5 | wood tap |
| build_done | kenney-music-jingles/jingles_PIZZI04.ogg | 0.56 | -2.9 | -16.3 | -1.5 | rising major sixth A3->F#4 |
| card_open | kenney-rpg-audio/bookClose.ogg | 0.23 | 0.0 | -18.8 | -1.0 | book cover thump for a card opening (swapped in, see below) |
| card_pick | kenney-casino-audio/cards-pack-take-out-1.ogg | 0.50 | -0.1 | -18.9 | -1.0 | take a card |
| horn | kenney-music-jingles/jingles_SAX03.ogg | 1.12 | -10.6 | -20.0 | 2.0 | sax semitone trill C#5/C5, an alarm |
| wave_clear | kenney-music-jingles/jingles_PIZZI16.ogg | 0.46 | -5.4 | -17.3 | -0.5 | rising fifth D#4 A4 A#4 |
| diner_hit | kenney-impact-sounds/impactWood_heavy_000.ogg | 0.31 | -0.9 | -19.6 | -4.5 | heavy wood knock |
| fail | kenney-music-jingles/jingles_PIZZI14.ogg | 0.92 | -4.9 | -15.0 | -3.0 | descending G#4 F#4 E4 D4 C4 |
| dawn | kenney-music-jingles/jingles_PIZZI10.ogg | 0.80 | -4.6 | -15.4 | -2.5 | rising D4 E4 F#4 G4 |
| guard_down | kenney-music-jingles/jingles_PIZZI09.ogg | 0.57 | -5.1 | -16.6 | -1.5 | falling E4->D4 |
| guard_up | kenney-music-jingles/jingles_PIZZI08.ogg | 0.57 | -4.8 | -16.6 | -1.5 | rising D4->E4 |
| click | kenney-interface-sounds/click_001.ogg | 0.10 | -1.4 | -26.4 | 0.0 | UI click |

Folders are `assets/kenney-<pack>/`. Total audio size is recorded in the Task 1 report and checked by the validator
(budget 2.5 MB = 2,621,440 B).

### Swaps under the 3 dB rule

Three first-choice files could not reach their class target within 3 dB once the -1 dB peak clamp was applied, so each
was replaced (same pack first, else the nearest-sounding loud file):

| id | first choice | measured (mean / peak) | after clamp | replacement |
|---|---|---|---|---|
| coin | casino-audio/chips-stack-1.ogg | -28.4 / -1.5 dB | 3.9 dB under target | casino-audio/chips-stack-4.ogg (same pack, same name kind; 2.8 dB under target, the closest chip sound) |
| collect | rpg-audio/handleCoins.ogg | -28.8 / 0.0 dB | 11.8 dB under target | rpg-audio/dropLeather.ogg (no coin sound in the pack is loud enough; a dropped leather pouch) |
| card_open | casino-audio/card-fan-1.ogg | -21.8 / -0.8 dB | 4.3 dB under target | rpg-audio/bookClose.ogg (no other casino card sound is loud enough; a soft cover thump) |

Two entries sit close to the limit: coin (-2.8 dB) and click (-2.4 dB, peak clamp). Weak candidates for the author's ears:
card_open and collect (the swaps are the least literal matches).

## Music

| id | file | duration (s) | peak (dB) | mean (dB) | volume_db |
|---|---|---|---|---|---|
| day | oga-happy-adventure-loop/happy_adventure_loop.mp3 | 46.81 | 0.0 | -13.5 | -12.5 |
| night | oga-chiptune-adventures/stage_2.mp3 | 56.10 | 0.0 | -10.9 | -15.0 |

- day: https://opengameart.org/content/happy-adventure-loop, `License(s): CC0`, `Author: TinyWorlds`, uploader TinyWorlds.
- night: https://opengameart.org/content/4-chiptunes-adventure, `License(s): CC0`, `Author: SubspaceAudio`
  (Juhani Junkala's account; the pack's INFO.txt says he is the author and released the tracks under CC0).
- Both are re-encoded to mono, 32 kHz, 64 kbit/s MP3, at most 60 s:
  `ffmpeg -y -i <src> -t 60 -ac 1 -ar 32000 -c:a libmp3lame -b:a 64k <dst>`. Each folder's `LICENSE.txt` has the page, date,
  licence field, author, original file name and SHA-256.
- `loop=true` is set in both `.mp3.import` files. An MP3 loop may have a small gap at the loop point.

## Spike results

