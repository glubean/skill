#!/usr/bin/env node

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "..");

const markdownExtensions = new Set([".md", ".mdx"]);
const ignoredDirs = new Set([".git", "dist", "node_modules"]);

const defaults = {
  skillDir: path.join(repoRoot, "glubean"),
  out: path.join(repoRoot, "dist", "glubean-custom-gpt-context.md"),
  includeReadme: true,
};

function usage() {
  return `Usage: node scripts/build-custom-gpt-context.mjs [options]

Options:
  --skill-dir <path>     Skill directory to bundle. Default: glubean
  --out <path>           Output markdown file. Default: dist/glubean-custom-gpt-context.md
  --no-readme            Do not include repository README.md before the skill files
  -h, --help             Show this help message
`;
}

function parseArgs(argv) {
  const args = { ...defaults };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "-h" || arg === "--help") {
      args.help = true;
      continue;
    }

    if (arg === "--no-readme") {
      args.includeReadme = false;
      continue;
    }

    if (arg === "--skill-dir" || arg === "--out") {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) {
        throw new Error(`${arg} requires a value`);
      }

      args[arg === "--skill-dir" ? "skillDir" : "out"] = path.resolve(repoRoot, value);
      index += 1;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return args;
}

function toPosixPath(filePath) {
  return path.relative(repoRoot, filePath).split(path.sep).join("/");
}

async function pathExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function walkMarkdownFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.name.startsWith(".") || ignoredDirs.has(entry.name)) {
      continue;
    }

    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      files.push(...(await walkMarkdownFiles(fullPath)));
      continue;
    }

    if (entry.isFile() && markdownExtensions.has(path.extname(entry.name))) {
      files.push(fullPath);
    }
  }

  return files;
}

function fileSortKey(filePath) {
  const relativePath = toPosixPath(filePath);

  if (relativePath.endsWith("/SKILL.md")) {
    return `00:${relativePath}`;
  }

  if (relativePath.endsWith("/references/index.md")) {
    return `01:${relativePath}`;
  }

  return `10:${relativePath}`;
}

function shiftHeadings(markdown, depth = 1) {
  let inFence = false;
  let fenceMarker = "";

  return markdown
    .split("\n")
    .map((line) => {
      const fenceMatch = line.match(/^(\s*)(`{3,}|~{3,})/);
      if (fenceMatch) {
        const marker = fenceMatch[2][0];
        if (!inFence) {
          inFence = true;
          fenceMarker = marker;
        } else if (marker === fenceMarker) {
          inFence = false;
          fenceMarker = "";
        }
        return line;
      }

      if (inFence) {
        return line;
      }

      return line.replace(/^(#{1,5})(\s+)/, (match, hashes, spacing) => {
        return `${"#".repeat(Math.min(hashes.length + depth, 6))}${spacing}`;
      });
    })
    .join("\n");
}

function sourceBlock(filePath, content) {
  const relativePath = toPosixPath(filePath);
  const shiftedContent = shiftHeadings(content.trimEnd(), 2);

  return [
    `## Source: \`${relativePath}\``,
    "",
    `<!-- BEGIN SOURCE ${relativePath} -->`,
    "",
    shiftedContent,
    "",
    `<!-- END SOURCE ${relativePath} -->`,
  ].join("\n");
}

async function buildBundle({ skillDir, out, includeReadme }) {
  if (!(await pathExists(skillDir))) {
    throw new Error(`Skill directory does not exist: ${skillDir}`);
  }

  const sourceFiles = [];
  const readmePath = path.join(repoRoot, "README.md");

  if (includeReadme && (await pathExists(readmePath))) {
    sourceFiles.push(readmePath);
  }

  const skillFiles = (await walkMarkdownFiles(skillDir)).sort((a, b) => {
    return fileSortKey(a).localeCompare(fileSortKey(b));
  });

  sourceFiles.push(...skillFiles);

  const generatedAt = new Date().toISOString();
  const index = sourceFiles.map((filePath) => `- \`${toPosixPath(filePath)}\``).join("\n");
  const blocks = [];

  for (const filePath of sourceFiles) {
    const content = await fs.readFile(filePath, "utf8");
    blocks.push(sourceBlock(filePath, content));
  }

  const bundle = [
    "# Glubean Custom GPT Context",
    "",
    `Generated at: ${generatedAt}`,
    `Source root: \`${toPosixPath(skillDir)}\``,
    `Included files: ${sourceFiles.length}`,
    "",
    "This file bundles the Glubean agent skill, its references, and the bundled Glubean documentation into one Markdown context file for upload to a Custom GPT.",
    "",
    "## Source Index",
    "",
    index,
    "",
    "---",
    "",
    blocks.join("\n\n---\n\n"),
    "",
  ].join("\n");

  await fs.mkdir(path.dirname(out), { recursive: true });
  await fs.writeFile(out, bundle, "utf8");

  return { out, sourceFiles };
}

async function main() {
  try {
    const args = parseArgs(process.argv.slice(2));

    if (args.help) {
      process.stdout.write(usage());
      return;
    }

    const { out, sourceFiles } = await buildBundle(args);
    const stats = await fs.stat(out);

    process.stdout.write(
      [
        `Wrote ${toPosixPath(out)}`,
        `Included ${sourceFiles.length} markdown files`,
        `Size ${stats.size.toLocaleString("en-US")} bytes`,
        "",
      ].join("\n"),
    );
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.stderr.write(usage());
    process.exitCode = 1;
  }
}

await main();
