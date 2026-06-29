#!/usr/bin/env python3
"""
Build the movement-library VERIFICATION sheet (docs/movement-library.html) from the
authoritative manifest dumped by the app's real resolver
(UNBOUNDTests/ExerciseVisualManifestDumpTests -> docs/asset-sets/exercise-visual-manifest.json).

Every card shows the EXACT image the code resolves for that asset, the resolved asset
name, every movement/skill surface that uses it, and a load badge. This is the
"does the art match code" ground-truth sheet - no python-guessed asset names.

Refresh flow:
  1. xcodebuild test ... -only-testing:UNBOUNDTests/ExerciseVisualManifestDumpTests   # writes the manifest
  2. python3 scripts/gen_library.py                                                    # writes the html
"""
import os, io, json, glob, base64, datetime
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(REPO, "UNBOUND/Assets.xcassets")
MANIFEST = os.path.join(REPO, "docs/asset-sets/exercise-visual-manifest.json")
OUT = os.path.join(REPO, "docs/movement-library.html")

entries = json.load(open(MANIFEST))

# index every png by "<imageset stem>" -> path, root set first (the shipped set)
def asset_path(asset):
    # exact: <asset>.imageset/<asset>.png, prefer root over Jot/Legacy
    hits = glob.glob(os.path.join(ASSETS, "**", f"{asset}.imageset", f"{asset}.png"), recursive=True)
    hits.sort(key=lambda p: ("ExerciseVisualsJot" in p, "ExerciseVisualsLegacy" in p))
    return hits[0] if hits else None

# group surfaces by resolved asset
by_asset = {}
for e in entries:
    by_asset.setdefault(e["asset"], []).append(e)

ROLE_RANK = {"canonicalExercise": 0, "skillNode": 1, "skillTarget": 2, "skillDrill": 3,
             "cardioModality": 4, "carrySled": 5, "mobilityDuration": 6}

cards, missing = [], 0
thumb_cache = {}
for asset, surfaces in sorted(by_asset.items()):
    surfaces.sort(key=lambda s: ROLE_RANK.get(s["role"], 9))
    primary = surfaces[0]
    loads = all(s["loads"] for s in surfaces)
    p = asset_path(asset)
    img = ""
    if p:
        if asset not in thumb_cache:
            try:
                im = Image.open(p).convert("RGBA")
                bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im)
                bg = bg.convert("RGB"); bg.thumbnail((240, 240))
                buf = io.BytesIO(); bg.save(buf, "WEBP", quality=80)
                thumb_cache[asset] = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
            except Exception:
                thumb_cache[asset] = ""
        img = thumb_cache[asset]
    ok = loads and bool(p) and bool(img)
    if not ok:
        missing += 1
    cards.append({
        "name": primary["displayName"],
        "asset": asset,
        "img": img,
        "ok": ok,
        "names": sorted({s["displayName"] for s in surfaces}),
        "surfaces": [{"id": s["id"], "role": s["role"], "loads": s["loads"]} for s in surfaces],
    })

cards.sort(key=lambda c: (c["ok"], c["name"].lower()))  # flagged first
gen = datetime.datetime.now().strftime("%Y-%m-%d")
total_surfaces = len(entries)
data_js = json.dumps(cards)

doc = """<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UNBOUND - Visual Verification Sheet</title>
<style>
:root{--bg:#0a0a0a;--surface:#161616;--border:#2a2a2a;--text:#f2f2f0;--muted:#9a9a9a;--ok:#3ecf8e;--bad:#ff5b6a;--accent:#5b8def;}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 -apple-system,BlinkMacSystemFont,'SF Pro',Segoe UI,Roboto,sans-serif;padding:26px 30px 80px}
h1{font-size:22px;margin:0 0 4px}.sub{color:var(--muted);margin:0 0 18px;font-size:13px}
.cards{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:18px}
.stat{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:12px 16px;min-width:120px}
.stat .n{font-size:24px;font-weight:800;font-variant-numeric:tabular-nums}.stat .l{color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.7px}
.stat.bad .n{color:var(--bad)}.stat.ok .n{color:var(--ok)}
.bar{position:sticky;top:0;background:var(--bg);padding:10px 0;display:flex;gap:10px;align-items:center;flex-wrap:wrap;z-index:5}
input[type=search]{background:var(--surface);border:1px solid var(--border);color:var(--text);border-radius:10px;padding:9px 13px;font-size:13px;min-width:260px;outline:none}
.chip{background:var(--surface);border:1px solid var(--border);color:var(--muted);border-radius:999px;padding:7px 13px;font-size:12px;font-weight:600;cursor:pointer;user-select:none}
.chip.on{color:var(--text);border-color:#555}.count{color:var(--muted);margin-left:auto;font-size:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:14px}
.card{background:var(--surface);border:1px solid var(--border);border-radius:14px;overflow:hidden;display:flex;flex-direction:column}
.card.bad{border-color:var(--bad)}
.thumb{background:#fff;aspect-ratio:1;display:flex;align-items:center;justify-content:center}
.thumb img{width:100%;height:100%;object-fit:contain}
.thumb.none{background:#2a1416;color:var(--bad);font-size:12px;font-weight:700}
.meta{padding:9px 11px}
.nm{font-weight:700;font-size:13px;margin-bottom:3px}
.as{font-family:ui-monospace,Menlo,monospace;font-size:10.5px;color:#cfe9ff;word-break:break-all}
.badge{display:inline-block;font-size:10px;font-weight:800;border-radius:5px;padding:1px 6px;margin-top:6px}
.b-ok{background:var(--ok);color:#062} .b-bad{background:var(--bad);color:#400}
.surf{margin-top:6px;display:flex;flex-direction:column;gap:1px}
.surf .s{font-family:ui-monospace,monospace;font-size:9.5px;color:var(--muted)}
.role{color:var(--accent)}
.hide{display:none}
</style></head><body>
<h1>UNBOUND - Visual Verification Sheet</h1>
<p class="sub">One card per resolved art asset, pulled from the app's real resolver (ExerciseVisualManifestDumpTests). Each image is EXACTLY what code renders &middot; """ + gen + """</p>
<div class="cards">
  <div class="stat"><div class="n">""" + str(len(cards)) + """</div><div class="l">Unique images</div></div>
  <div class="stat"><div class="n">""" + str(total_surfaces) + """</div><div class="l">Movement surfaces</div></div>
  <div class="stat """ + ("bad" if missing else "ok") + """"><div class="n">""" + str(missing) + """</div><div class="l">Not loadable</div></div>
</div>
<div class="bar">
  <input type="search" id="q" placeholder="Search name, id, or asset...">
  <span class="chip" id="flagchip">Show only not-loadable</span>
  <span class="count" id="count"></span>
</div>
<div class="grid" id="grid"></div>
<script>
const DATA = """ + data_js + """;
let q="", flagged=false;
const grid=document.getElementById('grid'), count=document.getElementById('count');
function render(){
  const s=q.toLowerCase();
  let rows=DATA.filter(c=>{
    if(flagged && c.ok) return false;
    if(!s) return true;
    return c.asset.toLowerCase().includes(s) || c.names.some(n=>n.toLowerCase().includes(s))
      || c.surfaces.some(x=>x.id.toLowerCase().includes(s));
  });
  grid.innerHTML='';
  for(const c of rows){
    const el=document.createElement('div'); el.className='card'+(c.ok?'':' bad');
    const thumb=c.img?('<div class="thumb"><img loading="lazy" src="'+c.img+'"></div>')
                      :('<div class="thumb none">NO IMAGE</div>');
    const surf=c.surfaces.map(x=>'<div class="s"><span class="role">'+x.role+'</span> '+x.id+(x.loads?'':' ✗')+'</div>').join('');
    el.innerHTML=thumb+'<div class="meta"><div class="nm">'+c.name+'</div><div class="as">'+c.asset+'</div>'+
      '<span class="badge '+(c.ok?'b-ok':'b-bad')+'">'+(c.ok?'RESOLVES + LOADS':'CHECK')+'</span>'+
      '<div class="surf">'+surf+'</div></div>';
    grid.appendChild(el);
  }
  count.textContent=rows.length+' shown / '+DATA.length;
}
document.getElementById('q').oninput=e=>{q=e.target.value;render();};
document.getElementById('flagchip').onclick=function(){flagged=!flagged;this.classList.toggle('on',flagged);render();};
render();
</script></body></html>"""

open(OUT, "w").write(doc)
print(f"wrote {OUT}: {len(cards)} unique images, {total_surfaces} surfaces, {missing} not loadable")
