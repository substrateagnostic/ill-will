# PAR FOR THE CURSE

*Sabotage mini-golf on a course that remembers. Build the traps. Survive the
traps. Blame your friends.*

One couch, one mouse, 2–4 players, 9 rounds on a single hole that accretes
every trap you draft and every ball that dies — by the end it's a haunted
Rube Goldberg museum of the evening's grudges, and the gravestones have
round numbers on them.

## How to play

```
godot --path .        # or open the project in Godot 4.6+ and hit Play
```

Each round, in reverse-standings order (losers first):

1. **DRAFT** — pick 1 of 3 trap cards. Last place drafts from the visibly
   nastier ☠ CURSED deck. Grudge (♠, earned by dying) buys an extra cursed
   option.
2. **BUILD** — place your trap anywhere legal (mouse to move, scroll / R to
   rotate, click to place, 25s or you forfeit it). You must putt through it
   too.
3. **PUTT** — stroke rotation, leader tees off first into the unknown. Drag
   back from your ball and release. Balls collide. Windmills windmill.
   The Crusher crushes.

Scoring: finish order earns 5/3/2/1. **Royalties**: your trap kills someone,
you get +2 — forever, every round, every victim (†). Die and you leave a
gravestone on the course (it has collision; bank shots off your friend's
corpse are encouraged). Nobody is ever eliminated. Nine rounds; when it's
over, the camera flies low over everything you built to each other.

## Testing / dev harness

Headless-ish autoplay for verification (window opens, plays itself, quits):

```
godot --path . -- --skipmenu --players=4 --rounds=3 --seed=42 \
  --autobuild --autoplay=7.3:-3.96,7.3:-1.32,7.3:1.32,7.3:3.96 \
  --shots=1500,5000 --quitafter=9000
```

`--shots=N,...` captures PNGs to `verify_out/` at those frames;
`--autoputt=power,angle,frame`, `--aimshow`, `--forcetrap=id` also available.
After adding assets: `godot --headless --editor --import --quit --path .`

## Credits

Design & code: Claude (Fable 5), directed in partnership with Alex
Galle-From. Assets (all CC0): [Kenney](https://kenney.nl) minigolf kit, UI,
particles, audio; [KayKit](https://kaylousberg.itch.io) character packs.
Fonts: Fredoka, Baloo 2 (OFL), Luckiest Guy (Apache 2.0). Engine: Godot 4.

над. нашу. присутствие. память.
