# Version-stamp the processed marker instead of a boolean flag

The `Creator` attribute is set to `"PDF Archiver"` after every OCR attempt, including failed ones, so
a file is never retried in a loop. That makes the flag permanent: when a later release improves OCR
or its quality checks, every already-touched file is excluded forever — which is exactly why the
`TextReadability` fix (`9a82a9c`) could never repair a single document. The marker becomes
`"PDF Archiver v<N>"`, and the pass skips a file only when its stamped version is **greater than or
equal to** the engine version it is running. Bumping `ocrEngineVersion` therefore grants every
archived document exactly one more attempt.

**Considered:** dropping the marker and relying on `TextReadability` alone — rejected, it reopens the
retry loop for documents where OCR genuinely finds no text (an unreadable scan would be re-OCR'd on
every pass forever). A sidecar index of processed files — rejected, it does not survive the archive
being moved, re-synced or restored on another device, which the in-file marker does.

**Consequences:** the marker lives in users' PDF files, so its format is effectively permanent —
readers must tolerate both the unversioned legacy value (treated as v1) and future suffixes. Any
future change to OCR output quality is expected to bump `ocrEngineVersion`; shipping an OCR
improvement without bumping it silently withholds that improvement from the whole existing archive.
