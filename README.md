# hugo-shortcode-issue

## Purpose

This project was created to reproduce a shortcode issue I encountered with Hugo.

## Files

The following files are part of this project:

### layouts/shortcodes/mbtable.html

```text
{{ $htmlTable := .Inner | markdownify }}
<div class="table">
{{ $htmlTable | safeHTML }}
</div>
```

### content/md/_index.md

This is the target content, which includes a markdown shortcode.

```markdown
+++
title = 'Markdown document'
date = 2024-09-02T21:04:03+09:00
draft = false
+++

# Markdown Example

{{% mbtable %}}
| foo | bar |
| --- | --- |
| baz | bim |
{{% /mbtable %}}
```

## How to reproduce the issue

```sh
$ hugo
$ cat public/md/index.html
```

### Expected Output

I expected the following output:

```html
<!DOCTYPE html>
<html>
<head>
</head>
<body>
  <main class="container"><h1 id="markdown-example">Markdown Example</h1>
<div class="table">
<table>
  <thead>
      <tr>
          <th style="text-align: left">foo</th>
          <th style="text-align: left">bar</th>
      </tr>
  </thead>
  <tbody>
      <tr>
          <td style="text-align: left">baz</td>
          <td style="text-align: left">bim</td>
      </tr>
  </tbody>
</table>
</div>


  </main>
</body>
</html>
```

### Actual (issued) Output

Unfortunately, I got the following result:

```html
<!DOCTYPE html>
<html>
<head>
</head>
<body>
  <main class="container"><h1 id="markdown-example">Markdown Example</h1>
<div class="table">
| foo | bar |
| --- | --- |
| baz | bim |
</div>


  </main>
</body>
</html>

```

## Guessed Root Cause

I suspect that the mixed environment, involving both Asciidoctor and Markdown rendering engines, is causing this issue.

Hugo renders the shortcode as part of the top-level content, the home object.

```golang
// Markdownify renders s from Markdown to HTML.
func (ns *Namespace) Markdownify(ctx context.Context, s any) (template.HTML, error) {
	home := ns.deps.Site.Home()
	if home == nil {
		panic("home must not be nil")
	}
	ss, err := home.RenderString(ctx, s)
	if err != nil {
		return "", err
	}

	// Strip if this is a short inline type of text.
	bb := ns.deps.ContentSpec.TrimShortHTML([]byte(ss), "markdown")

	return helpers.BytesToHTML(bb), nil
}
```

When the top-level content is not a Markdown document, the shortcode won't be rendered appropriately.

I created the following patch to confirm my suspicion:

```diff
diff --git a/tpl/transform/transform.go b/tpl/transform/transform.go
index 843351702..d0699051b 100644
--- a/tpl/transform/transform.go
+++ b/tpl/transform/transform.go
@@ -177,7 +177,8 @@ func (ns *Namespace) Markdownify(ctx context.Context, s any) (template.HTML, err
        if home == nil {
                panic("home must not be nil")
        }
-       ss, err := home.RenderString(ctx, s)
+       renderOpts := map[string]any{ "Markup": "markdown", }
+       ss, err := home.RenderString(ctx, renderOpts, s)
        if err != nil {
                return "", err
        }
```

This patch resolves the issue.

