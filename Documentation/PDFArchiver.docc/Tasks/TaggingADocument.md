# Tagging a document

Three fields decide the filename.

## Overview

The tagging form edits exactly what the filename holds: a date, a description
and a set of tags. What you see in the fields is what the file will be called.

### Date

Parsed from the filename when the document already carries one, otherwise
detected in the document text. Correct it if the detected date is the print date
rather than the date the document is about.

### Description

A few words naming what the document *is about* — the issuer, the purchase, the
subject. It becomes the middle part of the filename, lowercased and hyphenated:
`stromabrechnung-eon`.

Keep it in the shape the rest of your archive uses. The app already nudges
towards that: the length it suggests is measured from the descriptions you have
written before, not from a fixed rule.

### Tags

Lowercase single words, stored alphabetically after `__`. Tags are how the
archive is browsed and filtered later, so they work best as filing categories
that group documents — `rechnung`, `versicherung`, a person's name — rather than
one-off details like an invoice number.

Suggested tags come from the vocabulary the archive already uses. A suggestion
that is not already a tag somewhere in your archive is dropped rather than
offered, which keeps the vocabulary from drifting apart over the years. You can
of course still type a genuinely new tag yourself.

### Saving

Saving renames the document to
`yyyy-mm-dd--description__tag1_tag2.pdf` and moves it into `Archive/<year>/`.
The exact rules — character handling, sorting, what makes a name valid — are in
<doc:FilenameConvention>.
