// A config key nobody reads is worse than a missing one: a server owner sets
// it, restarts, and nothing changes. This lists every key in config.lua that
// the resource never looks at.
//
// Reported rather than failed by default — some keys are read indirectly, and
// the point is to see the list, not to block a build. Pass --strict to fail.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = readFileSync(path.join(ROOT, 'config.lua'), 'utf8');

function walk(dir) {
    const full = path.join(ROOT, dir);
    if (!existsSync(full)) return [];

    const out = [];
    for (const name of readdirSync(full)) {
        const rel = `${dir}/${name}`;
        if (statSync(path.join(ROOT, rel)).isDirectory()) out.push(...walk(rel));
        else if (/\.(lua|js)$/.test(rel)) out.push(rel);
    }
    return out;
}

const files = ['bridge', 'shared', 'client', 'server', 'html']
    .flatMap(walk)
    .map((file) => readFileSync(path.join(ROOT, file), 'utf8'));

const sources = files.join('\n');

// A block is often pulled into a local first — `local admin = Config.Admin`
// and then `admin.acePermission`. Any file that aliases a block counts a bare
// `.key` in that same file as a read.
function readViaAlias(block, key) {
    // The block itself, not a field of it: `= Config.Admin` is an alias,
    // `= Config.Admin.groups` is just a read of one key and must not make
    // every other key in the block look used.
    const alias = new RegExp(`=\\s*Config\\.${block}(?!\\s*\\.)`);
    const bare = new RegExp(`\\.\\s*${key}\\b`);

    return files.some((src) => alias.test(src) && bare.test(src));
}

function isRead(name, key) {
    const patterns = [
        `Config.${name}.${key}`,
        `Config\\.${name}\\s*\\.\\s*${key}`,
        `${name}\\.${key}`,
    ];

    return patterns.some((p) => new RegExp(p.replace(/\./g, '\\.')).test(sources))
        || readViaAlias(name, key);
}

// Every top-level assignment, whether it opens a table or not. Both shapes
// appear: `Config.Thing = { ... }` and `Config.Thing.key = value` written
// underneath it, and the second one used to land INSIDE the first one's body
// — so the contents of a lookup map read as nine dead switches.
const statements = [...config.matchAll(/^Config\.([A-Za-z]+)((?:\.[A-Za-z][A-Za-z0-9]*)*)\s*=\s*(\{?)/gm)];
const unused = [];
let checked = 0;

for (const [i, statement] of statements.entries()) {
    const name = statement[1];
    const trail = statement[2];
    const end = i + 1 < statements.length ? statements[i + 1].index : config.length;

    // Config.Thing.key = ... — the key is the whole path, and whatever it
    // holds is data rather than nine more switches.
    if (trail) {
        const key = trail.slice(1);
        checked += 1;

        if (!isRead(name, key)) unused.push(`Config.${name}.${key}`);
        continue;
    }

    // Config.Thing = { ... } — its own keys, one level down. Nested tables
    // are data, not switches.
    if (!statement[3]) continue;

    const body = config.slice(statement.index, end);

    for (const m of body.matchAll(/^    ([a-zA-Z][A-Za-z0-9]*)\s*=/gm)) {
        const key = m[1];
        checked += 1;

        if (!isRead(name, key)) unused.push(`Config.${name}.${key}`);
    }
}

console.log(`check-config — ${checked} keys checked`);

if (unused.length) {
    console.log(`\n${unused.length} key(s) nothing reads:`);
    for (const key of unused) console.log(`  ${key}`);

    if (process.argv.includes('--strict')) process.exit(1);
} else {
    console.log('every config key is read somewhere');
}
