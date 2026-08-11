# Skill: Tech Dominator Blog Content

**name**: tech-dominator-blog-content
**type**: content-retrieval
**description**: How an AI agent discovers and retrieves markdown content from the Tech Dominator blog.
**url**: https://blog.techdominator.com/.well-known/agent-skills/blog-content-skill.md

## What this skill provides

Read access to the Tech Dominator technical blog (posts about Azure and
Microsoft technologies), exposed in an agent-friendly way.

## How to use it

1. Fetch the sitemap at `https://blog.techdominator.com/sitemap.xml` to list
   every published URL, or browse `https://blog.techdominator.com/posts.html`.
2. For any HTML page or post, request its markdown representation by either:
   - replacing the `.html` extension with `.md`, or
   - following the page's `<link rel="alternate" type="text/markdown">` tag.
3. The markdown response carries the post title and body content for easy
   consumption.

## Related resources

- API Catalog: `https://blog.techdominator.com/.well-known/api-catalog`
- Atom feed: `https://blog.techdominator.com/feed.xml`
- Authentication & registration: `https://blog.techdominator.com/auth.md`
