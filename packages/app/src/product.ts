/**
 * Every destination the Ekowork UI can send a user to.
 *
 * The CLI already has this shape: RELEASES_REPO in
 * packages/opencode/src/installation/index.ts, added because ekode's update
 * check was offering opencode's releases. This is the same fix for the app,
 * where the rebrand changed what the product is *called* but not where it
 * *points* -- the menu read "Ekowork Documentation" while filing bugs into
 * anomalyco/opencode's tracker.
 *
 * The split is deliberate, and it is the whole design:
 *
 *   - A link moves here when it is about *who ships this*: releases, issues,
 *     feedback, changelog, notification chrome. Those are identity.
 *   - A link stays pointing at opencode when it is about *how the product
 *     works* and opencode's page is the accurate one. Ekowork has no docs
 *     site. Sending a user to a 404 to avoid printing the word "opencode"
 *     would be worse than the honest link, so those stay and say so.
 *
 * Anything not listed here was left alone on purpose. See UPSTREAM below.
 */

/**
 * The repository Ekowork's releases and issues live in.
 *
 * Must stay equal to RELEASES_REPO in
 * packages/opencode/src/installation/index.ts. Two constants naming one
 * product is the bug this module exists to stop, but they sit in different
 * package graphs -- the CLI does not depend on the app -- so the coupling is
 * a comment rather than an import.
 */
export const REPO = "jaycoolslm/ekode"

export const REPO_URL = `https://github.com/${REPO}`

export const ISSUES_URL = `${REPO_URL}/issues`

/**
 * Template filenames exactly as they exist in .github/ISSUE_TEMPLATE/.
 *
 * The links these replaced asked for `bug_report.yml` and
 * `feature_request.yml` with underscores. This tree has `bug-report.yml` and
 * `feature-request.yml` with hyphens. GitHub does not error on an unknown
 * template -- it silently opens a blank issue -- so the old links had been
 * quietly dropping the template for however long the filenames have differed.
 */
export const BUG_REPORT_URL = `${ISSUES_URL}/new?template=bug-report.yml`
export const FEATURE_REQUEST_URL = `${ISSUES_URL}/new?template=feature-request.yml`

/**
 * Ekowork has no dedicated feedback page. The issue tracker is the honest
 * destination; opencode.ai/desktop-feedback collected feedback for a product
 * this is not.
 */
export const FEEDBACK_URL = ISSUES_URL

/**
 * Served by the app itself out of packages/app/public/favicon-96x96-v3.png,
 * the same file index.html already links at line 10.
 *
 * This was an absolute https://opencode.ai/... URL, so every desktop
 * notification fetched its icon from a host Ekowork does not control -- a
 * network round trip, and a hard dependency on someone else's CDN staying up.
 *
 * The artwork behind this path is still opencode's. The rebrand renamed
 * surfaces but never replaced the icon files, so there is no Eko AI mark to
 * point at yet. Dropping the Eko AI png into packages/app/public under this
 * name is the whole change when one exists.
 */
export const NOTIFICATION_ICON = "/favicon-96x96-v3.png"

/**
 * Release-notes feed, in the shape parseRelease() expects.
 *
 * Deliberately undefined. This was https://opencode.ai/changelog.json, so
 * Ekowork popped a dialog announcing opencode's releases. Ekowork publishes
 * no changelog in that shape, and there is nothing to substitute: GitHub's
 * releases page is HTML and its API returns a different schema, so either
 * would fetch, fail to parse and throw away the response every launch.
 *
 * undefined turns the feature off honestly instead. highlights.tsx skips the
 * fetch entirely when this is unset. Set it to a URL when Ekowork actually
 * serves a changelog.json and the dialog comes back on its own.
 */
export const CHANGELOG_URL: string | undefined = undefined

/**
 * Links left pointing at opencode, on purpose.
 *
 * These describe how the product works, and opencode's pages are accurate for
 * it -- Ekowork is a fork, not a rewrite. They are gathered here so the choice
 * is visible in one place rather than looking like 4 sites nobody got round to.
 *
 * Replace a value the day Ekowork hosts the equivalent page. Until then the
 * link that works beats the link that is on-brand.
 */
export const UPSTREAM = {
  docs: "https://opencode.ai/docs",
  docsThemes: "https://opencode.ai/docs/themes/",
  docsCustomProvider: "https://opencode.ai/docs/providers/#custom-provider",
  /**
   * Not a docs page -- Zen is opencode's hosted model service. A user
   * connecting to Zen is genuinely going to opencode. Repointing this would
   * break the feature, not rebrand it.
   */
  zen: "https://opencode.ai/zen",
  /**
   * opencode's Discord. Ekowork has no community of its own, and the people
   * there can answer questions about this codebase because it is the same
   * codebase. An empty Ekowork server would be a worse answer than an honest
   * upstream one.
   */
  supportForum: "https://discord.com/invite/opencode",
} as const

/**
 * Left pointing at opencode on purpose, and not routed through this module
 * because none of them is a destination a user is sent to. Listed so a reader
 * greping for "opencode" finds the reasoning instead of re-deriving it:
 *
 *   packages/app/package.json:75 -- the ghostty-web dependency really is
 *   anomalyco's package. It is a dependency, not a link.
 *
 *   packages/app/src/entry.tsx:104 -- `location.hostname.includes("opencode.ai")`
 *   picks a dev backend when the app is served from opencode's own domain.
 *   Ekowork is never served from there, so the branch is unreachable rather
 *   than wrong. Deleting it is an upstream-merge conflict for no gain.
 *
 *   packages/app/src/pages/layout/helpers.ts:99 -- OPENCODE_PROJECT_ID is the
 *   hash of opencode's own worktree. Opening the opencode repo as a project
 *   shows opencode's favicon as that project's avatar. That is correct: it is
 *   about the project being opened, not about who ships this app.
 *
 * Also deliberately untouched, in packages/desktop/electron-builder.config.ts:
 * `schemes: ["opencode"]` and `rpm.packageName`. Both are install-time
 * identities with live upgrade paths behind them -- the legacyDesktopEntry
 * machinery in that file exists to protect exactly those. Renaming a URL
 * scheme also means finding every producer of an opencode:// link, including
 * the MCP OAuth callback in packages/opencode. That is a migration, not a
 * repoint, and half of it would be worse than none.
 */
