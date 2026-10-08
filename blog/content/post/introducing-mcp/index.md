---
title: 'Introducing osctrl-mcp'
description: '`osctrl`: A fast and efficient osquery management solution.'
summary: "The `osctrl-mcp` component extends osctrl's capabilities by exposing its read surface over the Model Context Protocol (MCP), enabling AI clients such as Claude Code or ChatGPT to inspect nodes, the osquery schema, and distributed query results through a permission-checked interface — read-only by default, with write tools gated behind an explicit switch." # For the post in lists.
date: '2026-10-08'
aliases:
  - introducing-osctrl-mcp
author: "Javier 🔐"

featureImage: 'osctrl-mcp.png' # Top image on post.
# featureImageAlt: 'Description of image' # Alternative text for featured image.
# featureImageCap: 'This is the featured image.' # Caption (optional).
# thumbnail: 'thumbnail.jpg' # Image in lists of posts.
# shareImage: 'share.jpg' # For SEO and social media snippets.

categories:
  - Projects
  - Security
tags:
  - osquery
  - osctrl
  - security
  - open source
  - ai
  - mcp
  - api
# the following overrides the settings from params.toml:
showRelatedInArticle: true
showRelatedInSidebar: true
---

When [osctrl](https://osctrl.net) was originally [introduced](https://blog.jmpsec.com/post/introducing-osctrl/), it was a performant TLS endpoint for [osquery](https://osquery.io). Later, the [`osctrl-api`](https://blog.jmpsec.com/post/introducing-api/) opened the same fleet to external tools, letting engineering teams build on top of it instead of around it.

**osctrl-mcp** is the continuation of that idea. It exposes osctrl over the [Model Context Protocol](https://modelcontextprotocol.io) (MCP) — the open standard that connects AI clients such as Claude Code, Claude Desktop, or many IDE assistants to external data sources and tools. With it, an operator can sit in any of those clients and inspect their fleet directly: environments, enrolled nodes, the osquery schema, and distributed query results — with every request authenticated and permission-checked, exactly as it would be through the web UI or the API.

### Two ways to connect

Both modes serve the same tools, so pick per deployment model:

| Mode | Transport | Suits |
|---|---|---|
| `osctrl-mcp` | stdio, launched by the client | One operator on a workstation |
| Hosted at `/api/v1/mcp` | HTTP, inside `osctrl-api` | A shared deployment where every user connects as themselves |

The standalone binary is deliberately boring infrastructure: it opens no listening socket, holds no state, and turns every tool call into an authenticated request against `osctrl-api`. The hosted endpoint, off by default in `osctrl-api` configuration, instead lets each operator point their client at the same URL with their own token.

### What the agent can actually do

Nine read tools are always available — nothing here mutates anything:

- `list_environments` — environments the token can see (enrollment secrets and certificates deliberately excluded)
- `fleet_stats` — totals, active vs. inactive, per-platform and per-environment breakdowns
- `search_nodes` / `get_node` — find nodes by status, platform, or hostname; get full detail, optionally with posture score
- `list_osquery_tables` / `get_table_schema` — the queryable osquery schema, used for query authoring
- `list_queries` / `list_saved_queries` / `get_query_results` — distributed queries, templates, and rows collected so far

That is enough to ask the questions that used to require opening the UI: *which macOS nodes in prod haven't checked in this week?*, *what columns does the `shell_history` table expose?*, *how many nodes have answered the query we launched yesterday?*

Four write tools exist — `run_query`, `expire_query`, `complete_query`, `tag_node` — but they are registered **only** when writes are explicitly enabled. A read-only server does not advertise them, so no misconfiguration quietly hands an agent the fleet.

### The design decisions, because this is security tooling

**The MCP layer contains no authorization logic of its own.** Every tool call is dispatched back through `osctrl-api`'s own handlers as the calling user, so the same per-endpoint permission checks that guard the web UI run for the agent too. Restating read policy inside an MCP layer would over-grant the moment the two implementations drifted apart — osctrl's read permissions are not uniform (node posture needs `AdminLevel`, queries need `QueryLevel`, the schema needs nothing), so the layer defers entirely to the handlers.

**The token is the boundary.** Deploy it with a dedicated, narrowly scoped service user rather than a human's token:

```bash
osctrl-cli user add -u mcp-agent -s -e prod
osctrl-cli user permissions -u mcp-agent -e prod --user
```

A token that cannot see an environment gets the same empty results the operator would. In hosted mode, two users hitting the same tool get different results, and every tool call lands in the audit log — including reads.

**`run_query` assumes the agent will make mistakes.** A target is mandatory, because osctrl reads "no selectors" as the whole environment. Every query expires (default 24h, max 168h), because an unexpired query keeps landing on nodes that enroll months later. Carve queries are refused outright — copying files off endpoints is a capability this server does not offer. And everything an agent schedules is visible in the UI, so an operator can see what it started.

**Fleet data is untrusted, and the server says so.** Hostnames, process names, and result rows come from the monitored endpoints — precisely the machines an attacker might control — and that text lands in the model's context. Tool descriptions and server instructions state that this content is data, never instructions. With writes off, the worst a malicious hostname produces is a misleading answer; with writes on, that loop closes. Turning writes on is meant for trusted operators and scoped tokens, not unattended automation.

### Getting started

Standalone `osctrl-mcp` binaries ship for Linux, macOS and Windows on both amd64 and arm64 alongside [v0.5.9](https://github.com/jmpsec/osctrl/releases/tag/v0.5.9). Point it at your deployment:

```bash
claude mcp add osctrl \
  --env OSCTRL_API_URL=https://osctrl.example.com \
  --env OSCTRL_API_TOKEN=<service-user-token> \
  -- /opt/osctrl/bin/osctrl-mcp
```

Claude Desktop (in `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "osctrl": {
      "command": "/opt/osctrl/bin/osctrl-mcp",
      "env": {
        "OSCTRL_API_URL": "https://osctrl.example.com",
        "OSCTRL_API_TOKEN": "<service-user-token>"
      }
    }
  }
}
```

The complete tool list, authentication model, and hosted-endpoint setup are documented in [MCP.md](https://github.com/jmpsec/osctrl/blob/main/MCP.md). It builds with `make mcp` if you prefer source.

As with `osctrl-api`, the goal is to enable integrations beyond what the project originally scoped — the difference is that this time the integration writes itself the SQL. Feedback is welcome, whether here, in the [issue tracker](https://github.com/jmpsec/osctrl/issues), or in the *#osctrl* channel in the official [osquery Slack community](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA) ([request an auto-invite!](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA)).
