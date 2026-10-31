---
name: blog-cover-image
description: "Prepare a prompt ready to use on a specialized image generation agent to generate a cover image for a techdominator.com blog post. WHEN: 'blog cover image', 'cover image prompt', 'prompt for a post cover'."
argument-hint: "provide the blog post path"
disable-model-invocation: true
---

# Blog Cover Image Generation

Use one of the following frameworks to structure your prompt for the image generation agent:
| # | Framework | Best for |
|---|---|---|
| 1 | Concept → System behavior → Physical analogy → Cinematic moment → Insight | Architecture and systems behavior |
| 2 | Problem → Consequence → Intervention → Video Game Reference → Transformation | Explaining why a technology exists |
| 3 | Before → Pressure → Breaking point → Manga Reference → Solution | Technical pain points, scaling, reliability |
| 4 | Invisible mechanism → Visible consequence → Rock/Metal Reference → Reveal | Complex concepts that are difficult to visualize |

# Process
Consider the color palette specified in the `_includes/critical-styles.scss` file, generate a prompt structured as following:

1. This exact text: `Generate a blog post cover in heavy pixel art and landscape format for the following article, aligning with the colors described, cover should be highly visual with no text:`
2. Summary of the color palette in the `_includes/critical-styles.scss` file.
3. Short summary of the blog post the user provided, select the best framework from the table above to structure the prompt.
4. Once prompt ready, use it with the `generate-images` skill to generate the cover image.
  - Image generation should be set to high quality
5. Optimize the generated image using `_tools/Optimize-Images.ps1`
6. Insert the optimized image into the blog post at the appropriate location, refer to `_posts\2025-03-15-azure-event-hubs-partition-receiver.md` for exact image placement and syntax.

