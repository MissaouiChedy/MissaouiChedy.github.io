# Agent Authentication & Registration

This document describes how AI agents authenticate with, and register against,
the resources published by **Tech Dominator** (`https://blog.techdominator.com`).

## Overview

Tech Dominator is a public, read-only technical blog. The content (posts, tags,
slides, feeds and sitemap) is publicly accessible over HTTPS and **does not
require authentication** for read access.

No protected write APIs are exposed at this time, so no credentials are needed
to consume the published content.

## Discovery Metadata

The following discovery documents are published so agents can programmatically
understand how to interact with this site:

| Document | Location |
|----------|----------|
| OAuth 2.0 Authorization Server Metadata (RFC 8414) | `/.well-known/oauth-authorization-server` |
| OAuth 2.0 Protected Resource Metadata (RFC 9728) | `/.well-known/oauth-protected-resource` |
| API Catalog (RFC 9727) | `/.well-known/api-catalog` |
| MCP Server Card (SEP-1649) | `/.well-known/mcp/server-card.json` |
| Agent Skills index | `/.well-known/agent-skills/index.json` |

## Registration

Tech Dominator does not issue tokens or require OAuth registration for read access. Agents may optionally identify themselves via standard `User-Agent` headers.

If metadata tracking is used, the `agent_auth` block in `/.well-known/oauth-authorization-server` provides information:

- **Registration document (`register_uri`)**: `https://blog.techdominator.com/auth.md`.
- **Supported identity types**: `agent`.
- **Supported credential types**: `public` (no secret or token required).

## Claims & Scopes

No OAuth scopes or access claims are enforced. All public content is accessible freely without authorization claims or access tokens.

## Revocation

Because no credentials or access tokens are issued or required, credential revocation is not applicable.

## Contact

For questions about agent access, see the
[about page](https://blog.techdominator.com/about-chedy-missaoui.html).
