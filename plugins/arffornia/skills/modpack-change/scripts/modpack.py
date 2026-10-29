#!/usr/bin/env python3
"""Resolve a mod file and check duplicates for Arffornia_Provisioning.

Usage (run from the Arffornia_Provisioning root):
  modpack.py resolve curseforge <projectId> [<fileId>]   # no fileId: lists NeoForge 1.21.1 files
  modpack.py resolve modrinth <versionId|project-slug>    # a slug lists NeoForge 1.21.1 versions
  modpack.py dupes [--name "<display name>"] [--project <id>] [--version <id>]
  modpack.py entry curseforge <projectId> <fileId> | modrinth <versionId>   # JSON entry to paste

`resolve` prints loader, game versions, file name, release type and (Modrinth) client/server
side and required dependencies, then FAIL lines for anything that is not NeoForge 1.21.1.
`dupes` scans config/*/modList.json and config/*/storage/mods/ for the same project, version,
or a display name / jar name that normalises to the same slug, and for ids repeated inside a
list. Exit code: 0 ok, 1 a FAIL or a duplicate was found, 2 usage or network error.

CurseForge: uses the official API when CF_API_KEY is set (never printed), otherwise the public
mirror api.cfwidget.com (file list only, no dependencies: check them on the project page).
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
import urllib.error
import urllib.request

GAME = os.environ.get("MC_VERSION", "1.21.1")
LOADER = os.environ.get("MC_LOADER", "neoforge")
UA = "Arffornia-agent-kit/modpack.py (github.com/Arffornia/agent-kit)"


def get(url: str, headers: dict | None = None) -> dict | list:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json", **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        print(f"ERROR {e.code} on {url.split('?')[0]}", file=sys.stderr)
        sys.exit(2)
    except urllib.error.URLError as e:
        print(f"ERROR network: {e.reason} ({url.split('?')[0]})", file=sys.stderr)
        sys.exit(2)


def slug(s: str) -> str:
    s = s.lower()
    s = re.sub(r"\.jar$", "", s)
    s = re.sub(r"[-_+ ]?(neo)?forge|fabric|mc?1\.\d+(\.\d+)?|\d+(\.\d+)+.*$", " ", s)
    return re.sub(r"[^a-z0-9]", "", s)


def check_file(loaders: list[str], games: list[str]) -> list[str]:
    fails = []
    if not any(l.lower() == LOADER for l in loaders):
        fails.append(f"FAIL loader is {loaders}, expected {LOADER}")
    if GAME not in games:
        fails.append(f"FAIL game versions {games} do not include {GAME}")
    return fails


def cf_resolve(project: str, file_id: str | None) -> int:
    key = os.environ.get("CF_API_KEY")
    if key:
        h = {"x-api-key": key}
        mod = get(f"https://api.curseforge.com/v1/mods/{project}", h)["data"]
        print(f"project {project}: {mod['name']}  {mod['links'].get('websiteUrl', '')}")
        if not file_id:
            files = get(f"https://api.curseforge.com/v1/mods/{project}/files?gameVersion={GAME}&modLoaderType=6&pageSize=10", h)["data"]
            for f in files:
                print(f"  fileId {f['id']}  {f['fileName']}  {f['gameVersions']}  releaseType={f['releaseType']}  {f['fileDate'][:10]}")
            return 0
        f = get(f"https://api.curseforge.com/v1/mods/{project}/files/{file_id}", h)["data"]
        vers = f["gameVersions"]
        print(f"fileId {f['id']}: {f['fileName']}  versions={vers}  releaseType={f['releaseType']} (1=release)")
        deps = [d for d in f.get("dependencies", []) if d.get("relationType") == 3]
        for d in deps:
            print(f"  requires projectId {d['modId']}")
        fails = check_file([v for v in vers if v.lower() in ("neoforge", "forge", "fabric", "quilt")], vers)
    else:
        w = get(f"https://api.cfwidget.com/{project}")
        print(f"project {project}: {w.get('title')}  {w.get('urls', {}).get('curseforge', '')}  (via cfwidget; set CF_API_KEY for dependencies)")
        files = w.get("files", [])
        if not file_id:
            ok = [f for f in files if GAME in f.get("versions", []) and any(v.lower() == LOADER for v in f.get("versions", []))]
            for f in sorted(ok, key=lambda f: -f["id"])[:10]:
                print(f"  fileId {f['id']}  {f['name']}  {f['type']}  {f.get('uploaded_at', '')[:10]}")
            if not ok:
                print(f"FAIL no {LOADER} {GAME} file found")
                return 1
            return 0
        match = [f for f in files if str(f["id"]) == str(file_id)]
        if not match:
            print(f"FAIL fileId {file_id} not in the project's file list")
            return 1
        f = match[0]
        print(f"fileId {f['id']}: {f['name']}  versions={f['versions']}  type={f['type']}")
        print("  dependencies: not available without CF_API_KEY; read the project page 'Relations' tab")
        fails = check_file(f["versions"], f["versions"])
        if f["type"] != "release":
            print(f"WARN release type is {f['type']}")
    for x in fails:
        print(x)
    return 1 if fails else 0


def mr_resolve(ref: str) -> int:
    if re.fullmatch(r"[A-Za-z0-9]{8}", ref):
        try:
            v = get(f"https://api.modrinth.com/v2/version/{ref}")
        except SystemExit:
            v = None
        if isinstance(v, dict) and v.get("id"):
            p = get(f"https://api.modrinth.com/v2/project/{v['project_id']}")
            print(f"versionId {v['id']}: {p['title']} {v['version_number']}  file={[f['filename'] for f in v['files']]}")
            print(f"  loaders={v['loaders']}  game={v['game_versions']}  type={v['version_type']}")
            print(f"  side: client={p['client_side']} server={p['server_side']}  https://modrinth.com/mod/{p['slug']}")
            for d in v.get("dependencies", []):
                if d.get("dependency_type") == "required":
                    print(f"  requires project {d.get('project_id')} version {d.get('version_id')}")
            fails = check_file(v["loaders"], v["game_versions"])
            if v["version_type"] != "release":
                print(f"WARN version type is {v['version_type']}: prefer a release unless the mod has none")
            for x in fails:
                print(x)
            return 1 if fails else 0
    p = get(f"https://api.modrinth.com/v2/project/{ref}")
    print(f"project {p['slug']}: {p['title']}  side: client={p['client_side']} server={p['server_side']}")
    vs = get(f"https://api.modrinth.com/v2/project/{ref}/version?loaders=%5B%22{LOADER}%22%5D&game_versions=%5B%22{GAME}%22%5D")
    for v in vs[:10]:
        print(f"  versionId {v['id']}  {v['version_number']}  {v['version_type']}  {v['date_published'][:10]}")
    if not vs:
        print(f"FAIL no {LOADER} {GAME} version")
        return 1
    return 0


def load_lists() -> list[tuple[str, str, dict]]:
    out = []
    for path in sorted(glob.glob("config/*/modList.json")):
        kind = path.split("/")[1]
        data = json.load(open(path, encoding="utf-8"))
        for source, entries in (data.get("mods") or {}).items():
            for e in entries or []:
                out.append((kind, source, e))
    if not out:
        print("ERROR no config/*/modList.json here: run from the Arffornia_Provisioning root", file=sys.stderr)
        sys.exit(2)
    return out


def ident(source: str, e: dict) -> str:
    if source == "curseforge":
        return f"cf:{e.get('projectId')}"
    if source == "modrinth":
        return f"mr:{e.get('versionId')}"
    return f"gh:{e.get('owner')}/{e.get('repoName')}/{e.get('assetName')}"


def dupes(name: str | None, project: str | None, version: str | None) -> int:
    rows = load_lists()
    jars = [(p.split("/")[1], os.path.basename(p)) for p in glob.glob("config/*/storage/mods/*.jar")]
    bad = 0
    pre = "PRE-EXISTING " if (name or project or version) else ""
    # 1. repeated inside one kind
    for kind in sorted({r[0] for r in rows}):
        seen: dict[str, str] = {}
        names: dict[str, str] = {}
        for k, src, e in rows:
            if k != kind:
                continue
            i, n = ident(src, e), slug(e.get("displayName", ""))
            if i in seen:
                print(f"{pre}DUP {kind}: {i} listed twice ({seen[i]} / {e.get('displayName')})"); bad += 1
            seen[i] = e.get("displayName", "")
            if n and n in names and names[n] != i:
                print(f"{pre}DUP? {kind}: '{e.get('displayName')}' looks like the same mod as {names[n]} (different source or id)"); bad += 1
            names.setdefault(n, i)
        for jk, jar in jars:
            if jk == kind and slug(jar) in names:
                print(f"{pre}DUP? {kind}: committed jar storage/mods/{jar} and modList entry {names[slug(jar)]}"); bad += 1
    # 2. same project with different files across launcher and server
    by_proj: dict[str, set] = {}
    for k, src, e in rows:
        if src == "curseforge" and k in ("launcher", "server"):
            by_proj.setdefault(str(e.get("projectId")), set()).add((k, str(e.get("fileId"))))
    for pid, s in by_proj.items():
        files = {f for _, f in s}
        if len(files) > 1:
            print(f"{pre}MISMATCH cf:{pid} has different fileIds across sides: {sorted(s)}"); bad += 1
    # 3. the candidate
    if name or project or version:
        if bad:
            print(f"({bad} pre-existing problem(s) above: report them, do not fix them in a content PR)")
        bad = 0
        hits = []
        for k, src, e in rows:
            if project and src == "curseforge" and str(e.get("projectId")) == str(project):
                hits.append((k, src, e))
            elif version and src == "modrinth" and e.get("versionId") == version:
                hits.append((k, src, e))
            elif name and slug(e.get("displayName", "")) == slug(name):
                hits.append((k, src, e))
        for jk, jar in jars:
            if name and slug(jar) == slug(name):
                hits.append((jk, "jar", {"displayName": jar}))
        for k, src, e in hits:
            print(f"PRESENT {k}/{src}: {json.dumps(e)}")
        if not hits:
            print("candidate: not present in any modList.json or storage/mods/")
        bad += len(hits)
    what = "candidate already present" if pre and bad else ("problems found" if bad else "no duplicates")
    print(f"checked {len(rows)} entries and {len(jars)} committed jars: {what}")
    return 1 if bad else 0


def entry(args: list[str]) -> int:
    if args[0] == "curseforge" and len(args) == 3:
        key = os.environ.get("CF_API_KEY")
        name = get(f"https://api.curseforge.com/v1/mods/{args[1]}", {"x-api-key": key})["data"]["name"] if key \
            else get(f"https://api.cfwidget.com/{args[1]}")["title"]
        print(json.dumps({"displayName": name, "projectId": args[1], "fileId": args[2]}, indent=4))
        return 0
    if args[0] == "modrinth" and len(args) == 2:
        v = get(f"https://api.modrinth.com/v2/version/{args[1]}")
        p = get(f"https://api.modrinth.com/v2/project/{v['project_id']}")
        print(json.dumps({"displayName": p["title"], "versionId": args[1]}, indent=4))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


def main(argv: list[str]) -> int:
    if len(argv) >= 3 and argv[0] == "resolve":
        if argv[1] == "curseforge":
            return cf_resolve(argv[2], argv[3] if len(argv) > 3 else None)
        if argv[1] == "modrinth":
            return mr_resolve(argv[2])
    if argv and argv[0] == "dupes":
        opts = dict(zip(argv[1::2], argv[2::2]))
        return dupes(opts.get("--name"), opts.get("--project"), opts.get("--version"))
    if len(argv) >= 2 and argv[0] == "entry":
        return entry(argv[1:])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
