# Nested meaning UI prototype

Question: how can someone quickly understand an unfamiliar word inside a lookup result without losing the original lookup?

Decision (2026-09-25): variant `A` was selected. The anchored popover keeps the unfamiliar word, its sentence, and the original lookup visible while showing only the minimum secondary explanation.

Three interaction variants are available on the same throwaway page, switchable with `?variant=`:

- `A` — anchored peek: double-clicking a word opens a small definition beside it.
- `B` — meaning rail: the secondary definition stays in a narrow rail beside the original result.
- `C` — inline thread: the secondary definition appears directly below the sentence that contains the word.

All variants keep the original lookup for **scalable** visible and treat the nested definition as temporary, secondary context. Double-click an English word in the result, or use one of the suggested words, to try it.

Run from the repository root:

```sh
./scripts/run-nested-meaning-prototype.sh
```

Then open `http://127.0.0.1:4174/?variant=A`. Use the floating arrows or the left/right arrow keys to compare variants.

This is throwaway prototype code. Reimplement the chosen interaction in SwiftUI rather than shipping this HTML.
