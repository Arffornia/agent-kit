# Content PR body

Title: `content(<launcher|server|proxy|pack>): add <Mod> <version>` (or upgrade/remove).
Branch: `content/<kind>-<slug>`.

```
**What**
| Kind | Mod | Source | File | Change | Side deps |
|---|---|---|---|---|---|
| launcher, server | Applied Energistics 2 | curseforge 223794 | 6488853 -> 8992605 (19.2.10 -> 19.2.18) | upgrade | GuideME already present |

Players get this at next launcher start; servers at next pod restart.

**Why**
<request or issue URL>. Changelog: <URL>.

**How it was tested**
$ python3 modpack.py resolve curseforge 223794 8992605
fileId 8992605: appliedenergistics2-19.2.18.jar  versions=['NeoForge', '1.21.1']  type=release
$ python3 modpack.py dupes --project 223794
...
$ make check
...

**Risk & revert**
Revert this PR; players get the old file at next launcher start. <For removals: blocks and
items of the mod are lost from server worlds.>

**Follow-ups (pre-existing, not fixed here)**
- <PRE-EXISTING lines from modpack.py dupes>
```
