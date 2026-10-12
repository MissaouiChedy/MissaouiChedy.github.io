---
name: write-blog-post
description: "Write and elaborate on a techdominator.com blog post based on the provided outline. WHEN: \"write the blog post\", \"elaborate on this outline\", \"flesh out the post\"."
argument-hint: "provide blog post file and code sample folder"
disable-model-invocation: true
---
Use the `techdominator-writing-style` skill to ensure that the writing style, structure, tone, and vocabulary are consistent with existing posts in the repository.

The user provides two inputs: the path of a blog post file containing an outline, and a code sample folder. If either is missing, ask for it before writing.

Elaborate on the blog post file the user provided. Elaborate on the content based on the outline in the same file.

Each section will contain a list of bullet points of elements to elaborate on.

Some bullet points will contain references to web pages that you should use to provide additional context and information in your elaboration.

Use the code sample folder the user provided to provide code snippets and examples where applicable.

When a diagram or screenshot is needed, insert the <<SCREENSHOT: description>> placeholder and provide a description of what the screenshot or diagram should contain.

At the start of the post, make sure to include a summary paragraph and a placeholder for the post cover image:
```
<p class="summary">
<Description of the blog post in 1-2 sentences.>
</p>

<div class="img-container">
  <img src="{{ site.url }}/imgs/<<PostTitle>>.png" alt="<<Post Title>>>" />
</div>
```
