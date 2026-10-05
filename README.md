# TrainingTracker

Displays the active Grounds Tome or Field Manual training regime and its
designated-target progress.

Load it with `//lua load TrainingTracker`. The tracker reads the page details,
then updates when FFXI reports `You defeated a designated target. (Progress: X/Y)`.

Commands:

```text
//tt show
//tt hide
//tt clear
//tt reset
//tt pos <x> <y>
//tt move <dx> <dy>
//tt test
```

`pos` sets an absolute screen position. `move` offsets the current position.
Coordinates are saved automatically, including positions changed by dragging.

If the addon sees progress before it sees the tome page, it displays the
progress with unknown targets and fills in the targets when a page is later
read. Multiple target groups are kept as separate progress lines, including
groups with the same total. `//tt test` displays a mock panel with two target
groups and duplicate progress totals; it does not alter game state.
