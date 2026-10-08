---
title: 'Retiring osctrl-admin: A New Frontend for osctrl'
description: '`osctrl`: A fast and efficient osquery management solution.'
summary: "The new osctrl frontend is a single-page application in React that communicates exclusively with `osctrl-api`. With it in place, `osctrl-admin` — the original web UI since 2019 — has been deprecated and completely removed, collapsing the operator experience into a single, hardened API surface." # For the post in lists.
date: '2026-08-19'
aliases:
  - deprecating-osctrl-admin
author: "Javier 🔐"

featureImage: 'header.jpg' # Top image on post.
featureImageAlt: 'A modern mint-glass dashboard connected to an API core bearing the osctrl logo, with the retired console set aside.'
# featureImageCap: 'This is the featured image.' # Caption (optional).
thumbnail: 'thumbnail.jpg' # Image in lists of posts.
shareImage: 'share.jpg' # For SEO and social media snippets.

categories:
  - Projects
  - Security
tags:
  - osquery
  - osctrl
  - security
  - open source
  - api
  - react
  - frontend
# the following overrides the settings from params.toml:
showRelatedInArticle: true
showRelatedInSidebar: true
---

When [osctrl](https://osctrl.net) was originally [introduced](/post/introducing-osctrl/) back in 2019, the operator experience shipped as `osctrl-admin`: a Go service that rendered HTML templates on the server, spiced up with a generous dose of jQuery, DataTables and AJAX calls. It served the project well for years — but as the feature set grew, so did the cost of maintaining it.

Today, `osctrl-admin` is officially deprecated and has been **completely removed** from the project. Its replacement is a single-page application in [React](https://react.dev) that lives under `frontend/` and communicates exclusively with [`osctrl-api`](/post/introducing-api/). No separate frontend Go service, no server-side templates — just a modern UI consuming the same API that every other osctrl client already uses.

## Why deprecate osctrl-admin?

In its final form, osctrl offered two parallel implementations of the same logic: `osctrl-admin` and `osctrl-api` both read from and wrote to the backend, both handled authentication, and both had permission checks to maintain. That meant every new feature had to be built twice, in two different styles, in two services — and every discrepancy between them was a subtle bug waiting to happen. Meanwhile, the template-based UI made it increasingly difficult to build the kind of interactive experiences the project needed, such as the read-only node console or the per-node file explorer.

Collapsing everything onto `osctrl-api` addresses all of that:

* **One implementation of the business logic.** The web UI is now just another API consumer, standing next to `osctrl-cli` and your own automations. Where the UI and the API used to drift apart, there is now a single source of truth.

* **One authenticated surface to harden.** `osctrl-api` ships with JWT authentication by default, CSRF handling for cookie-authenticated mutations, optional multi-factor authentication (TOTP, passkeys and security keys, recovery codes), trusted proxy controls and audit logging — including reads.

* **A UI that can finally keep up.** The API-driven design is what made the node console, the file explorer, accelerated distributed queries and the alerting system possible as interactive experiences rather than page reloads.

There is a security principle worth restating here, because it guided the design: **the permission checks in the frontend are navigation aids, not security controls.** Every protected operation must remain authenticated and authorized in `osctrl-api`, regardless of what the browser is willing to show. That has always been the project's posture, and removing `osctrl-admin` only reinforces it — there is no longer a second handler surface that could fall out of sync with the API's authorization model.

## The new frontend

The operator interface is a React 19 single-page application, built with TypeScript and [Vite](https://vite.dev), running on Node.js 22+. The stack was chosen to stay boring where it matters and expressive where it counts: [Tailwind CSS 4](https://tailwindcss.com) for styling, [TanStack Router](https://tanstack.com/router), [Query](https://tanstack.com/query) and [Table](https://tanstack.com/table) for routing, data fetching and grid-heavy fleet views, [Zod](https://zod.dev) for schema validation, and the [Monaco Editor](https://microsoft.github.io/monaco-editor/) for SQL authoring.

The UI covers the full operator surface: environments, nodes, activity and posture, queries, saved queries, carves, the node console and file explorer, tags, enrollment packages, users and MFA, alerts, log sinks, authentication providers, audit records, settings, and service configuration. OIDC and SAML logins flow through `osctrl-api` as [federated auth providers](https://github.com/jmpsec/osctrl/blob/develop/docs/auth-providers.md), so SSO is no longer tied to the old admin service.

The frontend ships with its own test suite too — Vitest and Testing Library for components, and Playwright for the end-to-end operator workflows across navigation, authentication, and everyday tasks like running queries and creating users.

## How the transition happened

This was not a big-bang rewrite. The rollout deliberately overlapped the old and new UIs for several releases, so operators always had a working interface:

| Release | Milestone |
|---|---|
| `v0.5.2` | `osctrl-api` extensions for a React frontend land, and the SPA arrives under `frontend/`, alongside `osctrl-admin` |
| `v0.5.3` | OIDC and SAML support for `osctrl-api` + the SPA, with user management in parity with the legacy admin |
| `v0.5.4` – `v0.5.5` | Redesigned queries and carves views, node console, file explorer, activity and posture |
| `v0.5.6` | ⚠️ Complete removal of `osctrl-admin`, including the last settings and configuration references |
| `v0.5.8` | `osctrl-frontend` published as an official release Docker image |

By the time `osctrl-admin` disappeared, the SPA had already covered its functionality — the removal was a formality, not a cliff.

## Deployment and migration

For containerized deployments, the release pipeline builds a dedicated `osctrl-frontend` image: nginx serves the static SPA bundle and proxies `/api/*` to `osctrl-api` on port `9002`. The image listens on HTTP port 80 by default, meant to sit behind your TLS terminator; set `OSCTRL_FRONTEND_TLS=1` and mount certificates under `/etc/ssl/osctrl/` for its TLS configuration.

If you build from source, `make frontend-build` produces the static bundle in `frontend/dist/`, which you can serve with any web server in front of `osctrl-api` — the bundled nginx configurations live under `deploy/cicd/nginx/` as reference.

Upgrading from `v0.5.5` or earlier? A few things to keep in mind:

* **Remove the `osctrl-admin` service.** Stop the unit, remove it from your service manager, and drop its configuration section. The [provisioning script](https://docs.osctrl.net/deployment/natively/) already reflects the new layout.

* **Your agents are unaffected.** Enrollment, configuration distribution and log collection all go through `osctrl-tls`, which did not go anywhere. Osquery nodes will keep checking in while you migrate.

* **Everything else keeps working.** `osctrl-api` and `osctrl-cli` are unchanged in their roles — if you were automating against the API, nothing breaks.

## Getting started

The fastest way to see the new UI is the Docker development stack:

```bash
git clone https://github.com/jmpsec/osctrl.git
cd osctrl
cp .env.example .env
make docker_dev_certs
make docker_dev_build
make docker_dev_up
```

This boots nginx, the frontend, `osctrl-api`, `osctrl-tls`, PostgreSQL, Redis and a set of sample osquery clients. Open `https://localhost:8444` and explore.

If you want to work on the UI itself:

```bash
make frontend-install
make frontend-dev
```

Vite serves the SPA at `http://localhost:5173` and proxies `/api/*` to `osctrl-api` on `http://localhost:8081`. The same-origin proxy matters — it is how JWT and CSRF cookies stay sane in development.

## What's next?

The deprecation of `osctrl-admin` closes a long transition and opens a simpler chapter: one API surface, consumed by the UI, the CLI and your own tools — all of them held to the same authentication and authorization bar. With the operator experience now living on top of `osctrl-api`, new features land once and show up everywhere.

As always, feedback is welcome: open an [issue in GitHub](https://github.com/jmpsec/osctrl/issues), check the [documentation](https://docs.osctrl.net), or reach out in the *#osctrl* channel in the official [osquery Slack community](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA) ([request an auto-invite!](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA)).
