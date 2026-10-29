#!/usr/bin/env python3
"""Offline tests for the deterministic skill helpers (no network, no model calls).

  python3 evals/test_helpers.py        # or: python3 -m unittest evals/test_helpers.py
Network-backed commands (modpack.py resolve, prio.py, merged_prs.py, timeline.py) are tested on
their offline paths only.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SK = os.path.join(ROOT, "plugins", "arffornia", "skills")


def run(script: str, *args: str, cwd: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, os.path.join(SK, script), *args], cwd=cwd, capture_output=True, text=True)


def write(base: str, rel: str, text: str) -> None:
    p = os.path.join(base, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(text))


class Tmp(unittest.TestCase):
    def setUp(self) -> None:
        self.d = tempfile.mkdtemp(prefix="ak-test-")

    def tearDown(self) -> None:
        shutil.rmtree(self.d, ignore_errors=True)


class RiskRouter(Tmp):
    def test_risk_yml_levels_and_skip(self):
        write(self.d, "risk.yml", """\
            levels:
              high: {paths: ["**/network/**"], why: "client input"}
              medium: {paths: ["src/**"]}
            low: ["docs/**"]
            skip: ["**/*.lock"]
            """)
        r = run("review/scripts/risk.py", "--json", "src/a/network/P.java", "src/x.js", "docs/a.md", "y.lock", cwd=self.d)
        out = json.loads(r.stdout)
        levels = {f["path"]: f["level"] for f in out["files"]}
        self.assertEqual(levels, {"src/a/network/P.java": "high", "src/x.js": "medium", "docs/a.md": "low", "y.lock": "skip"})
        self.assertEqual(out["overall"], "high")

    def test_defaults_without_risk_yml(self):
        r = run("review/scripts/risk.py", "--json", "docs/readme.md", cwd=self.d)
        out = json.loads(r.stdout)
        self.assertIn("built-in", out["source"])
        self.assertEqual(out["overall"], "low")

    def test_template_shape_first_match_and_security(self):
        write(self.d, "risk.yml", """\
            version: 1
            default: standard
            rules:
              - {name: network-boundary, depth: deep, security: true, paths: ["**/network/**"]}
              - {name: generated, depth: light, paths: ["package-lock.json"]}
              - {name: docs, depth: light, paths: ["**/*.md", "docs/**"]}
            escalate: {lines_changed: 400}
            """)
        out = json.loads(run("review/scripts/risk.py", "--json", "docs/network/a.md", "src/Foo.java", "package-lock.json", cwd=self.d).stdout)
        levels = {f["path"]: (f["level"], f["rule"]) for f in out["files"]}
        self.assertEqual(levels["docs/network/a.md"], ("high", "network-boundary (security)"))  # first match wins
        self.assertEqual(levels["src/Foo.java"], ("medium", "(default)"))
        self.assertEqual(levels["package-lock.json"][0], "low")
        self.assertTrue(out["security"])

    def test_only_skipped_files(self):
        r = run("review/scripts/risk.py", "--json", "composer.lock", cwd=self.d)
        self.assertEqual(json.loads(r.stdout)["overall"], "skip")


class I18nParity(Tmp):
    def test_vue_missing_placeholder_plural(self):
        loc = "src/renderer/src/i18n/locales"
        write(self.d, f"{loc}/en.json", '{"a": {"b": "Hi {name}", "c": "one | many"}, "d": "x"}')
        write(self.d, f"{loc}/fr.json", '{"a": {"b": "Salut", "c": "un"}, "e": "old"}')
        r = run("i18n-sync/scripts/i18n_parity.py", "--root", self.d, "--json")
        self.assertEqual(r.returncode, 1)
        res = json.loads(r.stdout)[0]
        self.assertEqual(res["missing"], ["d"])
        self.assertEqual(res["extra"], ["e"])
        self.assertEqual({p["key"] for p in res["placeholders"]}, {"a.b", "a.c"})

    def test_minecraft_positional_count(self):
        lang = "src/main/resources/assets/arffornia/lang"
        write(self.d, f"{lang}/en_us.json", '{"k.a": "%s of %s", "k.b": "Done"}')
        write(self.d, f"{lang}/fr_fr.json", '{"k.a": "%s", "k.b": "Fait"}')
        res = json.loads(run("i18n-sync/scripts/i18n_parity.py", "--root", self.d, "--json").stdout)[0]
        self.assertEqual([p["key"] for p in res["placeholders"]], ["k.a"])

    def test_parity_ok(self):
        lang = "src/main/resources/assets/arffornia/lang"
        write(self.d, f"{lang}/en_us.json", '{"k": "Energy: %s"}')
        write(self.d, f"{lang}/fr_fr.json", '{"k": "Énergie : %s"}')
        self.assertEqual(run("i18n-sync/scripts/i18n_parity.py", "--root", self.d).returncode, 0)

    @unittest.skipUnless(shutil.which("php"), "php not installed")
    def test_laravel_php_case_insensitive_placeholders(self):
        write(self.d, "lang/en/m.php", "<?php return ['w' => 'Hi :name', 'n' => ['x' => 'X']];")
        write(self.d, "lang/fr/m.php", "<?php return ['w' => 'Salut :Name'];")
        res = json.loads(run("i18n-sync/scripts/i18n_parity.py", "--root", self.d, "--json").stdout)[0]
        self.assertEqual(res["missing"], ["n.x"])
        self.assertEqual(res["placeholders"], [])


class ModpackDupes(Tmp):
    def test_dupes_and_candidate(self):
        ml = {"mods": {"curseforge": [{"displayName": "AE2", "projectId": "1", "fileId": "10"},
                                      {"displayName": "Rich Presence", "projectId": "2", "fileId": "20"},
                                      {"displayName": "Rich Presence (Forge)", "projectId": "2", "fileId": "20"}],
                       "modrinth": [], "github-releases": []}}
        srv = {"mods": {"curseforge": [{"displayName": "AE2", "projectId": "1", "fileId": "11"}], "modrinth": [], "github-releases": []}}
        write(self.d, "config/launcher/modList.json", json.dumps(ml))
        write(self.d, "config/server/modList.json", json.dumps(srv))
        r = run("modpack-change/scripts/modpack.py", "dupes", cwd=self.d)
        self.assertEqual(r.returncode, 1)
        self.assertIn("cf:2 listed twice", r.stdout)
        self.assertIn("MISMATCH cf:1", r.stdout)
        r = run("modpack-change/scripts/modpack.py", "dupes", "--name", "Brand New Mod", cwd=self.d)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("PRE-EXISTING", r.stdout)
        r = run("modpack-change/scripts/modpack.py", "dupes", "--project", "1", cwd=self.d)
        self.assertEqual(r.returncode, 1)
        self.assertIn("PRESENT launcher/curseforge", r.stdout)

    def test_not_provisioning(self):
        self.assertEqual(run("modpack-change/scripts/modpack.py", "dupes", cwd=self.d).returncode, 2)


class McLangLint(Tmp):
    def test_errors_and_warnings(self):
        a = "src/main/resources/assets/arffornia"
        write(self.d, f"{a}/lang/en_us.json", '{"gui.arffornia.crafter.energy": "Energy", "gui.arffornia.crafter.go": "Go: %s"}')
        write(self.d, f"{a}/lang/fr_fr.json", '{"gui.arffornia.crafter.energy": "Énergie disponible maintenant", "gui.arffornia.crafter.go": "Aller: %s"}')
        write(self.d, "src/main/java/x/S.java", '''\
            class S { void f() {
              Component.translatable("gui.arffornia.crafter.missing");
              Component.literal("Hello there player");
              Component.literal("/arffornia shop claim_reward");
            } }
            ''')
        r = run("mc-ui-check/scripts/mc_lang_lint.py", "--json", cwd=self.d)
        self.assertEqual(r.returncode, 1)
        out = json.loads(r.stdout)
        msgs = " | ".join(o["msg"] for o in out)
        self.assertIn("missing from en_us.json", msgs)
        self.assertIn("Hello there player", msgs)
        self.assertNotIn("claim_reward", msgs)
        self.assertIn("overflow risk", msgs)
        self.assertIn("no no-break space before ':'", msgs)


class SkillLint(Tmp):
    def test_flags_unquoted_hash_and_side_effects(self):
        write(self.d, "plugins/p/skills/bad/SKILL.md", """\
            ---
            name: bad
            description: Push the branch and close #12 when asked
            bogus: 1
            ---
            Run `git push -u origin HEAD`. See [ref](references/missing.md).
            """)
        write(self.d, "plugins/p/skills/good/SKILL.md", """\
            ---
            name: good
            description: "Explain a module. Use when asked how something works."
            ---
            Read [the format](references/format.md).
            """)
        write(self.d, "plugins/p/skills/good/references/format.md", "x")
        r = run("harness-audit/scripts/skill_lint.py", "--json", cwd=self.d)
        self.assertEqual(r.returncode, 1)
        out = json.loads(r.stdout)
        bad = " | ".join(o["msg"] for o in out if "bad" in o["path"])
        self.assertIn("contains ' #'", bad)
        self.assertIn("unknown front-matter key 'bogus'", bad)
        self.assertIn("without disable-model-invocation", bad)
        self.assertIn("broken link", bad)
        self.assertFalse([o for o in out if "good" in o["path"] and o["level"] == "ERROR"])

    def test_kit_itself_is_clean(self):
        r = run("harness-audit/scripts/skill_lint.py", cwd=ROOT)
        self.assertEqual(r.returncode, 0, r.stdout)


class Drift(Tmp):
    def test_gone_unmatched(self):
        try:
            import yaml  # noqa: F401
        except ImportError:
            self.skipTest("PyYAML missing")
        s = os.path.join(self.d, "architecture", "arffornia")
        write(s, "model.yaml", """\
            elements:
              - {id: web, kind: backend, matches: ['k8s:web/deployment/web', 'k8s:web/deployment/old']}
            connections: []
            """)
        write(s, "discovered/k8s-web.yaml", """\
            elements:
              - {id: 'k8s:web/deployment/web', kind: backend}
              - {id: 'k8s:web/deployment/redis', kind: database}
            connections: []
            """)
        out = json.loads(run("noodle-arffornia/scripts/drift.py", s, "--json").stdout)
        self.assertEqual([g["matches"] for g in out["gone"]], ["k8s:web/deployment/old"])
        self.assertEqual([u["id"] for u in out["unmatched"]], ["k8s:web/deployment/redis"])


class Prio(Tmp):
    def test_offline_scoring(self):
        issues = [
            {"number": 1, "title": "sec", "labels": [{"name": "type: security"}, {"name": "priority: P0"}, {"name": "effort: S"}],
             "repository_url": "https://api.github.com/repos/A/r", "body": ""},
            {"number": 2, "title": "docs", "labels": [{"name": "type: docs"}, {"name": "priority: P3"}, {"name": "effort: L"}],
             "repository_url": "https://api.github.com/repos/A/r", "body": "Blocked by #1"},
            {"number": 3, "title": "pr", "pull_request": {}, "body": "Closes #1", "labels": [],
             "repository_url": "https://api.github.com/repos/A/r", "html_url": "https://github.com/A/r/pull/3"},
        ]
        p = os.path.join(self.d, "issues.json")
        with open(p, "w") as f:
            json.dump(issues, f)
        out = json.loads(run("prio/scripts/prio.py", "--from-json", p, "--json").stdout)
        one = [r for r in out if r["number"] == 1][0]
        self.assertEqual(one["unblock"], 1)
        self.assertTrue(any("in progress" in n for n in one["notes"]))
        self.assertAlmostEqual(one["score"], (5 * 4 / 1 + 1.5) * 0.2, places=2)


class SharedRefs(unittest.TestCase):
    def test_in_sync(self):
        r = subprocess.run([os.path.join(SK, "_shared", "sync.sh"), "--check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
