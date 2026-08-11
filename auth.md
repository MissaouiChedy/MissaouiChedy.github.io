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

Agents that wish to identify themselves or register for future protected
resources should follow the `agent_auth` block in
`/.well-known/oauth-authorization-server`:

- **Registration endpoint (`register_uri`)**: this document (`/auth.md`).
- **Supported identity types**: `agent`.
- **Supported credential types**: `public` (no secret required for read access).

## Claims

Requested claims and profile information, where applicable, are described under
the `#claims` section referenced by the authorization-server metadata. For this
public blog, the only supported scope is `read`.

## Revocation

If credentials are ever issued for protected resources, revocation instructions
are published under the `#revocation` section referenced by the
authorization-server metadata.

## Contact

For questions about agent access, see the
[about page](https://blog.techdominator.com/about-chedy-missaoui.html).
