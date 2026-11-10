---
title: 'osctrl 0.6.3: A Santa Sync Server for Your macOS Fleet'
description: '`osctrl`: A fast and efficient osquery management solution.'
summary: "osctrl v0.6.3 can now act as a sync server for Santa, the binary authorization system for macOS. The same deployment that runs osquery on your Macs now manages allow and block rules, collects execution events and moves laptops from monitoring to lockdown, with no extra server to run." # For the post in lists.
date: '2026-11-10'
aliases:
  - introducing-santa-sync-server
author: "Javier 🔐"

# featureImage: 'header.jpg' # Top image on post.
# featureImageAlt: ''
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
  - macos
  - santa
# the following overrides the settings from params.toml:
showRelatedInArticle: true
showRelatedInSidebar: true
---

[osctrl](https://osctrl.net) [v0.6.3](https://github.com/jmpsec/osctrl/releases/tag/v0.6.3) is out, and its headline feature is for macOS fleets: osctrl can now act as a **sync server for [Santa](https://github.com/northpolesec/santa)**, the binary authorization system for macOS maintained by [North Pole Security](https://northpole.security). The Macs you already manage with osquery can now get their allow and block rules, report what they execute and switch between monitoring and enforcement, all from the same osctrl deployment.

## Why binary authorization on macOS

Most macOS laptops will run any binary the user downloads, as long as Gatekeeper and notarization let it through. That is a low bar. Signed and notarized malware exists, infostealers ship as convincing installers, and a developer laptop runs plenty of unsigned tools that nobody reviewed. Detection after the fact helps, but the stronger control is deciding up front what is allowed to run.

That is what Santa does. It uses Apple's Endpoint Security framework to evaluate every execution against a set of rules, and it runs in one of two modes:

* **MONITOR**: anything not explicitly blocked runs, and Santa logs what it would have blocked. This is how you learn what your fleet actually runs.

* **LOCKDOWN**: only explicitly allowed software runs. Everything else is blocked, and the user gets a notification explaining why.

Application allowlisting is not a new idea, and it shows up in every serious hardening guide. It is part of the [CIS Controls](https://www.cisecurity.org/controls) (Control 2, Inventory and Control of Software Assets), it is one of the [Essential Eight](https://www.cyber.gov.au/resources-business-and-government/essential-cyber-security/essential-eight) from the Australian Cyber Security Centre, and NIST covers it in [SP 800-167](https://csrc.nist.gov/pubs/sp/800/167/final). The hard part has never been the idea, it has been operating it: managing the rules, seeing what got blocked and rolling it out without breaking everybody's laptop.

## Why in osctrl

Santa clients are configured with a sync server, which is where the rules come from and where execution events go. Running one used to mean another service, another database and another inventory of machines to keep in sync with everything else.

osctrl already has most of that. Every Mac enrolled in osquery is a node in an environment, with tags, permissions and an audit log. With v0.6.3, Santa piggybacks on it:

* **No new server**: `osctrl-tls` serves the Santa sync protocol next to the osquery endpoints, and `osctrl-api` manages configuration, rules and events. They share the same database.

* **Same identity**: a Mac syncs Santa as the node it already is in osquery. Its hardware UUID is the machine ID, and it has to be enrolled in that same environment.

* **Same scoping**: rules use the environments, tags and nodes you already have, so a rule for the `engineering` tag works like any other tag-scoped setting in osctrl.

* **Same visibility**: osquery tells you what is installed and running on each Mac, and Santa tells you what tried to execute and what was blocked. Both now live in one place.

## How it works

### Rules

Rules can be scoped to the whole environment, a tag or a single node. For each rule type and identifier the most specific scope wins: node over tag over environment. This makes exceptions simple, a block at the environment level can be overridden with an allow on one node that legitimately needs the tool, without touching the rest of the fleet.

All the Santa rule types are supported: `BINARY`, `CERTIFICATE`, `CDHASH`, `TEAMID` and `SIGNINGID`, with `ALLOWLIST`, `ALLOWLIST_COMPILER`, `BLOCKLIST`, `SILENT_BLOCKLIST` and `CEL` policies.

Rule distribution uses a digest. At the start of each sync, osctrl computes the effective rules for that Mac and an order-independent SHA-256 digest of them. If the digest matches what the client last applied, nothing gets downloaded. If it differs, because a rule changed or the Mac was tagged differently, the client gets a clean sync with the full set. Changes made in the middle of a sync are picked up by the next one, rather than being recorded as applied.

### Events

Execution events uploaded by Santa clients show up in the **Events** tab of the new Santa page, and any of them can be turned into a rule with one click. Events are kept for 30 days.

### Client mode

The mode is set per environment from the UI. Every Mac in that environment gets MONITOR or LOCKDOWN on its next sync, so there is no need to push a new configuration profile to change it.

<!-- ![The Santa page in osctrl, with rules, events and machines](santa.png) -->

## Security of the sync server itself

A sync server decides what can run on every Mac in the fleet, so it is a target. The implementation is careful about it:

* **Per-environment token**: Santa sends a token in the `X-Osctrl-Santa-Token` header. osctrl only stores its SHA-256, compares it in constant time and shows the plaintext once, when it is generated. Rotating it invalidates the previous token immediately.

* **No existence oracle**: unknown environments, wrong tokens and machines that are not enrolled in that environment all get the same `403`.

* **Bounded requests**: JSON or protobuf bodies, optionally compressed, capped at 10 MiB raw and 20 MiB decompressed.

* **Audited**: every management action is written to the audit log, and failed authentications are logged too, with a cap so they cannot flood it.

* **Off by default**: like the console, the file explorer and vulnerability monitoring, nothing is migrated and no route exists unless you enable it.

There is one limit worth knowing. The token is shared by every Mac in the environment and hardware UUIDs are not secret, so a host holding the token could sync as another enrolled node in the same environment. Where that matters, require client mTLS at the reverse proxy in front of `osctrl-tls`, using Santa's `ClientAuthCertificate*` configuration keys.

## Rolling it out without breaking laptops

The quickest way to lose trust in binary authorization is to turn on LOCKDOWN on day one. The rollout that works looks like this:

1. **Enable the feature**: set `--santa-enabled` (or `SERVICE_SANTA_ENABLED`) on both `osctrl-tls` and `osctrl-api` and restart them.

2. **Prepare the environment**: open the environment's **Santa** page, go to **Settings**, set the mode to **MONITOR**, rotate the token and copy the `SyncBaseURL`.

3. **Deploy Santa through MDM**: install the [Santa package](https://github.com/northpolesec/santa/releases), the system extension and Full Disk Access profiles that pre-approve it, and a configuration profile pointing at osctrl:

```xml
<key>SyncBaseURL</key>
<string>https://osctrl.example.com/ENVIRONMENT-UUID/santa/sync/</string>
<key>SyncExtraHeaders</key>
<dict>
    <key>X-Osctrl-Santa-Token</key>
    <string>TOKEN-FROM-THE-UI</string>
</dict>
```

Leave `MachineIDKey` and `ClientMode` unset, so the machine ID is the hardware UUID and the mode comes from osctrl.

4. **Verify**: run `santactl sync` on a Mac, and it shows up under **Santa > Machines** with its last sync time. The `santa_agent` posture check reports whether the Santa system extension is active on each macOS node, so a Mac where Santa is missing or disabled shows up in the posture score instead of silently going unprotected.

5. **Learn in MONITOR mode**: review **Events** and allow legitimate software. Allowing by `TEAMID` covers a whole vendor with one rule, instead of one rule per binary hash every time the vendor ships an update.

6. **Handle exceptions with scope**: the developer who needs an unsigned tool gets a node-scoped rule, the team that needs a specific app gets a tag-scoped rule.

7. **Switch to LOCKDOWN**: when the events stop showing new legitimate binaries, flip the environment to LOCKDOWN. The mode applies to the whole environment, so a pilot group belongs in its own environment.

The complete guide, including the trust model and the MDM details, is in [pkg/santa/README.md](https://github.com/jmpsec/osctrl/blob/develop/pkg/santa/README.md).

## What makes a macOS laptop more secure

Binary authorization does not replace the other controls, it completes them. With v0.6.3, osctrl covers a good part of the picture for a Mac from one place:

* **Visibility**, with osquery: what is installed, running, listening and configured.

* **Exposure**, with [vulnerability monitoring](/post/vulnerability-monitoring/): which installed software has known vulnerabilities, starting with the known exploited ones.

* **Prevention**, with Santa: what is allowed to execute at all.

* **Evidence**, with posture checks and the audit log: whether every laptop actually has those controls running, and who changed what.

Malware that never runs cannot steal credentials, and a laptop in LOCKDOWN turns "the user downloaded something" from an incident into a blocked execution and a log entry.

## Also in this release

v0.6.3 is not only Santa. It also brings granular RBAC with global roles, query and carve tiers, sensitive nodes and sensitive carve paths, an optional database read replica for dashboards and node lists, frontend and API under a configurable URL prefix, a friendlier console with Tab completion and history, a set of hardening fixes from a security audit, and osquery 5.24.1. The full list is in the [release notes](https://github.com/jmpsec/osctrl/releases/tag/v0.6.3).

## Conclusion

Santa is one of the most effective controls you can deploy on macOS, and now it runs from the same place you already manage osquery. Enable it, start in MONITOR, learn what your fleet runs and move to LOCKDOWN when you are ready.

If you have any questions about the Santa sync server or [osctrl](https://osctrl.net) in general, feel free to create an [issue in GitHub](https://github.com/jmpsec/osctrl/issues), check the [documentation](https://docs.osctrl.net), or reach out in the *#osctrl* channel in the official [osquery Slack community](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA) ([request an auto-invite!](https://join.slack.com/t/osquery/shared_invite/zt-1wipcuc04-DBXmo51zYJKBu3_EP3xZPA)).
