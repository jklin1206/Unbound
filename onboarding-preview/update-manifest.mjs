import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const [file, title, note = "Captured from booted simulator"] = process.argv.slice(2);

if (!file || !title) {
  console.error("Usage: node update-manifest.mjs <file> <title> [note]");
  process.exit(1);
}

const root = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.join(root, "swiftui-screenshots", "manifest.json");
const dataPath = path.join(root, "swiftui-screenshots", "screenshots-data.js");
const existing = fs.existsSync(manifestPath)
  ? JSON.parse(fs.readFileSync(manifestPath, "utf8"))
  : { screenshots: [] };

const screenshots = Array.isArray(existing.screenshots) ? existing.screenshots : [];
const nextEntry = {
  file,
  title,
  note,
  capturedAt: new Date().toISOString()
};

const next = [
  nextEntry,
  ...screenshots.filter((shot) => shot.file !== file)
].sort((a, b) => a.title.localeCompare(b.title, undefined, { numeric: true }));

const payload = { screenshots: next };

fs.writeFileSync(manifestPath, `${JSON.stringify(payload, null, 2)}\n`);
fs.writeFileSync(dataPath, `window.swiftuiScreenshots = ${JSON.stringify(payload, null, 2)};\n`);
