/**
 * Every destination the Ekowork desktop app can send a user or a build to.
 *
 * Companion to packages/app/src/product.ts, which does the same job for the
 * web UI. Two files rather than one shared module on purpose: app and desktop
 * are separate module graphs, and this file is also read by
 * electron-builder.config.ts and scripts/copy-metainfo.ts, which load outside
 * the renderer bundle. A leaf file with no imports resolves in all of them.
 * Duplicating four constants beats a cross-package import that has to hold in
 * three different loaders.
 *
 * Same rule as the app module: a value lives here when it is about *who ships
 * this*. Anything about how the product works, where opencode's answer is the
 * accurate one, stays pointing upstream and says so.
 */

/**
 * The repository Ekowork's releases live in.
 *
 * Must stay equal to REPO in packages/app/src/product.ts and RELEASES_REPO in
 * packages/opencode/src/installation/index.ts. Three constants for one product
 * is not the shape anyone wants; they sit in three module graphs that cannot
 * import each other, so the coupling is stated rather than enforced. If a
 * fourth appears, that is the signal to make a real shared package.
 */
export const REPO_OWNER = "jaycoolslm"
export const REPO_NAME = "ekode"

export const REPO_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}`

export const ISSUES_URL = `${REPO_URL}/issues`

/**
 * The legal entity Ekowork is published under, as decided for code signing.
 *
 * Must stay equal to AppPublisher in packages/opencode/installer/ekode.iss,
 * so the Windows installer wizard, Add/Remove Programs, the Linux store
 * listing and the eventual certificate all say one thing.
 *
 * This replaced "Anomaly Innovations Inc." in the AppStream metainfo -- not a
 * link but a company attribution, telling anyone reading the store page that
 * opencode's company develops Ekowork. Found by running
 * scripts/copy-metainfo.ts and reading the XML, not by greping for URLs.
 */
export const PUBLISHER = "Eko AI"

/**
 * Where electron-builder publishes, and therefore where the shipped app looks
 * for its own updates.
 *
 * This was { owner: "anomalyco", repo: "opencode" }. A packaged Ekowork
 * checked opencode's releases and would have offered to update itself into a
 * different product -- the same defect 2296dd3 fixed on the CLI side, which
 * only touched packages/opencode and left this untouched.
 *
 * Beta points at the same repository rather than an "-beta" sibling. Upstream
 * splits prereleases into anomalyco/opencode-beta; ekode has one repo and
 * marks hyphenated tags as prereleases inside it -- see the release job in
 * .github/workflows/windows-installer.yml. One repo is the existing convention
 * here, so this follows it instead of inventing a repo that does not exist.
 */
export const PUBLISH_REPO = { owner: REPO_OWNER, repo: REPO_NAME } as const
export const PUBLISH_REPO_BETA = { owner: REPO_OWNER, repo: REPO_NAME } as const

/**
 * Served by the renderer itself out of packages/app/public. Was an absolute
 * https://opencode.ai/... URL, so every notification fetched its icon from a
 * host Ekowork does not control. The artwork is still opencode's -- the
 * rebrand renamed surfaces but never replaced the icon files.
 */
export const NOTIFICATION_ICON = "/favicon-96x96-v3.png"

/**
 * The one place Ekowork still installs opencode, and it is not fixed.
 *
 * The desktop app needs a Linux backend binary inside WSL, and installs it by
 * piping opencode's install script to bash. ekode has no Linux release channel
 * at all -- .github/workflows/windows-installer.yml builds windows-x64 only,
 * and 2296dd3 already recorded that ekode publishes to no package manager. So
 * there is nothing to repoint this at. Leaving it aimed upstream is the only
 * option that installs a working backend today.
 *
 * The part that will break, stated plainly so it is found before a user finds
 * it: servers.ts:345 passes the *desktop app's own version* to this script,
 * and servers.ts:350 then asserts the installed backend reports that same
 * version back. That holds today only because packages/desktop/package.json is
 * still 1.17.10, which is a real opencode release. The Windows installer
 * already tags v0.0.1-rc6. The first time the desktop version moves to an
 * ekode number, this script 404s on a version opencode never published and the
 * user sees "Ekowork installation failed" with no hint why.
 *
 * Fixing it needs a Linux ekode build published to REPO_URL/releases and this
 * constant repointed at an ekode install script. That is a distribution
 * change, not a rename, so it is deliberately out of scope here.
 */
export const WSL_BACKEND_INSTALL_URL = "https://opencode.ai/install"
