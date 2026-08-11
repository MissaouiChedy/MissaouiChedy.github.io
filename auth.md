# auth.md

You are an agent. **Tech Dominator** (`https://blog.techdominator.com`) is a
public, read-only technical blog. Discover the published metadata, then read the
public resources directly. Do not attempt agentic registration, claim ceremony,
token exchange, or revocation; this site does not require or issue credentials.

## Step 1 - Discover

Start with the protected resource metadata:

```http
GET https://blog.techdominator.com/.well-known/oauth-protected-resource
```

Expected shape:

```json
{
	"resource": "https://blog.techdominator.com",
	"authorization_servers": [],
	"scopes_supported": [],
	"bearer_methods_supported": []
}
```

The empty `authorization_servers`, `scopes_supported`, and
`bearer_methods_supported` arrays mean there is no OAuth authorization server,
no access-token scope set, and no bearer-token presentation method required for
published content.

For content discovery, fetch the API catalog:

```http
GET https://blog.techdominator.com/.well-known/api-catalog
```

The catalog links to machine-readable resources such as `posts.json`,
`sitemap.xml`, `feed.xml`, the MCP server card, and this document.

Additional discovery documents are available at:

| Document | Location |
|----------|----------|
| OAuth 2.0 Protected Resource Metadata (RFC 9728) | `/.well-known/oauth-protected-resource` |
| OAuth 2.0 Authorization Server Metadata (RFC 8414) | `/.well-known/oauth-authorization-server` |
| API Catalog (RFC 9727) | `/.well-known/api-catalog` |
| MCP Server Card (SEP-1649) | `/.well-known/mcp/server-card.json` |
| Agent Skills index | `/.well-known/agent-skills/index.json` |

## Step 2 - Pick a Method

Use public read access. This site does not support the auth.md registration
methods `identity_assertion`, `service_auth`, or `anonymous`, because there are
no protected read APIs and no write APIs exposed to agents.

If your task requires private data, account access, mutation, publishing, or any
operation beyond reading the published site content, stop. There is no supported
agent authorization path for that operation.

## Step 3 - Register

No registration is required or available.

Do not call `POST /agent/identity`; this site does not expose that endpoint. No
OAuth client, client secret, claim token, identity assertion, access token, or
refresh token is issued for public read access.

Agents may identify themselves with a standard `User-Agent` header when making
HTTP requests.

## Step 4 - Claim Ceremony

No claim ceremony is required or available.

Do not ask the user to visit a verification URL or enter a user code for this
site. Tech Dominator does not bind agent registrations to user accounts.

## Step 5 - Exchange Credentials

No token exchange is required or available.

Do not call `POST /oauth2/token`; this site does not issue bearer tokens for
public content.

## Step 6 - Use the Public Resources

Fetch public resources directly over HTTPS. Examples:

```http
GET https://blog.techdominator.com/posts.json
GET https://blog.techdominator.com/sitemap.xml
GET https://blog.techdominator.com/feed.xml
GET https://blog.techdominator.com/posts.html
```

No `Authorization` header is required.

## Errors

If a public resource returns `404`, the resource does not exist at that path. Use
the API catalog, sitemap, feed, or site navigation to find an available URL.

If a request is rate-limited or returns a transient `5xx` response, back off and
retry later. Do not retry aggressively.

If a request appears to require authentication, treat it as unsupported for
agents unless this document and the discovery metadata are updated with an
authorization path.

## Revocation

Revocation is not applicable. This site does not issue access tokens,
refresh tokens, client credentials, claim tokens, or identity assertions for
public read access.

## Contact

For questions about agent access, see the
[about page](https://blog.techdominator.com/about-chedy-missaoui.html).
