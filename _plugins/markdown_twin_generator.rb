# frozen_string_literal: true

# Generates a Markdown "twin" for every post and for the About page.
#
# GitHub Pages cannot perform `Accept: text/markdown` content negotiation,
# but it does serve .md files with `Content-Type: text/markdown`. The twins
# therefore implement the "Markdown for Agents" contract: for any article at
# /article/{slug}.html an agent can GET /article/{slug}.md and receive a
# Markdown representation of the page. HTML remains the default for browsers.

require "reverse_markdown"

module Jekyll
  # Creates one MarkdownTwinPage per post plus one for the About page.
  class MarkdownTwinGenerator < Generator
    safe true
    priority :low

    ABOUT_PAGE_NAME = "about-chedy-missaoui.html"

    def generate(site)
      sources = site.posts.docs.dup
      about_page = site.pages.find { |page| page.name == ABOUT_PAGE_NAME }
      sources << about_page if about_page

      sources.each { |doc| site.pages << MarkdownTwinPage.new(site, doc) }
    end
  end

  # A virtual page whose content is the Markdown representation of a source
  # post/page, written next to it with a ".md" extension.
  #
  # The fake ".mdtwin" source extension is not matched by the Markdown
  # converter (only the passthrough Identity converter matches it), so the
  # content is written out untouched while Liquid still renders. The ".md"
  # permalink drives the output URL, file name and served Content-Type.
  class MarkdownTwinPage < Page
    TWIN_EXTENSION = ".mdtwin"

    def initialize(site, doc)
      @site = site
      @base = site.source
      @dir = File.dirname(doc.url)
      @name = "#{File.basename(doc.url, '.html')}#{TWIN_EXTENSION}"

      process(@name)

      # Post URLs end in ".html" (/:categories/:title.html permalink); the
      # About page URL is extensionless. Normalize both to a ".md" twin URL.
      permalink = doc.url.end_with?(".html") ? doc.url.sub(/\.html\z/, ".md") : "#{doc.url}.md"

      @data = {
        "layout"    => nil,
        "permalink" => permalink,
        "sitemap"   => true,
      }

      # Markdown-authored sources pass through verbatim. HTML-authored sources
      # are carried raw and converted to Markdown once Liquid has rendered
      # (see the :post_render hook below): several legacy .html posts embed
      # Liquid tags whose literal text would not survive the HTML parser.
      @content = doc.content.to_s
      @html_source = doc.extname != ".md"
    end

    # Report as HTML so jekyll-sitemap picks the twins up via site.html_pages.
    def html?
      true
    end

    def html_source?
      @html_source
    end
  end
end

# Convert the rendered output of HTML-sourced twins to Markdown. Markdown
# twins pass through untouched: their content already is Markdown.
Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.is_a?(Jekyll::MarkdownTwinPage) && page.html_source?

  page.output = ReverseMarkdown.convert(page.output.to_s, github_flavored: true)
end
