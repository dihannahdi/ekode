import { resolveChannel } from "./utils"
import { ISSUES_URL, REPO_URL } from "../src/product"

const arg = process.argv[2]
const channel = arg === "dev" || arg === "beta" || arg === "prod" ? arg : resolveChannel()

const appId = channel === "prod" ? "ai.opencode.desktop" : `ai.opencode.desktop.${channel}`
const productName = channel === "prod" ? "Ekowork" : `Ekowork ${channel.charAt(0).toUpperCase() + channel.slice(1)}`
const summary = `Open source AI coding agent${channel !== "prod" ? ` (${channel})` : ""}`

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>${appId}</id>

  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>

  <name>${productName}</name>
  <summary>${summary}</summary>

  <developer id="ly.anoma">
    <name>Anomaly Innovations Inc.</name>
  </developer>

  <description>
    <p>
      Ekowork is an open source agent that helps you write and run code with any AI model.
    </p>
  </description>

  <launchable type="desktop-id">${appId}.desktop</launchable>

  <content_rating type="oars-1.1" />

  <url type="bugtracker">${ISSUES_URL}</url>
  <url type="homepage">${REPO_URL}</url>
  <url type="vcs-browser">${REPO_URL}</url>

  <!--
    No <screenshots> block. The one here showed opencode's lander image,
    pinned to an upstream commit, on a listing titled "Ekowork" -- a store
    page presenting another product's screenshot as this one. AppStream
    treats screenshots as optional, so omitting it costs a nicer listing and
    keeps the listing truthful. Add one showing Ekowork when there is one.
  -->
</component>
`

await Bun.write(`resources/${appId}.metainfo.xml`, xml)
console.log(`Generated metainfo for ${channel} at resources/${appId}.metainfo.xml`)
