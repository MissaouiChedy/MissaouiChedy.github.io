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

	var tools = [
		{
			name: "list_posts",
			description: "List the published Tech Dominator blog post URLs.",
			inputSchema: {
				type: "object",
				properties: {},
				additionalProperties: false
			},
			execute: function () {
				return fetchText(BASE_URL + "/sitemap.xml").then(function (xml) {
					var urls = xml.match(/<loc>[^<]+<\/loc>/g) || [];
					var matches = urls.map(function (entry) { return entry.replace(/<\/?loc>/g, ""); });
					return { content: [{ type: "text", text: matches.join("\n") }] };
				});
			}
		},
		{
			name: "search_posts",
			description: "Find Tech Dominator blog posts matching a keyword by searching the sitemap of published URLs.",
			inputSchema: {
				type: "object",
				properties: {
					query: {
						type: "string",
						description: "Keyword to match against post URLs (case-insensitive)."
					}
				},
				required: ["query"],
				additionalProperties: false
			},
			execute: function (args) {
				var query = (args && args.query ? String(args.query) : "").toLowerCase();
				return fetchText(BASE_URL + "/sitemap.xml").then(function (xml) {
					var urls = xml.match(/<loc>[^<]+<\/loc>/g) || [];
					var matches = urls
						.map(function (entry) { return entry.replace(/<\/?loc>/g, ""); })
						.filter(function (u) { return query === "" || u.toLowerCase().indexOf(query) !== -1; });
					return { content: [{ type: "text", text: matches.join("\n") || "No posts matched the query." }] };
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
