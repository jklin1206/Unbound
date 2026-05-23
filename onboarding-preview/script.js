const asset = (path) => `../${path}`;

const ranks = {
  initiate: asset("generated-skill-media/ranks/transparent/rank_title_initiate_transparent.png"),
  vessel: asset("generated-skill-media/ranks/transparent/rank_title_vessel_transparent.png"),
  unbound: asset("generated-skill-media/ranks/transparent/rank_title_unbound_transparent.png"),
  ascendant: asset("generated-skill-media/ranks/transparent/rank_title_ascendant_transparent.png")
};

const body = {
  dormant: asset("UNBOUND/Resources/BodyMap/body_baseline.png"),
  vtaper: asset("UNBOUND/Resources/BodyMap/archetype_vtaper.png"),
  shredded: asset("UNBOUND/Resources/BodyMap/archetype_shredded.png"),
  heavy: asset("UNBOUND/Resources/BodyMap/archetype_heavyweight.png"),
  sleeper: asset("UNBOUND/Resources/BodyMap/archetype_sleeper.png"),
  opening: asset("UNBOUND/Resources/BodyMap/openingscreen.png")
};

const statOrder = ["POW", "AGI", "CTL", "END", "MOB", "EXP"];

const screens = [
  {
    id: "opening",
    label: "01 Opening",
    eyebrow: "UNBOUND",
    title: "Start your arc.",
    subtitle: "Every session moves your story forward. The training arc, except this one is yours.",
    button: "Begin",
    art: `<img class="opening-img" src="${body.opening}" alt="">`
  },
  {
    id: "pain",
    label: "02 Pain",
    eyebrow: "DAY ZERO",
    title: "Your stats aren't there yet.",
    subtitle: "No clear rank. No map. Just the feeling that you should be further than this.",
    button: "Show the ladder",
    art: `<div class="split"><div class="character"><img src="${body.dormant}" alt=""></div>${hexBlock([8,7,8,9,8,7], false)}</div>`,
    pills: ["INITIATE", "DAY ZERO", "NO MAP YET"]
  },
  {
    id: "ranks",
    label: "03 Rank Ladder",
    eyebrow: "RANK LADDER",
    title: "There are levels above this.",
    subtitle: "Vessel. Unbound. Ascendant. Names you do not get by accident.",
    button: "Keep going",
    art: `<div class="hero-art">${rankOrbit()}</div>`
  },
  {
    id: "build-preview",
    label: "04 Future Cards",
    eyebrow: "BUILD PREVIEW",
    title: "Different builds. Different stats.",
    subtitle: "The card changes as the work changes you.",
    button: "Climb the ranks",
    art: buildPreview()
  },
  {
    id: "goals",
    label: "05 Goal",
    eyebrow: "THE WANT",
    title: "What are you chasing?",
    subtitle: "Pick the version of you that keeps showing up in your head.",
    button: "Continue",
    art: optionStack([
      ["Build muscle", "Look stronger in the mirror"],
      ["Get lean", "Cut the noise and reveal the work"],
      ["Get athletic", "Move like your body is awake"],
      ["Get stronger", "Make the numbers climb"]
    ])
  },
  {
    id: "obstacle",
    label: "06 Pain Point",
    eyebrow: "THE WALL",
    title: "What keeps stopping the arc?",
    subtitle: "This is the part UNBOUND has to beat for you.",
    button: "Continue",
    art: optionStack([
      ["I don't know what to do", "The next move is never clear"],
      ["I fall off", "Consistency breaks before results arrive"],
      ["I plateau", "The work stops feeling like it is changing me"],
      ["I run out of time", "The perfect week never happens"]
    ])
  },
  {
    id: "handle",
    label: "07 Handle",
    eyebrow: "IDENTITY",
    title: "What's your handle?",
    subtitle: "This is the name on your Day Zero card.",
    button: "Lock it in",
    art: `<div class="card" style="margin-top:40px"><div class="eyebrow">@ HANDLE</div><div class="title" style="font-size:42px">@UNBOUND</div><p class="subtitle">The card starts empty. That is the point.</p></div>`
  },
  {
    id: "entry-map",
    label: "08 Entry Map",
    eyebrow: "ENTRY MAP",
    title: "Your starting point is set.",
    subtitle: "Day Zero is marked. The climb starts from here.",
    button: "Start my arc",
    art: baselineMap()
  },
  {
    id: "scan",
    label: "09 Arc Entry",
    eyebrow: "ARC ENTRY",
    title: "Commit the starting frame.",
    subtitle: "One image for the version you are about to leave behind.",
    button: "Capture frame",
    art: `<div class="hero-art"><div class="character"><img src="${body.dormant}" alt=""></div></div>`
  },
  {
    id: "reveal",
    label: "10 Profile Reveal",
    eyebrow: "DAY ZERO PROFILE",
    title: "This is where the card begins.",
    subtitle: "Every session after this has somewhere to land.",
    button: "Show me the climb",
    art: profileReveal()
  },
  {
    id: "trajectory",
    label: "11 Trajectory",
    eyebrow: "12 MONTHS",
    title: "One path keeps repeating.",
    subtitle: "One path starts climbing.",
    button: "See my arc",
    art: trajectory()
  },
  {
    id: "paywall",
    label: "12 Paywall",
    eyebrow: "ARC READY",
    title: "Start your arc.",
    subtitle: "Every rep tracked. Every node earned. Every milestone yours.",
    button: "Unlock UNBOUND",
    art: optionStack([
      ["Three arcs built around where you start", ""],
      ["Full skill tree: muscle-up, front lever, the whole ladder", ""],
      ["Rescan anytime - watch the arc move", ""],
      ["Daily sessions, streaks, and gains you keep", ""]
    ])
  }
];

let active = 0;

const phone = document.getElementById("phoneScreen");
const list = document.getElementById("screenList");
const grid = document.getElementById("screenGrid");
const gridToggle = document.getElementById("gridToggle");
const actualSection = document.getElementById("actualSection");
const actualGrid = document.getElementById("actualGrid");
const actualToggle = document.getElementById("actualToggle");
const reloadActualBtn = document.getElementById("reloadActualBtn");

function renderScreen(screen) {
  return `
    <div class="screen-content">
      <div>
        <div class="eyebrow">${screen.eyebrow}</div>
        <h2 class="title">${screen.title}</h2>
        <p class="subtitle">${screen.subtitle}</p>
      </div>
      ${screen.pills ? `<div class="pill-row" style="margin-top:16px">${screen.pills.map(p => `<span class="pill">${p}</span>`).join("")}</div>` : ""}
      <div class="hero-art">${screen.art}</div>
      <button class="cta" type="button">${screen.button}</button>
    </div>
  `;
}

function setActive(index) {
  active = (index + screens.length) % screens.length;
  phone.innerHTML = renderScreen(screens[active]);
  [...list.children].forEach((btn, i) => btn.classList.toggle("active", i === active));
}

function renderNav() {
  list.innerHTML = screens.map((s, i) => `<button type="button">${s.label}</button>`).join("");
  [...list.children].forEach((btn, i) => btn.addEventListener("click", () => setActive(i)));
}

function renderGrid() {
  grid.innerHTML = screens.map((s, i) => `
    <div class="thumb" data-index="${i}">
      <article class="screen">${renderScreen(s)}</article>
    </div>
  `).join("");
  [...grid.children].forEach(node => node.addEventListener("click", () => setActive(Number(node.dataset.index))));
}

async function renderActualScreenshots() {
  try {
    if (window.swiftuiScreenshots?.screenshots?.length) {
      renderActualCards(window.swiftuiScreenshots.screenshots);
      return;
    }

    const response = await fetch("./swiftui-screenshots/manifest.json", { cache: "no-store" });
    if (!response.ok) throw new Error("No manifest");
    const manifest = await response.json();
    const shots = manifest.screenshots || [];
    if (shots.length === 0) throw new Error("Empty manifest");
    renderActualCards(shots);
  } catch {
    actualGrid.innerHTML = `
      <div class="empty-actual">
        No simulator screenshots yet. After a SwiftUI change, build/run the app and save screenshots into
        <code>onboarding-preview/swiftui-screenshots</code> with a <code>manifest.json</code>.
      </div>
    `;
  }
}

function renderActualCards(shots) {
  actualGrid.innerHTML = shots.map((shot) => `
    <article class="actual-card">
      <img src="./swiftui-screenshots/${shot.file}?t=${Date.now()}" alt="${shot.title}">
      <div class="actual-meta">
        <b>${shot.title}</b>
        <span>${shot.note || shot.file}</span>
      </div>
    </article>
  `).join("");
}

function hexBlock(values, labels = true) {
  const points = values.map((value, index) => {
    const angle = -Math.PI / 2 + index * (Math.PI * 2 / 6);
    const r = 48 * (value / 40);
    return `${64 + Math.cos(angle) * r},${64 + Math.sin(angle) * r}`;
  }).join(" ");
  const axes = statOrder.map((label, index) => {
    const angle = -Math.PI / 2 + index * (Math.PI * 2 / 6);
    const x = 64 + Math.cos(angle) * 57;
    const y = 64 + Math.sin(angle) * 57;
    const lx = 64 + Math.cos(angle) * 72;
    const ly = 64 + Math.sin(angle) * 72;
    return `<line x1="64" y1="64" x2="${x}" y2="${y}" />${labels ? `<text x="${lx}" y="${ly}">${label} ${values[index]}</text>` : ""}`;
  }).join("");
  return `
    <svg class="hex" viewBox="-18 -18 164 164" role="img" aria-label="Attribute hex">
      <g class="grid">
        <polygon points="64,16 105.6,40 105.6,88 64,112 22.4,88 22.4,40"></polygon>
        <polygon points="64,32 91.7,48 91.7,80 64,96 36.3,80 36.3,48"></polygon>
        ${axes}
      </g>
      <polygon class="fill" points="${points}"></polygon>
    </svg>
  `;
}

function baselineMap() {
  return `
    <div class="baseline-layout">
      <div class="card rank-lock">
        <div>
          <div class="eyebrow">ENTRY MAP</div>
          <div class="rank-name">INITIATE</div>
          <p class="subtitle">This is the first mark. Everything above it has to be earned.</p>
        </div>
        <img class="badge" src="${ranks.initiate}" alt="">
      </div>
      <div class="card hex-wrap">
        ${hexBlock([3,1,1,1,3,1], true)}
        <div class="mini-list">
          ${metric("OVERALL LV", "LV 0")}
          ${metric("FOCUS", "FULL BODY")}
          ${metric("FIRST SPARK", "POW + MOB")}
        </div>
      </div>
      <p class="subtitle">The blank parts are the point. Your first sessions start turning this into something real.</p>
    </div>
  `;
}

function buildPreview() {
  return `
    <div class="split">
      <div class="character"><img src="${body.vtaper}" alt=""></div>
      <div>
        <img class="badge" src="${ranks.unbound}" alt="">
        <h3 style="font-size:24px;margin:8px 0">Endurance + Pull</h3>
        <p class="subtitle">Long output. Explosive upper body.</p>
        ${hexBlock([24,21,23,32,19,29], true)}
        <div class="mini-list">
          ${statRow("POW", 24, 32)}
          ${statRow("AGI", 21, 32)}
          ${statRow("CTL", 23, 32)}
          ${statRow("END", 32, 32)}
          ${statRow("MOB", 19, 32)}
          ${statRow("EXP", 29, 32)}
        </div>
      </div>
    </div>
  `;
}

function profileReveal() {
  return `
    <div class="card">
      <div class="rank-lock">
        <div>
          <div class="eyebrow">DAY ZERO PROFILE</div>
          <div class="rank-name">@UNBOUND</div>
          <p class="subtitle">A card with room to become dangerous.</p>
        </div>
        <img class="badge" src="${ranks.initiate}" alt="">
      </div>
      <div class="hex-wrap" style="margin-top:16px">
        ${hexBlock([5,2,4,3,5,2], true)}
        <div class="mini-list">
          ${metric("START", "INITIATE")}
          ${metric("FIRST WALL", "SHOW UP")}
          ${metric("NEXT", "ARC 1")}
        </div>
      </div>
    </div>
  `;
}

function rankOrbit() {
  const items = [
    ["initiate", "Initiate"],
    ["vessel", "Vessel"],
    ["unbound", "Unbound"],
    ["ascendant", "Ascendant"]
  ];
  return `
    <div style="position:relative;width:280px;height:280px">
      ${items.map(([key, name], i) => {
        const angle = -90 + i * 90;
        const x = 128 + Math.cos(angle * Math.PI / 180) * 104;
        const y = 128 + Math.sin(angle * Math.PI / 180) * 104;
        return `<img src="${ranks[key]}" alt="${name}" style="position:absolute;left:${x}px;top:${y}px;width:70px;height:70px;object-fit:contain;filter:drop-shadow(0 0 18px rgba(95,255,234,.22))">`;
      }).join("")}
      <img src="${ranks.unbound}" alt="" style="position:absolute;left:88px;top:80px;width:112px;height:112px;object-fit:contain;filter:drop-shadow(0 0 28px rgba(95,255,234,.42))">
      <div style="position:absolute;left:0;right:0;bottom:28px;text-align:center;font-weight:950;font-size:28px">UNBOUND</div>
    </div>
  `;
}

function trajectory() {
  return `
    <div class="card">
      <div class="eyebrow">RANK OVER TIME</div>
      <svg viewBox="0 0 320 220" style="width:100%;margin-top:16px">
        <path d="M24 178 C 100 172, 196 174, 296 170" fill="none" stroke="rgba(255,255,255,.28)" stroke-width="3" />
        <path d="M24 178 C 86 156, 122 110, 174 80 S 250 42, 296 28" fill="none" stroke="#5fffea" stroke-width="5" />
        <text x="24" y="205" fill="#8d98a3" font-size="12">Day Zero</text>
        <text x="232" y="205" fill="#8d98a3" font-size="12">Month 12</text>
      </svg>
      <p class="subtitle">The difference is not hype. It is having a visible climb to come back to.</p>
    </div>
  `;
}

function optionStack(items) {
  return `<div class="option-stack">${items.map(([title, detail], i) => `
    <div class="option"><span class="pill">${String(i + 1).padStart(2, "0")}</span><div><strong>${title}</strong>${detail ? `<small>${detail}</small>` : ""}</div></div>
  `).join("")}</div>`;
}

function metric(label, value) {
  return `<div class="metric"><b>${label}</b><span>${value}</span></div>`;
}

function statRow(label, value, max) {
  return `<div class="mini-row"><span>${label}</span><div class="bar"><span style="width:${Math.round(value / max * 100)}%"></span></div><span>LV ${value}</span></div>`;
}

document.getElementById("prevBtn").addEventListener("click", () => setActive(active - 1));
document.getElementById("nextBtn").addEventListener("click", () => setActive(active + 1));
gridToggle.addEventListener("change", () => grid.classList.toggle("hidden", !gridToggle.checked));
actualToggle.addEventListener("change", () => actualSection.classList.toggle("hidden", !actualToggle.checked));
reloadActualBtn.addEventListener("click", renderActualScreenshots);
document.addEventListener("keydown", (event) => {
  if (event.key === "ArrowLeft") setActive(active - 1);
  if (event.key === "ArrowRight") setActive(active + 1);
});

renderNav();
renderGrid();
renderActualScreenshots();
setActive(0);
