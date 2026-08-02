#!/usr/bin/env bun
/**
 * Generates per-harness agent definitions from harness-agnostic crewmates.
 *
 * Each crewmate lives in crewmates/<name>/ with:
 *   PROMPT.md  — the agent body, no frontmatter, model-agnostic
 *   meta.json  — name, description + per-harness config ("claude-code", "opencode")
 *
 * Usage:
 *   bun scripts/generate-adapters.ts                 # emit to global locations
 *   bun scripts/generate-adapters.ts --dry           # print what would be written
 *   bun scripts/generate-adapters.ts --only implementer
 *   bun scripts/generate-adapters.ts \
 *     --claude-out ./out/claude --opencode-out ./out/opencode
 *
 * Defaults:
 *   claude-code -> ~/.claude/agents/<name>.md
 *   opencode    -> ~/.config/opencode/agent/<name>.md
 */
import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

interface ClaudeCodeConfig {
  model?: string;
  tools?: string[];
}

interface OpencodeConfig {
  mode?: "subagent" | "primary" | "all";
  model?: string;
  tools?: Record<string, boolean>;
}

interface CrewmateMeta {
  name: string;
  description: string;
  "claude-code"?: ClaudeCodeConfig;
  opencode?: OpencodeConfig;
}

const ROOT = join(import.meta.dir, "..");
const CREWMATES_DIR = join(ROOT, "crewmates");

const args = process.argv.slice(2);
const flag = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const dry = args.includes("--dry");
const only = flag("--only");
const claudeOut = flag("--claude-out") ?? join(homedir(), ".claude", "agents");
const opencodeOut = flag("--opencode-out") ?? join(homedir(), ".config", "opencode", "agent");

function loadCrewmates(): Array<{ meta: CrewmateMeta; prompt: string }> {
  const dirs = readdirSync(CREWMATES_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .filter((name) => !only || name === only);

  return dirs.map((dir) => {
    const metaPath = join(CREWMATES_DIR, dir, "meta.json");
    const promptPath = join(CREWMATES_DIR, dir, "PROMPT.md");
    if (!existsSync(metaPath)) throw new Error(`missing meta.json in ${dir}`);
    if (!existsSync(promptPath)) throw new Error(`missing PROMPT.md in ${dir}`);

    const meta = JSON.parse(readFileSync(metaPath, "utf8")) as CrewmateMeta;
    if (!meta.name || !meta.description) {
      throw new Error(`${dir}/meta.json needs "name" and "description"`);
    }
    return { meta, prompt: readFileSync(promptPath, "utf8").trim() };
  });
}

// Quote YAML values that contain characters a strict parser would choke on.
function yamlValue(value: string): string {
  return /[:#\[\]{}&*!|>'"%@`,]/.test(value) ? JSON.stringify(value) : value;
}

function claudeCodeAdapter(meta: CrewmateMeta, prompt: string): string {
  const cfg = meta["claude-code"] ?? {};
  const lines = [`name: ${meta.name}`, `description: ${yamlValue(meta.description)}`];
  if (cfg.model) lines.push(`model: ${cfg.model}`);
  if (cfg.tools?.length) lines.push(`tools: ${cfg.tools.join(", ")}`);
  return `---\n${lines.join("\n")}\n---\n\n${prompt}\n`;
}

function opencodeAdapter(meta: CrewmateMeta, prompt: string): string {
  const cfg = meta.opencode ?? {};
  const lines = [`description: ${yamlValue(meta.description)}`, `mode: ${cfg.mode ?? "subagent"}`];
  if (cfg.model) lines.push(`model: ${cfg.model}`);
  if (cfg.tools && Object.keys(cfg.tools).length) {
    lines.push("tools:");
    for (const [tool, enabled] of Object.entries(cfg.tools)) {
      lines.push(`  ${tool}: ${enabled}`);
    }
  }
  return `---\n${lines.join("\n")}\n---\n\n${prompt}\n`;
}

function emit(path: string, content: string): void {
  if (dry) {
    console.log(`-- would write ${path}`);
    return;
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
  console.log(`wrote ${path}`);
}

const crewmates = loadCrewmates();
if (crewmates.length === 0) {
  console.error(only ? `no crewmate named "${only}"` : "no crewmates found");
  process.exit(1);
}

for (const { meta, prompt } of crewmates) {
  emit(join(claudeOut, `${meta.name}.md`), claudeCodeAdapter(meta, prompt));
  emit(join(opencodeOut, `${meta.name}.md`), opencodeAdapter(meta, prompt));
}

console.log(`${crewmates.length} crewmate(s) -> claude-code: ${claudeOut}, opencode: ${opencodeOut}`);
