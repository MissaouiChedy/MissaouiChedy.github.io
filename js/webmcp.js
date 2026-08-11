/*
 * Exposes the site's key actions to AI agents via the WebMCP API
 * (navigator.modelContext.provideContext). Guarded so it is a no-op in
 * browsers that do not implement the WebMCP API.
 */
(function () {
	"use strict";

	if (!("modelContext" in navigator) || typeof navigator.modelContext.provideContext !== "function") {
		return;
	}

	var BASE_URL = window.location.origin;

	function fetchJson(url) {
		return fetch(url, { headers: { "Accept": "application/json" } }).then(function (response) {
			if (!response.ok) {
				throw new Error("Request failed with status " + response.status);
			}
			return response.json();
		});
	}

	function fetchText(url) {
		return fetch(url).then(function (response) {
			if (!response.ok) {
				throw new Error("Request failed with status " + response.status);
			}
			return response.text();
		});
	}

	function getPostsIndex() {
		return fetchJson(BASE_URL + "/posts.json").catch(function () {
			// Fallback to parsing sitemap.xml if posts.json is unavailable
			return fetchText(BASE_URL + "/sitemap.xml").then(function (xml) {
				var urls = [];
				if (typeof DOMParser !== "undefined") {
					var parser = new DOMParser();
					var doc = parser.parseFromString(xml, "text/xml");
					var locs = doc.querySelectorAll("loc");
					for (var i = 0; i < locs.length; i++) {
						if (locs[i].textContent) {
							urls.push(locs[i].textContent.trim());
						}
					}
				} else {
					var matches = xml.match(/<loc>[^<]+<\/loc>/g) || [];
					urls = matches.map(function (entry) { return entry.replace(/<\/?loc>/g, ""); });
				}
				return urls.map(function (u) {
					return {
						title: u.replace(/\/$/, "").split("/").pop().replace(/-/g, " "),
						url: u,
						date: "",
						tags: [],
						summary: ""
					};
				});
			});
		});
	}

	function extractArticleText(htmlString) {
		if (typeof DOMParser !== "undefined") {
			var parser = new DOMParser();
			var doc = parser.parseFromString(htmlString, "text/html");
			var article = doc.querySelector("[itemprop='articleBody']") ||
				doc.querySelector("article") ||
				doc.querySelector("main") ||
				doc.body;

			if (article) {
				var noise = article.querySelectorAll("script, style, nav, footer, header, .sponsor-banner, #disqus_thread");
				for (var i = 0; i < noise.length; i++) {
					if (noise[i].parentNode) {
						noise[i].parentNode.removeChild(noise[i]);
					}
				}
				var text = article.textContent || article.innerText || "";
				return text.replace(/\n\s*\n/g, "\n\n").trim();
			}
		}

		return htmlString.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
			.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, "")
			.replace(/<[^>]+>/g, " ")
			.replace(/\s+/g, " ")
			.trim();
	}

	var tools = [
		{
			name: "list_posts",
			description: "List published Tech Dominator blog posts with their titles, URLs, dates, and tags.",
			inputSchema: {
				type: "object",
				properties: {},
				additionalProperties: false
			},
			execute: function () {
				return getPostsIndex().then(function (posts) {
					if (!posts || posts.length === 0) {
						return { content: [{ type: "text", text: "No blog posts found." }] };
					}
					var lines = posts.map(function (p) {
						var tagsStr = (p.tags && p.tags.length > 0) ? " [Tags: " + p.tags.join(", ") + "]" : "";
						var dateStr = p.date ? " (" + p.date + ")" : "";
						return "- " + p.title + dateStr + tagsStr + "\n  URL: " + p.url;
					});
					return { content: [{ type: "text", text: lines.join("\n\n") }] };
				});
			}
		},
		{
			name: "search_posts",
			description: "Find Tech Dominator blog posts matching a keyword by searching titles, tags, summaries, or URLs.",
			inputSchema: {
				type: "object",
				properties: {
					query: {
						type: "string",
						description: "Keyword to match against post titles, tags, summaries, and URLs (case-insensitive)."
					}
				},
				required: ["query"],
				additionalProperties: false
			},
			execute: function (args) {
				var query = (args && args.query ? String(args.query) : "").toLowerCase();
				return getPostsIndex().then(function (posts) {
					var matches = posts.filter(function (p) {
						if (!query) return true;
						var titleMatch = p.title && p.title.toLowerCase().indexOf(query) !== -1;
						var urlMatch = p.url && p.url.toLowerCase().indexOf(query) !== -1;
						var summaryMatch = p.summary && p.summary.toLowerCase().indexOf(query) !== -1;
						var tagMatch = Array.isArray(p.tags) && p.tags.some(function (t) {
							return String(t).toLowerCase().indexOf(query) !== -1;
						});
						return titleMatch || urlMatch || summaryMatch || tagMatch;
					});

					if (matches.length === 0) {
						return { content: [{ type: "text", text: "No posts matched the query: " + query }] };
					}

					var formatted = matches.map(function (p) {
						var tagsStr = (p.tags && p.tags.length > 0) ? "\n  Tags: " + p.tags.join(", ") : "";
						var summaryStr = p.summary ? "\n  Summary: " + p.summary : "";
						var dateStr = p.date ? " (" + p.date + ")" : "";
						return "- " + p.title + dateStr + "\n  URL: " + p.url + tagsStr + summaryStr;
					});

					return { content: [{ type: "text", text: formatted.join("\n\n") }] };
				});
			}
		},
		{
			name: "get_post",
			description: "Retrieve the text content of a single Tech Dominator blog post by its URL.",
			inputSchema: {
				type: "object",
				properties: {
					url: {
						type: "string",
						description: "The full URL or relative path of the blog post to retrieve."
					}
				},
				required: ["url"],
				additionalProperties: false
			},
			execute: function (args) {
				var targetUrl = args && args.url ? String(args.url) : "";
				if (!targetUrl) {
					return Promise.resolve({ content: [{ type: "text", text: "Error: URL parameter is required." }] });
				}

				if (targetUrl.indexOf("http") !== 0) {
					targetUrl = BASE_URL + (targetUrl.indexOf("/") === 0 ? "" : "/") + targetUrl;
				}

				return fetchText(targetUrl).then(function (html) {
					var textContent = extractArticleText(html);
					return { content: [{ type: "text", text: textContent || "Could not extract content from post." }] };
				}).catch(function (err) {
					return { content: [{ type: "text", text: "Failed to fetch post: " + err.message }] };
				});
			}
		}
	];

	try {
		navigator.modelContext.provideContext({ tools: tools });
	} catch (error) {
		/* WebMCP unsupported or registration failed; ignore silently. */
	}
})();
