import importlib.util
import sys
import unittest
from pathlib import Path


PATCH_PATH = Path(__file__).with_name("patch-floating-right-sidebar.py")
SPEC = importlib.util.spec_from_file_location("orca_sidebar_patcher", PATCH_PATH)
assert SPEC is not None and SPEC.loader is not None
patcher = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = patcher
SPEC.loader.exec_module(patcher)


def web_worktree_fixture(
    *,
    new_card: bytes,
    compact_cards: bytes,
    display: bytes,
    ports: bytes,
    inline_visibility: bytes,
    trailing_visibility: bytes,
    trailing_element: bytes,
    review: bytes,
    runtime: bytes = b"n",
) -> bytes:
    return b"".join(
        (
            display,
            b"=Wt({issue:xe,linearIssue:xt,jiraIssue:vt,review:",
            new_card,
            b"?null:",
            review,
            b",comment:jt,automationProvenance:Ge,cliProvenance:$e}),",
            inline_visibility,
            b"=!",
            new_card,
            b"&&!",
            compact_cards,
            b"&&(",
            display,
            b"||",
            ports,
            b"),",
            trailing_visibility,
            b"=(",
            new_card,
            b"||",
            compact_cards,
            b")&&(",
            display,
            b"||",
            ports,
            b"),",
            trailing_element,
            b"=",
            trailing_visibility,
            b"?(0,",
            runtime,
            b'.jsx)("div",{className:"ml-auto flex shrink-0 items-center gap-1 pr-1.5",children:Ds}):null,',
            b"(0,",
            runtime,
            b'.jsxs)("div",{className:"flex min-w-0 items-center justify-between gap-2",children:[(0,',
            runtime,
            b'.jsxs)("div",{className:"flex min-w-0 flex-1 items-center gap-1.5",children:[]}),',
            trailing_visibility,
            b"&&",
            trailing_element,
            b"]})",
        )
    )


ORCA_1_4_167 = web_worktree_fixture(
    new_card=b"w",
    compact_cards=b"J",
    display=b"Pt",
    ports=b"et",
    inline_visibility=b"ur",
    trailing_visibility=b"mr",
    trailing_element=b"Yo",
    review=b"Ke",
)
ORCA_1_4_176 = web_worktree_fixture(
    new_card=b"P",
    compact_cards=b"V",
    display=b"st",
    ports=b"We",
    inline_visibility=b"Ss",
    trailing_visibility=b"Rs",
    trailing_element=b"Vr",
    review=b"Re",
)


class WebPrNumberContextTests(unittest.TestCase):
    def discover(self, data: bytes):
        discover = getattr(patcher, "discover_web_pr_number_context", None)
        self.assertIsNotNone(discover, "structural discovery function is missing")
        return discover(data)

    def test_discovers_1_4_167_context(self):
        context = self.discover(ORCA_1_4_167)
        self.assertEqual(context.anchor, b",mr&&Yo]})")
        self.assertIn(b"!w&&!J&&Ke", context.insertion)
        self.assertIn(b'["#",Ke.number]', context.insertion)

    def test_discovers_1_4_176_context(self):
        context = self.discover(ORCA_1_4_176)
        self.assertEqual(context.anchor, b",Rs&&Vr]})")
        self.assertIn(b"!P&&!V&&Re", context.insertion)
        self.assertIn(b'["#",Re.number]', context.insertion)

    def test_rejects_ambiguous_worktree_context(self):
        with self.assertRaisesRegex(
            SystemExit,
            "expected one minified worktree-card title JSX call, found 2",
        ):
            self.discover(ORCA_1_4_176 + ORCA_1_4_176)

    def test_rejects_missing_review_relationship(self):
        malformed = ORCA_1_4_176.replace(b"review:P?null:Re", b"review:Q?null:Re")
        with self.assertRaisesRegex(
            SystemExit,
            "expected one minified worktree-card review binding, found 0",
        ):
            self.discover(malformed)


if __name__ == "__main__":
    unittest.main()
