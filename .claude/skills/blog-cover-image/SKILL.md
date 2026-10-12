---
name: blog-cover-image
description: "Prepare a prompt ready to use on a specialized image generation agent to generate a cover image for a techdominator.com blog post. WHEN: \"blog cover image\", \"cover image prompt\", \"prompt for a post cover\"."
argument-hint: "provide the blog post path"
disable-model-invocation: true
---

The user provides the path of a blog post (for example a file under `_posts/`).

Considering the color palette specified in the `_includes/critical-styles.scss` file, generate a prompt structured as following:

1. This exact text: `Generate a blog post cover in heavy pixel art and landscape format for the following article, aligning with the colors described, cover should be highly visual with minimal text:`
2. Summary of the color palette in the `_includes/critical-styles.scss` file.
3. Short summary of the blog post the user provided.
