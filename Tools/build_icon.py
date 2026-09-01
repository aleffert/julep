#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Generate Apps/Shared/Julep.icon from Tools/icon-source.{svg,png}.

An Icon Composer package: an icon.json manifest plus an Assets directory of layer
images. The system draws the background gradient, the silhouette, the shadow under the
artwork and the specular highlight on the edge, so the source artwork is the foreground
only -- no baked background, mask, rim or shadow of its own.

An SVG source is copied through untouched so it stays vector at every rendered size. A
PNG source is composited onto a 1024 canvas, which is all a raster can offer.

Julep.icon is also an Icon Composer document -- open it and the app edits it in place. So
once icon.json exists this script leaves it alone and refreshes only the layer artwork,
and hand tuning in Icon Composer survives re-running it. Pass --reset to throw those edits
away and regenerate the manifest from the constants below.

Run with `mise run icon`, or `mise run icon -- --reset`.
"""

import argparse
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ICON = REPO / "Apps/Shared/Julep.icon"

# SVG wins if both are present -- it is the better source and the one to migrate toward.
CANDIDATES = [REPO / "Tools/icon-source.svg", REPO / "Tools/icon-source.png"]

CANVAS = 1024
ARTWORK_SCALE = 0.70  # artwork width as a fraction of the canvas, for raster sources

# Carried over from the hand-built icon: vertical, light top to dark bottom.
GRAD_TOP = (26, 116, 100)
GRAD_BOTTOM = (10, 58, 62)


def color(rgb):
    r, g, b = (c / 255.0 for c in rgb)
    return f"extended-srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"


def manifest(image_name):
    return {
        "fill": {
            "linear-gradient": [color(GRAD_TOP), color(GRAD_BOTTOM)],
            # Top to bottom. The HIG asks for top-to-bottom light-to-dark, and Apple's
            # own icons measure as vertical with no meaningful horizontal component.
            "orientation": {"start": {"x": 0.5, "y": 0.0}, "stop": {"x": 0.5, "y": 1.0}},
        },
        "groups": [
            {
                "name": "Sprig",
                "layers": [{"name": "Sprig", "image-name": image_name}],
                # The system's own shadow, in place of one baked into the artwork.
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "specular": True,
            }
        ],
        "supported-platforms": {"squares": "shared"},
    }


def write_layer(src, dest):
    """An SVG passes through as-is; a PNG is centred on a transparent 1024 canvas."""
    if src.suffix.lower() == ".svg":
        shutil.copyfile(src, dest)
        return

    from PIL import Image

    art = Image.open(src).convert("RGBA")
    width = round(ARTWORK_SCALE * CANVAS)
    art = art.resize((width, round(art.height * width / art.width)), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((CANVAS - art.width) // 2, (CANVAS - art.height) // 2))
    canvas.save(dest)


def layer_names(doc):
    for group in doc.get("groups", []):
        for layer in group.get("layers", []):
            if "image-name" in layer:
                yield layer["image-name"]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reset", action="store_true",
                    help="regenerate icon.json, discarding any Icon Composer edits")
    args = ap.parse_args()

    src = next((p for p in CANDIDATES if p.exists()), None)
    if src is None:
        raise SystemExit(f"no source artwork; expected one of {[str(p) for p in CANDIDATES]}")

    doc_path = ICON / "icon.json"
    existing = None
    if doc_path.exists() and not args.reset:
        existing = json.loads(doc_path.read_text())

    if existing is None:
        if ICON.exists():
            shutil.rmtree(ICON)
        (ICON / "Assets").mkdir(parents=True)
        image_name = f"sprig{src.suffix.lower()}"
        write_layer(src, ICON / "Assets" / image_name)
        doc_path.write_text(json.dumps(manifest(image_name), indent=2) + "\n")
        note = "manifest reset" if args.reset else "created"
    else:
        # Refresh the artwork under whatever filename the document already points at, so
        # Icon Composer's own edits to icon.json keep working.
        names = [n for n in layer_names(existing) if Path(n).stem == "sprig"]
        if len(names) != 1 or Path(names[0]).suffix.lower() != src.suffix.lower():
            raise SystemExit(
                f"{doc_path.relative_to(REPO)} references {names or 'no sprig layer'}, which does "
                f"not match {src.name}. Re-run with --reset to regenerate the manifest "
                f"(this discards Icon Composer edits)."
            )
        image_name = names[0]
        write_layer(src, ICON / "Assets" / image_name)
        note = "artwork only, manifest preserved"

    print(f"{ICON.relative_to(REPO)} <- {src.relative_to(REPO)} (layer: {image_name}; {note})")


if __name__ == "__main__":
    main()
