---
description: "Prepare a prompt ready to use on a specialized image generation agent to generate a cover image for a techdominator.com blog post"
argument-hint: "provide the blog post path"
agent: "agent"
---

Considering the color palette specified in the `css\main.scss` file, generate a prompt structured as following:

1. This exact text: `Generate a blog post cover in heavy pixel art and landscape format for the following article, aligning with the colors described, cover should be highly visual with minimal text:`
2. Summary of the color palette in the `css\main.scss` file.
3. Short summary of the ${input:blogPostPath} article
