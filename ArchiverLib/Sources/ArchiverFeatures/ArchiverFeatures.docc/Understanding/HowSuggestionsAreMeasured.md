# How suggestions are measured

Why the archive is also the test set.

## Overview

A suggestion is a guess, and guesses need a scoreboard. The archive provides one
for free: every filed document is a decision a human already made, and the
filename records it. Hide the name, ask the app to propose one, compare.

That is what the evaluation suite does, built on Apple's Evaluations framework.

### The two kinds of measurement

**Heuristics** — things countable in code. How many of the tags you actually
chose were recovered, how many suggested tags exist in the archive at all,
whether the description length matches the archive's band, whether a suggestion
was offered.

**A model judge** — things only describable in words. Whether a suggestion reads
like the rest of the archive, whether every part of it is supported by the
document, whether the tags sit at a useful level of detail.

The two disagree in a useful way. Heuristics are exact but narrow; the judge is
broad but drifts. A change is trusted when the heuristics move.

### Honest splitting

The documents used for scoring are held out of the prompt. Otherwise the model
would be shown the answer it is being asked for — the archive statistics that go
into the prompt would include the very document under test.

### What the measurements have shown

Two things worth knowing when reading suggestions critically:

**There is a ceiling, and it is not the wording.** About half the tags in a real
archive never appear in the document text. Family names, filing conventions,
judgement calls — no prompt can extract what is not there. That is the reason the
prompt carries tag companions rather than more instructions.

**Better wording is not always better filing.** Asking for richer descriptions
made them longer than the archive's own style and cost tag accuracy. The
measurements are what caught that; it looked like an improvement while reading
individual answers.
