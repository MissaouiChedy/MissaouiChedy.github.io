# Skill: Tech Dominator Blog Content

**name**: tech-dominator-blog-content
**type**: content-retrieval
**description**: How an AI agent discovers and retrieves content from the Tech Dominator blog.
**url**: https://blog.techdominator.com/.well-known/agent-skills/blog-content-skill.md

## What this skill provides

Read access to the Tech Dominator technical blog (posts about Azure and
Microsoft technologies).

## How to use it

1. Query post metadata (titles, URLs, publication dates, tags, and summaries) by fetching `https://blog.techdominator.com/posts.json` or reading the sitemap at `https://blog.techdominator.com/sitemap.xml`.
2. Fetch individual HTML pages/posts, interact via WebMCP tools (`search_posts`, `list_posts`, `get_post`), or subscribe to the Atom feed at `https://blog.techdominator.com/feed.xml`.

## Markdown versions

Every HTML page has a Markdown twin served with `Content-Type: text/markdown`:
replace the `.html` extension with `.md` in any page URL (for example,
`https://blog.techdominator.com/article/load-testing-event-hubs-processing-with-locust.md`
or `https://blog.techdominator.com/about-chedy-missaoui.md`). Prefer the `.md`
version when consuming article content as an agent; the sitemap lists both
variants of every page.

## Related resources

- JSON Posts Index: `https://blog.techdominator.com/posts.json`
- MCP Server Card: `https://blog.techdominator.com/.well-known/mcp/server-card.json`
- API Catalog: `https://blog.techdominator.com/.well-known/api-catalog`
- Atom feed: `https://blog.techdominator.com/feed.xml`
- Authentication & registration: `https://blog.techdominator.com/auth.md`
