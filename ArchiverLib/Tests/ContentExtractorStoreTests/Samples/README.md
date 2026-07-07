# Evaluation samples

Drop tagged PDFs here to use as ground-truth references for the content-extraction
evaluation. Files must follow the archiver naming scheme:

```
yyyy-mm-dd--description__tag1_tag2_tag3.pdf
```

- The **filename** is the expected output (description + tags).
- The PDF **text layer** is the input the model sees (needs OCR'd / searchable text;
  pure image scans with no text are skipped automatically).

`*.pdf` is git-ignored in this folder, so your personal documents are **never
committed**. For a larger corpus, instead point the env var at a copy of your
archive without copying files into the repo:

```sh
export PDF_ARCHIVER_EVAL_SAMPLES="/path/to/tagged/pdfs"
export PDF_ARCHIVER_EVAL_MAX=30   # optional, default 30
```

Aim for 20–30 documents that cover the variety you actually archive (different
vendors, document types, languages, short vs. long, easy vs. ambiguous).
