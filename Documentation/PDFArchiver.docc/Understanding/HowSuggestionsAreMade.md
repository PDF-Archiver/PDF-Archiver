# How suggestions are made

What the model is shown comes from your archive, every time.

## Overview

The model that proposes a description and tags is a general one. What makes its
answers fit *your* archive is that what it gets shown is not general: it is put
together from the documents you have already filed, each time it is asked.

### What the model is shown

**Your tags, most frequent first.** Only tags you have used more than once or
twice, so a one-off does not come back as a suggestion.

**Example descriptions from recent filings.** This is the only place the model
sees how you word things, which turns out to matter more than any instruction
about wording.

**The description length your archive uses.** Measured from your own
descriptions rather than fixed in advance. An archive of two-word names and one
of eight-word summaries get different suggestions, because asking for a length
the archive does not use produces answers that fit nothing.

**Which tags belong together.** Derived from the archive: if `hornbach` appears,
`baumarkt` does too. This matters because roughly half the tags in a real archive
never appear in the document text at all — `steuerrelevant` is a judgement, not a
word on the page — and no instruction can conjure them. But they follow reliably
from the ones that *are* on the page.

### What happens to the answer

**Tags outside your vocabulary are dropped.** A suggestion that is not already a
tag somewhere in the archive is removed rather than shown. This cannot lose a
correct answer, because a correct answer is by definition one you already use,
and it keeps the vocabulary from splintering into synonyms.

If that leaves nothing, the document gets no tags. See
<doc:TurningOnAppleIntelligence> for why an empty answer is preferred to a
plausible wrong one.

**The wording is cleaned up.** Symbols and capitals are removed so the result
can become a filename, exactly as if you had typed it yourself.

### Two things worth knowing

**Only the beginning of a long document is read.** That is where invoices and
notices say what they are, so it is rarely a limitation — but a document that
only reveals itself on page six will not be understood.

**Nothing is sent off the device.**
