import re
import sys
from pathlib import Path


SIDEBAR_INLINE_CLASSES = b"relative flex-shrink-0 flex flex-row"
SIDEBAR_OVERLAY_CLASSES = b"absolute inset-y-0 right-0 z-30 flex"
WORKSPACE_ROW_CLASSES = b"flex flex-row flex-1 min-h-0 overflow-hidden"
POSITIONED_WORKSPACE_ROW_CLASSES = b"relative flex flex-1 min-h-0 overflow-hidden"
WORKSPACE_BOUNDARY_COPY = b"The app is still running. Retry the shell or use the menu to report the crash details."
RENDERER_CLASS_PREFIX = b'className: "'
WEB_CLASS_PREFIX = b'className:"'
RENDERER_JSX_CALLS = (
    (b"(0, import_jsx_runtime.jsx)", b"import_jsx_runtime.jsx"),
    (b"(0, import_jsx_runtime.jsxs)", b"import_jsx_runtime.jsxs"),
)
PATCH_REGION_LOOKBEHIND = 512
PATCH_REGION_LOOKAHEAD = 16384
WORKTREE_PATCH_REGION_LOOKBEHIND = 98304
WEB_WORKSPACE_JSX_CALL = re.compile(
    rb"\(0,(?P<runtime>[A-Za-z_$][A-Za-z0-9_$]*)\.jsxs\)\(\"div\",\{$"
)
WEB_STORE_BINDING = re.compile(
    rb"(?P<open>[A-Za-z_$][A-Za-z0-9_$]*)="
    rb"(?P<store>[A-Za-z_$][A-Za-z0-9_$]*)"
    rb"\([A-Za-z_$][A-Za-z0-9_$]*=>"
    rb"[A-Za-z_$][A-Za-z0-9_$]*\.rightSidebarOpen\)"
)
WEB_WORKTREE_TITLE_JSX_CALL = re.compile(
    rb"\(0,(?P<runtime>[A-Za-z_$][A-Za-z0-9_$]*)\.jsxs\)"
    rb'\("div",\{className:"flex min-w-0 items-center justify-between gap-2"'
)
RENDERER_PR_NUMBER_ANCHOR = (
    b"\t\t\t\t\t\t\tshowTitleRowIndicators && titleRowIndicators\n"
)
RENDERER_PR_NUMBER_INSERTION = (
    b"!newCardStyle && !compactCards && metaReview && "
    b'/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {\n'
    b'\t\t\t\t\t\t\t\tclassName: "ml-auto shrink-0 pr-1.5",\n'
    b'\t\t\t\t\t\t\t\t"data-worktree-card-pr-number": "",\n'
    b"\t\t\t\t\t\t\t\tchildren: /* @__PURE__ */ "
    b'(0, import_jsx_runtime.jsxs)("span", {\n'
    b'\t\t\t\t\t\t\t\t\tclassName: "block w-3.5 text-center text-[10px] '
    b'font-medium leading-none text-muted-foreground/80",\n'
    b'\t\t\t\t\t\t\t\t\tchildren: ["#", metaReview.number]\n'
    b"\t\t\t\t\t\t\t\t})\n"
    b"\t\t\t\t\t\t\t}),\n"
    b"\t\t\t\t\t\t\t"
)
WEB_PR_NUMBER_ANCHOR = b",mr&&Yo]})"
WEB_PR_NUMBER_BINDINGS = (
    b"Ke=Zs?oe:null",
    b"ur=!w&&!J&&(Pt||et)",
    b"mr=(w||J)&&(Pt||et)",
    b"Yo=mr?",
)
WEB_PR_NUMBER_INSERTION_TEMPLATE = (
    b',!w&&!J&&Ke&&(0,__RUNTIME__.jsx)("span",'
    b'{className:"ml-auto shrink-0 pr-1.5",'
    b'"data-worktree-card-pr-number":"",children:(0,__RUNTIME__.jsxs)("span",'
    b'{className:"block w-3.5 text-center text-[10px] font-medium leading-none '
    b'text-muted-foreground/80",children:["#",Ke.number]})})'
)
PR_NUMBER_MARKER = b"data-worktree-card-pr-number"
EXPECTED_RENDERER_COPIES = 2


def occurrence_offsets(data: bytes, needle: bytes) -> list[int]:
    offsets: list[int] = []
    start = 0
    while True:
        offset = data.find(needle, start)
        if offset < 0:
            return offsets
        offsets.append(offset)
        start = offset + len(needle)


def compress_jsx_calls(
    region: bytes,
    calls: tuple[tuple[bytes, bytes], ...],
    bytes_to_recover: int,
) -> tuple[bytes, int]:
    # ASAR offsets require each embedded renderer to retain its exact byte length.
    recovered = 0
    for original, compact in calls:
        while original in region and recovered < bytes_to_recover:
            region = region.replace(original, compact, 1)
            recovered += len(original) - len(compact)
    return region, recovered


def renderer_click_handler() -> bytes:
    return (
        b"onClickCapture: (event) => rightSidebarOpen "
        b'&& !event.target.closest(".absolute.right-0.z-30") '
        b"&& useAppStore.getState().setRightSidebarOpen(false),\n"
        b"\t\t\t\t\t\t\t"
    )


def web_click_handler(data: bytes, workspace_offset: int) -> bytes:
    search_start = max(0, workspace_offset - 65536)
    matches = list(WEB_STORE_BINDING.finditer(data, search_start, workspace_offset))
    if not matches:
        raise SystemExit(
            "refusing to patch Orca: minified right-sidebar store binding not found "
            "before workspace shell"
        )

    binding = matches[-1]
    open_name = binding.group("open")
    store_name = binding.group("store")
    return (
        b"onClickCapture:event=>"
        + open_name
        + b'&&!event.target.closest(".absolute.right-0.z-30")&&'
        + store_name
        + b".getState().setRightSidebarOpen(!1),"
    )


def web_jsx_calls(
    data: bytes, workspace_offset: int
) -> tuple[tuple[bytes, bytes], ...]:
    class_start = workspace_offset - len(WEB_CLASS_PREFIX)
    call_context = data[max(0, class_start - 128) : class_start]
    match = WEB_WORKSPACE_JSX_CALL.search(call_context)
    if not match:
        raise SystemExit(
            "refusing to patch Orca: minified workspace JSX runtime not found"
        )

    runtime = match.group("runtime")
    return (
        (b"(0," + runtime + b".jsx)", runtime + b".jsx"),
        (b"(0," + runtime + b".jsxs)", runtime + b".jsxs"),
    )


def patch_workspace_shell(data: bytearray, workspace_offset: int) -> None:
    if data[workspace_offset - len(RENDERER_CLASS_PREFIX) : workspace_offset] == (
        RENDERER_CLASS_PREFIX
    ):
        prefix = RENDERER_CLASS_PREFIX
        handler = renderer_click_handler()
        jsx_calls = RENDERER_JSX_CALLS
    elif (
        data[workspace_offset - len(WEB_CLASS_PREFIX) : workspace_offset]
        == WEB_CLASS_PREFIX
    ):
        prefix = WEB_CLASS_PREFIX
        handler = web_click_handler(bytes(data), workspace_offset)
        jsx_calls = web_jsx_calls(bytes(data), workspace_offset)
    else:
        raise SystemExit(
            "refusing to patch Orca: workspace shell has an unknown renderer format"
        )

    region_start = max(0, workspace_offset - PATCH_REGION_LOOKBEHIND)
    region_end = min(len(data), workspace_offset + PATCH_REGION_LOOKAHEAD)
    region = bytes(data[region_start:region_end])
    class_start = workspace_offset - len(prefix) - region_start
    class_end = class_start + len(prefix) + len(WORKSPACE_ROW_CLASSES) + 1
    expected_class = prefix + WORKSPACE_ROW_CLASSES + b'"'
    if region[class_start:class_end] != expected_class:
        raise SystemExit("refusing to patch Orca: workspace class anchor changed")

    replacement_class = handler + prefix + POSITIONED_WORKSPACE_ROW_CLASSES + b'"'
    growth = len(replacement_class) - len(expected_class)
    patched_region = region[:class_start] + replacement_class + region[class_end:]
    patched_region, recovered = compress_jsx_calls(patched_region, jsx_calls, growth)
    if recovered < growth:
        raise SystemExit(
            "refusing to patch Orca: not enough renderer syntax space for "
            "click-outside behavior"
        )

    padding = b" " * (recovered - growth)
    handler_offset = patched_region.find(handler)
    if handler_offset < 0:
        raise SystemExit(
            "refusing to patch Orca: click-outside handler insertion failed"
        )
    padding_offset = handler_offset + len(handler)
    patched_region = (
        patched_region[:padding_offset] + padding + patched_region[padding_offset:]
    )
    if len(patched_region) != len(region):
        raise SystemExit(
            "refusing to patch Orca: workspace patch changed renderer byte length"
        )

    data[region_start:region_end] = patched_region


def insert_pr_number_before_anchor(
    data: bytearray,
    anchor: bytes,
    insertion: bytes,
    jsx_calls: tuple[tuple[bytes, bytes], ...],
    renderer_name: str,
) -> None:
    offsets = occurrence_offsets(bytes(data), anchor)
    if len(offsets) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one "
            f"{renderer_name} worktree-card PR-number anchor, found {len(offsets)}"
        )

    anchor_offset = offsets[0]
    region_start = max(0, anchor_offset - WORKTREE_PATCH_REGION_LOOKBEHIND)
    region_end = anchor_offset + len(anchor)
    region = bytes(data[region_start:region_end])
    compressed_region, recovered = compress_jsx_calls(region, jsx_calls, len(insertion))
    if recovered < len(insertion):
        raise SystemExit(
            "refusing to patch Orca: not enough renderer syntax space for "
            f"the {renderer_name} worktree-card PR number"
        )
    if compressed_region.count(anchor) != 1:
        raise SystemExit(
            "refusing to patch Orca: worktree-card PR-number anchor changed "
            f"while compacting the {renderer_name} renderer"
        )

    padding = b" " * (recovered - len(insertion))
    patched_region = compressed_region.replace(anchor, insertion + padding + anchor, 1)
    if len(patched_region) != len(region):
        raise SystemExit(
            "refusing to patch Orca: worktree-card PR-number patch changed "
            f"the {renderer_name} renderer byte length"
        )
    data[region_start:region_end] = patched_region


def patch_worktree_card_pr_numbers(data: bytearray) -> None:
    if PR_NUMBER_MARKER in data:
        raise SystemExit(
            "refusing to patch Orca: worktree-card PR-number marker already exists"
        )

    insert_pr_number_before_anchor(
        data,
        RENDERER_PR_NUMBER_ANCHOR,
        RENDERER_PR_NUMBER_INSERTION,
        RENDERER_JSX_CALLS,
        "desktop",
    )

    web_anchor_offsets = occurrence_offsets(bytes(data), WEB_PR_NUMBER_ANCHOR)
    if len(web_anchor_offsets) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one web worktree-card PR-number "
            f"anchor, found {len(web_anchor_offsets)}"
        )
    web_anchor_offset = web_anchor_offsets[0]
    web_context = bytes(
        data[
            max(
                0, web_anchor_offset - WORKTREE_PATCH_REGION_LOOKBEHIND
            ) : web_anchor_offset
        ]
    )
    for binding in WEB_PR_NUMBER_BINDINGS:
        if web_context.count(binding) != 1:
            raise SystemExit(
                "refusing to patch Orca: minified worktree-card PR-number "
                f"binding changed: {binding.decode()}"
            )
    web_title_calls = list(WEB_WORKTREE_TITLE_JSX_CALL.finditer(web_context))
    if len(web_title_calls) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one minified worktree-card title "
            f"JSX call, found {len(web_title_calls)}"
        )
    web_runtime = web_title_calls[0].group("runtime")
    web_insertion = WEB_PR_NUMBER_INSERTION_TEMPLATE.replace(
        b"__RUNTIME__", web_runtime
    )
    insert_pr_number_before_anchor(
        data,
        WEB_PR_NUMBER_ANCHOR,
        web_insertion,
        (
            (b"(0," + web_runtime + b".jsx)", web_runtime + b".jsx"),
            (b"(0," + web_runtime + b".jsxs)", web_runtime + b".jsxs"),
        ),
        "web",
    )


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} APP_ASAR")

    asar_path = Path(sys.argv[1])
    original = asar_path.read_bytes()

    sidebar_offsets = occurrence_offsets(original, SIDEBAR_INLINE_CLASSES)
    if len(sidebar_offsets) != EXPECTED_RENDERER_COPIES:
        raise SystemExit(
            "refusing to patch Orca: expected "
            f"{EXPECTED_RENDERER_COPIES} inline right-sidebar renderers, "
            f"found {len(sidebar_offsets)}"
        )

    workspace_offsets = occurrence_offsets(original, WORKSPACE_ROW_CLASSES)
    positioned_offsets = [
        offset
        for index, offset in enumerate(workspace_offsets[:-1])
        if WORKSPACE_BOUNDARY_COPY in original[max(0, offset - 512) : offset]
        and workspace_offsets[index + 1] - offset <= 1024
    ]
    if len(positioned_offsets) != EXPECTED_RENDERER_COPIES:
        raise SystemExit(
            "refusing to patch Orca: expected "
            f"{EXPECTED_RENDERER_COPIES} workspace-shell rows, "
            f"found {len(positioned_offsets)}"
        )

    patched = bytearray(
        original.replace(SIDEBAR_INLINE_CLASSES, SIDEBAR_OVERLAY_CLASSES)
    )
    for offset in positioned_offsets:
        patch_workspace_shell(patched, offset)
    patch_worktree_card_pr_numbers(patched)

    if len(patched) != len(original):
        raise SystemExit(
            "refusing to patch Orca: renderer patch changed the ASAR byte length"
        )

    patched_bytes = bytes(patched)
    if patched_bytes.count(SIDEBAR_OVERLAY_CLASSES) != EXPECTED_RENDERER_COPIES:
        raise SystemExit("refusing to patch Orca: overlay sidebar verification failed")
    if (
        patched_bytes.count(POSITIONED_WORKSPACE_ROW_CLASSES)
        != EXPECTED_RENDERER_COPIES
    ):
        raise SystemExit(
            "refusing to patch Orca: workspace positioning verification failed"
        )
    if patched_bytes.count(b"onClickCapture: (event) => rightSidebarOpen") != 1:
        raise SystemExit(
            "refusing to patch Orca: desktop click-outside verification failed"
        )
    if (
        patched_bytes.count(b'event.target.closest(".absolute.right-0.z-30")')
        != EXPECTED_RENDERER_COPIES
    ):
        raise SystemExit("refusing to patch Orca: click-outside verification failed")
    if patched_bytes.count(PR_NUMBER_MARKER) != EXPECTED_RENDERER_COPIES:
        raise SystemExit(
            "refusing to patch Orca: worktree-card PR-number verification failed"
        )

    asar_path.write_bytes(patched_bytes)


if __name__ == "__main__":
    main()
