# Generates markdown representations of HTML pages and posts so AI agents can
# request a markdown version of a resource (e.g. via an `Accept: text/markdown`
# negotiation companion) while HTML stays the default for browsers.
#
# Runs after the site is written to disk (so the generated files are not removed
# by Jekyll's site cleanup) and writes a static `foo.md` next to every rendered
# `foo.html`, containing the page body converted back to markdown. Discovery is
# advertised with `<link rel="alternate" type="text/markdown">` tags.
require "set"

module Jekyll
  module MarkdownForAgents
    module_function

    def run(site)
      markdowner = site.converters.find { |c| c.is_a?(Jekyll::Converters::Markdown) }
      return unless markdowner

      emitted = Set.new

      site.posts.docs.each do |doc|
        html = read_destination(doc.destination(site.dest))
        emit(site, markdowner, emitted, doc.url, doc.data["title"], html)
      end

      site.pages.each do |page|
        html = read_destination(page.destination(site.dest))
        emit(site, markdowner, emitted, page.url, page.data["title"], html)
      end
    end

    def read_destination(path)
      File.read(path)
    rescue StandardError
      nil
    end

    def emit(site, markdowner, emitted, url, title, html)
      return if html.to_s.strip.empty?

      md_url = markdown_url_for(url)
      return if md_url.nil? || emitted.include?(md_url)
      emitted << md_url

      markdown = markdowner.convert(extract_body(html)).to_s.strip
      return if markdown.empty?

      markdown = "# #{title}\n\n#{markdown}" unless title.to_s.strip.empty?

      dest = File.join(site.dest, md_url.delete_prefix("/"))
      FileUtils.mkdir_p(File.dirname(dest))
      File.write(dest, "#{markdown}\n")
    end

    # Reduce a full HTML document to its meaningful content so the conversion to
    # markdown drops <head> markup, scripts and styles. Prefer the inner content
    # of <main>/<article> when present, falling back to <body>.
    def extract_body(html)
      doc = html.to_s
      body = doc[%r{<body[^>]*>(.*?)</body>}mi, 1] || doc
      main = body[%r{<(main|article)\b[^>]*>(.*?)</\1>}mi, 2] || body
      main = main.gsub(%r{<script\b[^>]*>.*?</script>}mi, "")
      main.gsub(%r{<style\b[^>]*>.*?</style>}mi, "")
    end

    def markdown_url_for(url)
      if url.end_with?(".html")
        url.sub(/\.html\z/, ".md")
      elsif url.end_with?("/")
        url == "/" ? "/index.md" : "#{url.delete_suffix("/")}/index.md"
      elsif url.include?(".")
        # A non-HTML asset (e.g. feed.xml, sitemap.xml) - no markdown version.
        nil
      else
        # Extensionless pretty URL (e.g. an .html page served at "/posts").
        "#{url}.md"
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  Jekyll::MarkdownForAgents.run(site)
end
