#!/usr/bin/env python3
"""Check en/fr translation key parity for the three Arffornia i18n formats.

Usage:
  i18n_parity.py [--root DIR] [--source en] [--target fr] [--json] [--strict]
  i18n_parity.py --pair path/en.json path/fr.json     # any two files of the same format

Auto-detects, under --root (default: .):
  launcher  src/renderer/src/i18n/locales/{en,fr}.json   vue-i18n, nested, {name} / @:linked / plural "a | b"
  website   lang/{en,fr}/*.php and lang/{en,fr}.json      Laravel, :name / :NAME placeholders
  mod       src/main/resources/assets/*/lang/{en_us,fr_fr}.json   Minecraft, flat, %s / %1$s / %%

Reports, per file pair: keys missing in the target, keys only in the target (usually stale),
placeholder mismatches, empty values, values equal to their key (a raw key on screen), and
(--strict) target values identical to the source (possibly untranslated).
Exit code: 0 parity, 1 a missing key / placeholder mismatch / empty value / raw key
(identical values too with --strict), 2 usage or parse error.
Needs `php` on PATH only for Laravel .php files.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys

PH = {
    "vue": re.compile(r"\{\s*[\w.]+\s*\}|@:[\w.]+|@\.[a-z]+:[\w.]+"),
    "laravel": re.compile(r"(?<![\w:]):[A-Za-z_][A-Za-z0-9_]*"),
    "mc": re.compile(r"%(?:\d+\$)?[sdf]|%%"),
}


def flatten(obj, prefix: str = "") -> dict[str, str]:
    out: dict[str, str] = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            out.update(flatten(v, f"{prefix}.{k}" if prefix else str(k)))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            out.update(flatten(v, f"{prefix}.{i}"))
    else:
        out[prefix] = "" if obj is None else str(obj)
    return out


def load(path: str) -> dict[str, str]:
    if path.endswith(".php"):
        if not shutil.which("php"):
            raise RuntimeError("php is not on PATH (needed for Laravel .php lang files)")
        r = subprocess.run(["php", "-r", "echo json_encode(require $argv[1]);", path],
                           capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            raise RuntimeError(f"cannot load {path}: {r.stderr.strip() or 'no output'}")
        data = json.loads(r.stdout)
        return flatten(data) if isinstance(data, (dict, list)) else {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    # Laravel lang/en.json and Minecraft lang files are flat: keys may contain dots, keep them
    if all(not isinstance(v, (dict, list)) for v in data.values()):
        return {k: "" if v is None else str(v) for k, v in data.items()}
    return flatten(data)


def placeholders(fmt: str, s: str) -> list[str]:
    found = PH[fmt].findall(s)
    if fmt == "mc":  # %s and %1$s are interchangeable only when there is one argument
        return sorted(found)
    # Laravel and vue-i18n substitute by name: compare the set (a translation may use one twice
    # or once); :name / :Name / :NAME are the same placeholder with different casing.
    if fmt == "laravel":
        return sorted({x.lower() for x in found})
    return sorted({x.replace(" ", "") for x in found})


def compare(fmt: str, src_path: str, tgt_path: str | None, strict: bool) -> dict:
    src = load(src_path)
    tgt = load(tgt_path) if tgt_path and os.path.exists(tgt_path) else {}
    res = {"format": fmt, "source": src_path, "target": tgt_path, "target_exists": bool(tgt_path and os.path.exists(tgt_path)),
           "missing": sorted(set(src) - set(tgt)), "extra": sorted(set(tgt) - set(src)),
           "placeholders": [], "empty": [], "raw_key": [], "identical": []}
    for k in sorted(set(src) & set(tgt)):
        a, b = src[k], tgt[k]
        if placeholders(fmt, a) != placeholders(fmt, b):
            res["placeholders"].append({"key": k, "source": placeholders(fmt, a), "target": placeholders(fmt, b)})
        if fmt == "vue" and a.count("|") != b.count("|"):
            res["placeholders"].append({"key": k, "source": f"{a.count('|') + 1} plural forms", "target": f"{b.count('|') + 1} plural forms"})
        if not b.strip():
            res["empty"].append(k)
        if b.strip() == k:
            res["raw_key"].append(k)
        if strict and a == b and re.search(r"[A-Za-z]{4,}", a):
            res["identical"].append(k)
    for k, v in src.items():
        if not v.strip():
            res["empty"].append(f"{k} (source)")
        if v.strip() == k:
            res["raw_key"].append(f"{k} (source)")
    return res


def discover(root: str, s: str, t: str) -> list[tuple[str, str, str]]:
    pairs = []
    loc = os.path.join(root, "src/renderer/src/i18n/locales")
    if os.path.isfile(os.path.join(loc, f"{s}.json")):
        pairs.append(("vue", os.path.join(loc, f"{s}.json"), os.path.join(loc, f"{t}.json")))
    lang = os.path.join(root, "lang")
    for p in sorted(glob.glob(os.path.join(lang, s, "**", "*.php"), recursive=True)):
        rel = os.path.relpath(p, os.path.join(lang, s))
        pairs.append(("laravel", p, os.path.join(lang, t, rel)))
    if os.path.isfile(os.path.join(lang, f"{s}.json")):
        pairs.append(("laravel", os.path.join(lang, f"{s}.json"), os.path.join(lang, f"{t}.json")))
    mc_s = {"en": "en_us", "fr": "fr_fr"}.get(s, s)
    mc_t = {"en": "en_us", "fr": "fr_fr"}.get(t, t)
    for p in sorted(glob.glob(os.path.join(root, "src/main/resources/assets/*/lang", f"{mc_s}.json"))):
        pairs.append(("mc", p, os.path.join(os.path.dirname(p), f"{mc_t}.json")))
    return pairs


def guess_fmt(path: str) -> str:
    if path.endswith(".php") or "/lang/" in path and re.search(r"/lang/[a-z]{2}(\.json|/)", path):
        return "laravel"
    if re.search(r"[a-z]{2}_[a-z]{2}\.json$", path):
        return "mc"
    return "vue"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=".")
    ap.add_argument("--source", default="en")
    ap.add_argument("--target", default="fr")
    ap.add_argument("--pair", nargs=2, metavar=("SOURCE", "TARGET"))
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args()
    pairs = [(guess_fmt(a.pair[0]), a.pair[0], a.pair[1])] if a.pair else discover(a.root, a.source, a.target)
    if not pairs:
        print(f"no {a.source} lang files found under {a.root} (looked for launcher, Laravel and Minecraft layouts)", file=sys.stderr)
        return 2
    try:
        results = [compare(f, s, t, a.strict) for f, s, t in pairs]
    except (RuntimeError, json.JSONDecodeError) as e:
        print(f"ERROR {e}", file=sys.stderr)
        return 2
    bad = 0
    for r in results:
        n = len(r["missing"]) + len(r["placeholders"]) + len(r["empty"]) + len(r["raw_key"]) + len(r["identical"])
        bad += n
    if a.json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
        return 1 if bad else 0
    for r in results:
        head = f"[{r['format']}] {r['source']} -> {r['target']}"
        if not r["target_exists"]:
            head += "  (TARGET FILE MISSING)"
        print(head)
        for label, key in (("missing in target", "missing"), ("only in target (stale?)", "extra"),
                           ("empty", "empty"), ("value equals key", "raw_key"), ("identical to source", "identical")):
            if r[key]:
                print(f"  {label}: {len(r[key])}")
                for k in r[key][:200]:
                    print(f"    {k}")
        for p in r["placeholders"]:
            print(f"  placeholder mismatch: {p['key']}  source={p['source']} target={p['target']}")
        if not any(r[k] for k in ("missing", "extra", "empty", "raw_key", "identical", "placeholders")):
            print("  ok")
    print(f"{len(results)} file pair(s), {bad} problem(s)" + (" (stale keys are reported, not counted)" if any(r["extra"] for r in results) else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
