# Generates a root .htaccess advertising agent-discovery resources via
# Link response headers (RFC 8288). GitHub Pages cannot set custom headers,
# so this takes effect when the site is served by an Apache-compatible host.
Jekyll::Hooks.register :site, :post_write do |site|
  base = site.config["url"].to_s
  links = [
    %(<#{base}/.well-known/api-catalog>; rel=\\"api-catalog\\"; type=\\"application/linkset+json\\"),
    %(<#{base}/posts.html>; rel=\\"service-doc\\"; type=\\"text/html\\"),
    %(<#{base}/.well-known/agent-skills/index.json>; rel=\\"agent-skills\\"; type=\\"application/json\\"),
  ]

  lines = [
    "# Link response headers for AI agent discovery (RFC 8288)",
    "<IfModule mod_headers.c>",
  ]
  lines += links.map { |l| %(  Header always set Link "#{l}") }
  lines << "</IfModule>"
  lines << ""

  File.write(File.join(site.dest, ".htaccess"), lines.join("\n"))
end
