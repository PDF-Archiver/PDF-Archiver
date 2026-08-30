# How suggestions are made

The prompt is assembled from your archive, every time.

## Overview

The model that proposes a description and tags is a general one. What makes its
answers fit *your* archive is that the prompt is not general: it is rebuilt from
the documents you have already filed.

### What goes into the prompt

**Your tags, most frequent first.** Only tags used at least a few times, so a
one-off does not become a suggestion. The names alone, never their counts — a
count in the prompt has a way of coming back out inside a tag.

**Example descriptions from recent filings.** This is the only place the model
sees how you word things, which turns out to matter more than any instruction
about wording.

**The description length your archive uses.** Measured as the 10th-to-90th
percentile of your own descriptions, not a fixed number. An archive of two-word
slugs and one of eight-word summaries get different instructions. Asking for
"5-10 words" in an archive that files 1-4 produced answers piled up on 5 —
measuring instead fixed that.

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

**The description is trimmed, tags are slugified.** Symbols go, case goes, and a
trailing count the model echoed from the statistics is stripped before
slugifying — otherwise `rechnung:3` would become the tag `rechnung3`.

### What is deliberately not done

The document text is truncated to fit the model's context window rather than
summarized first. The suggestion is computed from the beginning of the document,
which is where invoices and notices say what they are.

Nothing is sent off the device.
