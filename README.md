# hugo-shortcode-issue

## Purpose of this repository

This project was created to reproduce a shortcode issue I encountered with Hugo.

## Issue

The "markdownify" function calls in the asciidoctor as a rendering engine under the specific condition.

## Files

The following files are part of this project:

### layouts/shortcodes/mbtable.html

This shortcode needs the "| markdownify" part because I want to handle the HTML code.

```text
{{ $htmlTable := .Inner | markdownify }}
{{ $table_class := .Get "table_class" }}
{{ $new_table_tag := printf "<table class=\"%s\">" $table_class }}
{{ $htmlTable = replace $htmlTable "<table>" $new_table_tag }}
<div class="table">
{{ $htmlTable | safeHTML }}
</div>
```

* Reference: [https://www.mybluelinux.com/how-create-bootstrap-tables-in-hugo/](https://www.mybluelinux.com/how-create-bootstrap-tables-in-hugo/)

If you just want to use a table without such an inner decoration, remove the "| markdownify" part from the shortcode and use the "{{% %}}" format. In this case, the table will be described based on the parent document format, such as markdown and asciidoc.

### content/md/_index.md

This is the target content, which includes a markdown shortcode.

```markdown
+++
title = 'Markdown document'
date = 2024-09-02T21:04:03+09:00
draft = false
+++

# Markdown Example

{{< mbtable table_class="table-info" >}}
| foo | bar |
| --- | --- |
| baz | bim |
{{< /mbtable >}}

# Asciidoctor Table

{{< mbtable table_class="table-info" >}}
|===
| foo | bar

| baz
| bim
| ===
{{< /mbtable >}}
```

### Expected Output

I expected the following output in the public/md/index.html file:

```html
<div class="table">
<table class="table-info">
<thead>
<tr>
<th>foo</th>
<th>bar</th>
</tr>
</thead>
<tbody>
<tr>
<td>baz</td>
<td>bim</td>
</tr>
</tbody>
</table>
</div>

<div class="table">
<p>|===
| foo | bar</p>
<p>| baz
| bim
| ===</p>
</div>
```

### Actual (issued) Output

I got the following result:

```html
<div class="table">
| foo | bar |
| --- | --- |
| baz | bim |
</div>

<div class="table">
<table class="tableblock frame-all grid-all stretch">
<colgroup>
<col style="width: 50%;"/>
<col style="width: 50%;"/>
</colgroup>
<thead>
<tr>
<th class="tableblock halign-left valign-top">foo</th>
<th class="tableblock halign-left valign-top">bar</th>
</tr>
</thead>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p class="tableblock">baz</p></td>
<td class="tableblock halign-left valign-top"><p class="tableblock">bim</p></td>
</tr>
</tbody>
</table>
</div>
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

## Shortcode with Asciidoc

The content/_index.adoc file contains a shortcode in markdown format.

After processing the file with the patched version of the hugo command, I got the expected otuput as follows.

```html
<div class="table">
<table class="table-info">
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
```
