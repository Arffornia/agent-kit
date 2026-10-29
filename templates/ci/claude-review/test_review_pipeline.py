"""Unit tests for review_pipeline.py. Run: python3 -m unittest .github/claude-review/test_review_pipeline.py"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import review_pipeline as rp  # noqa: E402

RISK = """
default: standard
levels:
  deep:
    - "src/main/**/network/**"
    - ".github/workflows/**"
  standard: ["src/**"]
  light:
    - "**/*.md"
    - "docs/**"
escalate:
  lines_changed: 400
"""


class Glob(unittest.TestCase):
    def test_globs(self):
        self.assertTrue(rp.glob_to_regex("src/**/network/**").match("src/main/java/a/network/P.java"))
        self.assertTrue(rp.glob_to_regex("**/*.md").match("README.md"))
        self.assertTrue(rp.glob_to_regex("*.md").match("docs/a/b.md"))
        self.assertFalse(rp.glob_to_regex("/*.md").match("docs/b.md"))
        self.assertTrue(rp.glob_to_regex("docs/").match("docs/x/y.png"))
        self.assertTrue(rp.glob_to_regex("app/{Http,Services}/**").match("app/Services/A.php"))


class Triage(unittest.TestCase):
    def cfg(self):
        return rp._mini_yaml(RISK)

    def test_mini_yaml_matches_pyyaml_shape(self):
        c = self.cfg()
        self.assertEqual(c["levels"]["deep"], ["src/main/**/network/**", ".github/workflows/**"])
        self.assertEqual(c["levels"]["standard"], ["src/**"])
        self.assertEqual(c["escalate"]["lines_changed"], "400")

    def test_highest_level_wins(self):
        r = rp.triage(["README.md", "src/main/java/x/network/A.java"], self.cfg(), 10, [])
        self.assertEqual(r["level"], "deep")
        self.assertEqual(len(r["verifiers"]), 3)

    def test_light_carves_out_of_standard_but_not_deep(self):
        cfg = {"levels": {"deep": ["src/net/**"], "standard": ["src/**"], "light": ["src/test/**", "**/*.md"]}}
        self.assertEqual(rp.triage(["src/test/A.java"], cfg, 1, [])["level"], "light")
        self.assertEqual(rp.triage(["src/net/README.md"], cfg, 1, [])["level"], "deep")
        self.assertEqual(rp.triage(["src/A.java", "src/test/A.java"], cfg, 1, [])["level"], "standard")

    def test_docs_only_is_light(self):
        r = rp.triage(["README.md", "docs/a.md"], self.cfg(), 10, [])
        self.assertEqual(r["level"], "light")
        self.assertEqual(r["lenses"], ["quick"])

    def test_unmatched_uses_default_and_size_escalates(self):
        self.assertEqual(rp.triage(["build.gradle"], self.cfg(), 10, [])["level"], "standard")
        self.assertEqual(rp.triage(["README.md"], self.cfg(), 900, [])["level"], "standard")

    def test_labels_only_raise(self):
        self.assertEqual(rp.triage(["README.md"], self.cfg(), 1, ["ai-review:deep"])["level"], "deep")

    def test_aliases_and_top_level_keys(self):
        r = rp.triage(["a/b.php"], {"high": ["a/**"]}, 1, [])
        self.assertEqual(r["level"], "deep")


class Pipeline(unittest.TestCase):
    def test_merge_dedup_and_missing(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "bugs.json").write_text(json.dumps({"findings": [
                {"path": "a.py", "line": 10, "severity": "major", "category": "bug", "title": "Null deref on empty list", "evidence": "x[0]"},
            ]}))
            Path(d, "security.json").write_text(json.dumps({"findings": [
                {"path": "a.py", "line": 11, "severity": "blocking", "category": "security", "title": "Null deref on empty list input", "evidence": "x[0] with []"},
                {"path": "b.py", "line": 3, "severity": "minor", "category": "security", "title": "Log leaks token"},
            ]}))
            res = rp.merge(d, ["bugs", "security", "conventions"])
        self.assertEqual(len(res["candidates"]), 2)
        self.assertEqual(res["candidates"][0]["severity"], "blocking")
        self.assertEqual(res["candidates"][0]["found_by"], ["bugs", "security"])
        self.assertEqual(res["missing_lenses"], ["conventions"])

    def test_tally_quorum(self):
        cands = {"candidates": [
            {"id": "F1", "path": "a.py", "line": 1, "severity": "major", "category": "bug", "title": "t1", "evidence": "e", "found_by": ["bugs"]},
            {"id": "F2", "path": "a.py", "line": 5, "severity": "blocking", "category": "bug", "title": "t2", "evidence": "e", "found_by": ["bugs"]},
        ], "missing_lenses": []}
        with tempfile.TemporaryDirectory() as d:
            Path(d, "verifier-1.json").write_text(json.dumps({"votes": [
                {"id": "F1", "verdict": "confirmed", "severity": "major", "evidence": "seen"},
                {"id": "F2", "verdict": "confirmed", "severity": "minor", "evidence": "seen"}]}))
            Path(d, "verifier-2.json").write_text(json.dumps({"votes": [
                {"id": "F1", "verdict": "rejected", "evidence": "guarded at a.py:0"},
                {"id": "F2", "verdict": "confirmed", "severity": "blocking", "evidence": "seen too"}]}))
            res = rp.tally(cands, d, 3, 2, "deep")
        self.assertEqual([f["id"] for f in res["confirmed"]], ["F2"])
        self.assertEqual(res["confirmed"][0]["severity"], "minor")  # median, rounding to less severe
        self.assertEqual(res["missing"], ["verifier-3"])

    def test_light_keeps_only_evidenced_non_minor(self):
        cands = {"candidates": [
            {"id": "F1", "path": "a", "line": 1, "severity": "minor", "category": "x", "title": "t", "evidence": "e", "found_by": ["quick"]},
            {"id": "F2", "path": "a", "line": 2, "severity": "major", "category": "x", "title": "t", "evidence": "", "found_by": ["quick"]},
            {"id": "F3", "path": "a", "line": 3, "severity": "major", "category": "x", "title": "t", "evidence": "e", "found_by": ["quick"]},
        ]}
        res = rp.tally(cands, "/nonexistent", 0, 0, "light")
        self.assertEqual([f["id"] for f in res["confirmed"]], ["F3"])

    def test_payload_inline_vs_outside(self):
        files = [{"filename": "a.py", "patch": "@@ -1,2 +1,3 @@\n ctx\n+new\n-old\n ctx2"}]
        res = {"confirmed": [
            {"id": "F1", "path": "a.py", "line": 2, "severity": "major", "category": "bug", "title": "in diff", "evidence": "e", "found_by": ["bugs"], "votes": "2/2"},
            {"id": "F2", "path": "a.py", "line": 50, "severity": "minor", "category": "bug", "title": "outside", "evidence": "e", "found_by": ["bugs"], "votes": "2/2"},
        ], "rejected": 4, "missing": ["verifier-2"]}
        out = rp.payload(res, files, "standard", 1, 3, "abc123", ["paths: standard"])
        self.assertEqual(out["event"], "COMMENT")
        self.assertEqual([c["line"] for c in out["comments"]], [2])
        self.assertIn("Findings: 2 (blocking 0, major 1, minor 1)", out["body"])
        self.assertIn("Outside the diff", out["body"])
        self.assertIn("Did not complete: verifier-2", out["body"])
        self.assertIn("arffornia-ai-review sha=abc123 round=1", out["body"])

    def test_rounds(self):
        reviews = [{"body": "x <!-- arffornia-ai-review sha=aaa round=1 level=light -->"}, {"body": "human"}]
        self.assertEqual(rp.count_rounds(reviews, "bbb"), (1, False))
        self.assertEqual(rp.count_rounds(reviews, "aaa"), (1, True))


if __name__ == "__main__":
    unittest.main()
