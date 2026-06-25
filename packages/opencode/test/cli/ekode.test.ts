// Verifies the CLI presents itself as `ekode` (the local rebrand) rather than
// `opencode`. Spawns the real TS entrypoint through Bun so the yargs scriptName
// and the help-gate change in src/index.ts are exercised end to end.
//
// yargs writes --help to stderr (via the `show()` callback) and --version to
// stdout, so each assertion checks the stream the program actually writes to.
import { describe, expect, test } from "bun:test"
import { join } from "path"

const entrypoint = join(import.meta.dir, "..", "..", "src", "index.ts")
const cwd = join(import.meta.dir, "..", "..")

async function spawn(args: string[]) {
  const proc = Bun.spawn(["bun", "run", "--conditions=browser", entrypoint, ...args], {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
  })
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ])
  return { stdout, stderr, exitCode }
}

describe("ekode CLI rebrand", () => {
  test("--help presents the program as ekode and exits 0", async () => {
    const result = await spawn(["--help"])
    expect(result.exitCode).toBe(0)
    // The command list is prefixed with the scriptName.
    expect(result.stderr).toContain("ekode run")
    expect(result.stderr).toContain("ekode serve")
    // No command-list line is still prefixed with the old program name.
    // (Command descriptions legitimately mention "opencode", so match only
    // an indented, line-leading `opencode <command>` usage prefix.)
    expect(result.stderr).not.toMatch(/\n\s+opencode\s+\S/)
  })

  test("subcommand help is not prefixed with the logo banner", async () => {
    const result = await spawn(["run", "--help"])
    expect(result.exitCode).toBe(0)
    // The help-gate keys off the `ekode ` usage prefix; if it still checked
    // `opencode `, the ASCII logo would be wrongly prepended here.
    expect(result.stderr.trimStart().startsWith("ekode run")).toBe(true)
  })

  test("--version prints a version string and exits 0", async () => {
    const result = await spawn(["--version"])
    expect(result.exitCode).toBe(0)
    expect(result.stdout.trim().length).toBeGreaterThan(0)
  })
})
