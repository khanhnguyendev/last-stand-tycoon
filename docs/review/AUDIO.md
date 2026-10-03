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
was replaced (same pack first, else the loudest-measuring file whose name fits). Distances below are
`mean + clamped volume_db - class target` (negative = under target); all numbers are measured, nobody listened.

| id | first choice | measured (mean / peak) | after clamp | replacement |
|---|---|---|---|---|
| coin | casino-audio/chips-stack-1.ogg | -28.4 / -1.5 dB | 3.9 dB under target | casino-audio/chips-stack-4.ogg (same pack, same name kind; 2.8 dB under target, the loudest-measuring chips-stack file) |
| collect | rpg-audio/handleCoins.ogg | -28.8 / 0.0 dB | 11.8 dB under target | rpg-audio/dropLeather.ogg (-18.7 / -0.1, 1.7 dB under; name fits a coin pouch) |
| card_open | casino-audio/card-fan-1.ogg | -21.8 / -0.8 dB | 4.3 dB under target | rpg-audio/bookClose.ogg (-18.8 / 0.0, 1.8 dB under; a cover closing, the name loosely fits an opening) |

Alternatives measured and rejected (ffmpeg volumedetect on the source packs):
- coin (target -24): chips-stack-1 (mean -28.4, peak -1.5, -3.9 dB), chips-stack-2 (mean -29.0, peak -0.2, -6.0 dB), chips-stack-3 (mean -29.3, peak -1.0, -5.3 dB), chips-stack-5 (mean -29.0, peak -0.4, -6.0 dB), chips-stack-6 (mean -28.0, peak -0.6, -4.5 dB). chips-stack-4 is the best of the chips-stack files. Not chosen: casino chip-lay-1 (mean -25.1, peak -2.1, -0.1 dB) measures closer to target; I kept a chips-stack file for the name match.
- collect (target -18): chips-handle-1 (mean -31.1, peak -0.3, -14.1 dB), chips-handle-2 (mean -35.1, peak -1.2, -17.1 dB), chips-handle-3 (mean -28.1, peak -0.9, -10.6 dB), chips-handle-4 (mean -30.2, peak -1.5, -11.7 dB), chips-handle-5 (mean -24.8, peak -0.5, -7.3 dB), chips-handle-6 (mean -26.2, peak -1.4, -8.2 dB), handleCoins2 (mean -34.0, peak -10.7, -6.5 dB). Every coin or chip-handling file is at least 6.5 dB under target.
- card_open (target -18): card-fan-2 (mean -29.4, peak -0.8, -11.9 dB), bookOpen (mean -33.6, peak -11.5, -5.1 dB), cards-pack-open-1 (mean -28.2, peak 0.0, -11.2 dB), cards-pack-open-2 (mean -28.7, peak -2.7, -9.2 dB), card-slide-1 (mean -27.6, peak -1.5, -9.1 dB), card-slide-2 (mean -25.5, peak -1.0, -7.5 dB), card-slide-3 (mean -26.9, peak -1.4, -8.9 dB), card-slide-4 (mean -27.6, peak -1.7, -9.1 dB), card-slide-5 (mean -30.7, peak -1.9, -12.2 dB), card-slide-6 (mean -29.3, peak -2.0, -10.3 dB), card-slide-7 (mean -31.1, peak -0.5, -13.6 dB), card-slide-8 (mean -29.4, peak -1.7, -10.9 dB). Every other casino card file is at least 7.5 dB under target.

collect and card_open went cross-pack (to rpg-audio) beyond the plan's same-pack rule, because no same-pack file with a
fitting name reaches the target within 3 dB (the lists above show it). dropLeather and bookClose are the loudest-measuring
rpg-audio files whose names fit; both are weak matches and flagged for the author to audition.

Two entries sit close to the limit: coin (-2.8 dB) and click (-2.4 dB, peak clamp).

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


Task 3a spike (2026-10-03), debug and profile web builds of branch `s5/p1-t03a-spike`, temporary hook (removed before commit).
Method: both music tracks loaded and registered with `AudioServer.register_stream_as_sample`, timed with `Time.get_ticks_usec()`;
decoded size = mix rate x 2 channels x 4 bytes x length; `export/pw_audio_spike.mjs` reads `window.LST_AUDIO` (the D-212 shell hook).

| Measure | Result |
|---|---|
| Chromium 153.0.8010.12 (Playwright), desktop 720x1280, AudioContext before any input | `suspended` (created at about 3.0 s, 10 s with no input) |
| Same, 1 s after `page.mouse.click` on the canvas centre | `running` (statechange logged at 13.5 s, the tap) |
| iOS Simulator (iPhone 17 Pro, Safari), 25 s, no input | `interrupted` (not `suspended`; treat any state other than `running` as locked) |
| Registration time, both tracks | 115-124 ms on Chromium (5 runs), 121 ms on the iOS Simulator |
| Decoded size per track | day 15.7 MiB (46.8 s), night 18.9 MiB (56.1 s) at 44.1 kHz; 17.1 MiB and 20.5 MiB at 48 kHz |
| Decoded total | 34.6 MiB at 44.1 kHz (Chromium), 37.7 MiB at 48 kHz (iOS); budget 48 MiB |
| Mix rate | 44100 (Chromium), 48000 (iOS Simulator) |
| Wasm heap (JS side) | not readable: `HEAP8`, `Module.HEAP8`, `wasmMemory` are all undefined in the 4.7.2 shell; `performance.memory` is quantised (57.5 MiB, unchanged) |
| Godot static memory, before / after registering both tracks (Chromium debug build) | `MEMORY_STATIC_MAX` 41.86 MiB / 79.20 MiB (+37.33 MiB); `OS.get_static_memory_usage()` 41.02 MiB / 41.02 MiB |
| Underrun or `Audio` console lines | none, in 60 s runs of samples and stream |
| Mean `proc_ms` (profile build, 7 x 10 s windows, run 1 / run 2) | no music 125.4 / 128.3; samples 128.2 / 132.3; stream 118.2 / 132.1 |

The `proc_ms` numbers come from software WebGL on a desktop, so the scatter (106-159 ms per window) is far larger than
the 1.0 ms threshold and no stream or sample delta can be read from them; they only show no gross cost.

Memory: `MEMORY_STATIC_MAX` rose 37.33 MiB while static usage returned to 41.02 MiB, so the WASM-side frames are transient,
but the WASM heap's high-water mark never shrinks (up to +37 MiB if the heap had no free room). The Web Audio buffers
(34.6 MiB at 44.1 kHz, 37.7 MiB at 48 kHz) live outside the WASM heap and persist. Total cost of `samples` with both tracks:
about 72 MiB (Chromium) to 78 MiB (iOS). Evidence: `media/s5/task03a/chromium_rerun_console.txt` (the label shots of the first
run were not kept; `chromium_gesture_check_*.png` are the gesture check, `ios_before_gesture.png` still shows the label).

Decision (main session, D-212): `AudioManifest.MUSIC_MODE = &"swap"`. Rule (1) passes as written (decoded total ≤ 48 MiB), but
its intent was the added memory, and that is 72–78 MiB. Rule (2), stream playback, showed no underrun, but its CPU cost cannot
be read on software WebGL, and in a single-threaded build a stream is mixed on the main thread, so the first-wave stall and any
long frame would glitch the music; samples were introduced to avoid exactly that. Rule (3) keeps one track registered at a
time: about 36–41 MiB at most, for one registration of about 60–70 ms (half of the 115–138 ms for both tracks) at each music
change, which happens at a phase change behind the phase banner. Task 7 measures that hitch on the profile build.
Notes for Task 3b: on iOS Safari the unlocked state is `running`, and the locked state may read `interrupted`.
Playwright's `page.evaluate` and `waitForFunction` carry a user gesture, so an evaluate before the tap can make the context
`running`; `export/pw_audio_spike.mjs` therefore evaluates nothing before the tap. An init script logs
`LST_STATE <ms> ctx<i>=<state>` to the console on creation and on every statechange, the "before" states are read from those
lines, and the script exits 1 if no context was seen before the tap, if any was `running` before it, or if none is `running`
1 s after it. The only tap in the Chromium runs is the `page.mouse.click`.

### Swap check (Task 3b)

`export/pw_audio_swap_check.mjs` (removed in the lazy-mode commit; its output is kept in `media/s5/task03b/swap_check_console.txt`)
counted `AudioContext.createBuffer` calls and `AudioBuffer` collections (`FinalizationRegistry`) on the debug web build, in
Chromium with `--js-flags=--expose-gc`, through night, J (day), N (night). Godot 4.7.2 has no `unregister_stream_as_sample`, so swap
mode dropped every reference to the old track. Result: the old track's registered buffer was never collected (the night buffer of
19,793,456 bytes was still live after J and several `gc()` passes), and the return to night created a new registered buffer pair
instead of reusing one (four music buffers, 75,895,424 bytes, live after N + gc). Swap leaks one track per change and
re-registers on return, so it was dropped (D-212 amendment).

### Music mode: lazy

`AudioManifest.MUSIC_MODE = &"lazy"`: a music stream is registered as a sample on first use and stays referenced in the
director's `_streams`. `export/pw_audio_music_check.mjs` (output: `media/s5/task03b/music_check_console.txt`, exit 0) measured on
the same build: a track's first play creates two buffers, the registered sample (night 19,793,456 bytes, day 16,515,056 bytes,
kept) and a playback copy of the same size that is collected after the track stops. Live music bytes after gc: after J
52,823,568 (night + day + the playing day copy); after N 56,101,968 (night + day + the playing night copy). The switch back to
night created one music buffer (the playback copy) and no second registration: "night re-registered after N: no".
