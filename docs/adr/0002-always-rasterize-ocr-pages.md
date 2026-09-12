# Always rasterize a page for OCR, never reuse its embedded image

Adding a text layer replaces each page with a freshly rendered one, so the rendered image must contain
everything the page showed. Reusing a page's own embedded JPEG instead of re-rendering avoids a second
lossy encode, and a scanned page usually *is* one full-page bitmap — but "usually" is the problem. No
cheap dictionary-level guard (one XObject, `/Subtype /Image`, `DCTDecode`, `/Rotate 0`, an aspect ratio
matching the media box) says anything about the page's content stream: a page with a corner logo plus
invoice text passes all of them, and reuse would then discard the text and blow the logo up full-page.
OCR rewrites the user's document in place with no backup, so that loss is unrecoverable — and #300 put
the action one tap away on every document, archived ones included.

**Considered:** scanning the content stream (`CGPDFContentStreamCreateWithPage` + `CGPDFScanner`) and
rejecting any text, path or inline-image operator plus any `cm` that is not the media box — rejected.
The guard surface is much wider than the operator list (annotations, soft masks, transparency groups,
optional content), every omission is another silent content-loss path, and the payoff is only avoiding
one re-encode.

**Consequences:** an image-only page is re-encoded once per OCR run, at 3x its point size (~216 DPI)
and at the configured `PDFQuality`. Repeated runs on the same document compound that loss, which is
acceptable because OCR runs once automatically and manual re-runs are rare and deliberate. Do not
reintroduce image reuse without a content-stream check that is proven against a mixed image+text page.
