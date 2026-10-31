#!/usr/bin/env python3
"""Static UI-text checks for the Arffornia mod (spec 006 rules), until the client test harness exists.

Usage (from the Arffornia_Mods root):
  mc_lang_lint.py [--assets src/main/resources/assets/arffornia] [--src src/main/java] [--ratio 1.3] [--json]
  mc_lang_lint.py --pseudo build/en_xx.json      # also write the pseudo-locale (+30%, [ ], accents)

ERROR  a key used in Java (`Component.translatable("k")`, `.translatable("k")`, `"k"` in a
       `*.arffornia.*` literal) that is missing from en_us.json
ERROR  a key in en_us.json missing from fr_fr.json, or a %s / %1$s placeholder mismatch
ERROR  `Component.literal("...")` with prose in main sources (player text must be a lang key);
       commands ("/..."), single tokens and lines marked `// i18n-ignore` are exempt
WARN   a GUI key (gui./tooltip./message./container.) whose French text is longer than RATIO x
       the English one: overflow risk at GUI scale 3-4. Checked for real by the harness later.
WARN   French typography: missing (narrow) no-break space before : ; ? ! » or after «
WARN   a non-registry key not following gui|tooltip|message.arffornia.<screen>.<element>
Exit code: 1 on any ERROR.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

REGISTRY = re.compile(r"^(block|item|entity|effect|enchantment|biome|fluid|creativetab|itemGroup|key|key\.category|"
                      r"arffornia\.configuration|death|advancements?|subtitles|jei|emi|config|commands?|chat)\.")
STYLE = re.compile(r"^(gui|tooltip|message|container|screen|hud)\.arffornia\.[a-z0-9_]+(\.[a-z0-9_]+)+$")
GUI = re.compile(r"^(gui|tooltip|message|container|screen|hud)\.")
PH = re.compile(r"%(?:\d+\$)?[sdf]")
NBSP = "\u00a0\u202f"
USE = re.compile(r"""(?:translatable|translatableWithFallback|Translatable)\(\s*"([a-z0-9_.]+)"|"((?:gui|tooltip|message|container|screen|hud)\.arffornia\.[a-z0-9_.]+)\"""")
LITERAL = re.compile(r"""Component\.literal\(\s*"([^"]*[A-Za-z]{2,}[^"]*)"\s*\)""")
ACCENT = str.maketrans("aceinouyACEINOUY", "àçéîñöûýÀÇÉÎÑÖÛÝ")


def pseudo(s: str) -> str:
    out, i = [], 0
    for m in PH.finditer(s):
        out.append(s[i:m.start()].translate(ACCENT))
        out.append(m.group(0))
        i = m.end()
    out.append(s[i:].translate(ACCENT))
    body = "".join(out)
    pad = "~" * max(1, round(len(s) * 0.3))
    return f"[{body}{pad}]"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", default=None)
    ap.add_argument("--src", default="src/main/java")
    ap.add_argument("--ratio", type=float, default=1.3)
    ap.add_argument("--pseudo")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    assets = a.assets or next(iter(sorted(glob.glob("src/main/resources/assets/*/lang/.."))), None)
    if not assets or not os.path.isfile(os.path.join(assets, "lang", "en_us.json")):
        print("ERROR no assets/<modid>/lang/en_us.json found: run from the mod root or pass --assets", file=sys.stderr)
        return 2
    en = json.load(open(os.path.join(assets, "lang", "en_us.json"), encoding="utf-8"))
    fr_path = os.path.join(assets, "lang", "fr_fr.json")
    fr = json.load(open(fr_path, encoding="utf-8")) if os.path.isfile(fr_path) else {}
    out: list[dict] = []

    def add(level: str, where: str, msg: str) -> None:
        out.append({"level": level, "where": where, "msg": msg})

    off_style: list[str] = []
    if not fr:
        add("ERROR", fr_path, "fr_fr.json missing or empty")
    for k, v in en.items():
        if fr and k not in fr:
            add("ERROR", k, "missing in fr_fr.json")
            continue
        f = fr.get(k)
        if f is None:
            continue
        if sorted(PH.findall(v)) != sorted(PH.findall(f)):
            add("ERROR", k, f"placeholders differ: en {PH.findall(v)} fr {PH.findall(f)}")
        if GUI.match(k) and len(v) >= 4 and len(f) > a.ratio * len(v):
            add("WARN", k, f"fr is {len(f) / len(v):.2f}x en ({len(f)} vs {len(v)} chars): overflow risk")
        for m in re.finditer(r"(?<=[^\s" + NBSP + r"])([:;?!»])", f):
            if m.group(1) == ":" and re.search(r"\d:\d|https?:|%\d\$", f[max(0, m.start() - 6):m.end() + 2]):
                continue
            add("WARN", k, f"fr: no no-break space before '{m.group(1)}': {f!r}")
            break
        if re.search(r"«(?=[^" + NBSP + "])", f):
            add("WARN", k, f"fr: no no-break space after '«': {f!r}")
        if not REGISTRY.match(k) and not STYLE.match(k):
            off_style.append(k)
    if off_style:
        add("WARN", f"{len(off_style)} key(s)", "not gui|tooltip|message.arffornia.<screen>.<element> (rename only in a "
            "dedicated PR, keys are API for datapacks and translators): " + ", ".join(off_style[:6]) + (" ..." if len(off_style) > 6 else ""))
    for k in fr:
        if k not in en:
            add("WARN", k, "only in fr_fr.json (stale?)")
    used: dict[str, str] = {}
    for p in glob.glob(os.path.join(a.src, "**", "*.java"), recursive=True):
        text = open(p, encoding="utf-8", errors="ignore").read()
        for m in USE.finditer(text):
            key = m.group(1) or m.group(2)
            line = text.count("\n", 0, m.start()) + 1
            used.setdefault(key, f"{p}:{line}")
        for m in LITERAL.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            lit, src_line = m.group(1), text.splitlines()[line - 1]
            # commands, ids and numbers are not prose; `// i18n-ignore` opts a line out explicitly
            if lit.startswith("/") or " " not in lit.strip() or "i18n-ignore" in src_line:
                continue
            add("ERROR", f"{p}:{line}", f'Component.literal("{m.group(1)[:40]}") is player text: use a lang key')
    for key, where in sorted(used.items()):
        if key not in en and not key.endswith("."):
            add("ERROR", where, f"key '{key}' used in code but missing from en_us.json")
    if a.pseudo:
        os.makedirs(os.path.dirname(a.pseudo) or ".", exist_ok=True)
        json.dump({k: pseudo(v) for k, v in en.items()}, open(a.pseudo, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        add("INFO", a.pseudo, f"pseudo-locale written ({len(en)} keys)")
    if a.json:
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        for o in sorted(out, key=lambda o: ({"ERROR": 0, "WARN": 1, "INFO": 2}[o["level"]], o["where"])):
            print(f"{o['level']:5} {o['where']}: {o['msg']}")
        print(f"{len(en)} en keys, {len(fr)} fr keys, {len(used)} keys referenced in code: "
              f"{sum(o['level'] == 'ERROR' for o in out)} error(s), {sum(o['level'] == 'WARN' for o in out)} warning(s)")
    return 1 if any(o["level"] == "ERROR" for o in out) else 0


if __name__ == "__main__":
    sys.exit(main())
