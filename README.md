# Quarto Typesetting for Communications in Kinesiology



This is a Quarto template that assists production and copy editors at Communications in Kinesiology create final PDF and HTML versions of the published articles.

## Creating a New Article

You can use this as a template to create an article for CiK. To do this, use the following command:

```bash
quarto use template arcaldwell49/cik-quarto
```

This will install the extension and create an example qmd file and bibiography that you can use as a starting place for your article.

## Installation For Existing Document

You may also use this format with an existing Quarto project or document. From the quarto project or document directory, run the following command to install this format:

```bash
quarto install extension arcaldwell49/cik-quarto
```

## Usage

To use the format, you can use the format names `cik-pdf` and `cik-html`. For example:

```bash
quarto render article.qmd --to cik-pdf
```

or in your document yaml

```yaml
format:
  pdf: default
  cik-pdf:
    keep-tex: true    
```

