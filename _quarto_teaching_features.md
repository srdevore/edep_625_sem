# Quarto features to explore for EDEP 625 (SEM)

Recommendations for instruction and fostering critical thinking. Filename starts with `_` so Quarto excludes it from the site build.

Picked for direct fit with SEM as a subject and for pushing grad students past mechanical replication.

## 1. Embedded interactive R (`{webr}` or `{shinylive}`)

Students re-fit lavaan models in the browser with no install.

- **Pedagogical move:** give them a working model and ask *"drop the cross-loading constraint — does fit improve? Is the change in χ² meaningful relative to df?"* They have to *do* the experiment, not read about it.
- **Why it's highest-impact for this course:** removes the friction between "what if?" and getting an answer. SEM is a "fiddle with constraints and see what happens" subject; webR makes that immediate.
- Docs: <https://quarto-webr.thecoatlessprofessor.com/>, <https://quarto-ext.github.io/shinylive/>

## 2. Path diagrams as code (Mermaid / Graphviz / TikZ blocks)

SEM lives or dies on diagram literacy.

- Quarto renders Mermaid/Graphviz/TikZ inline; source-controlled diagrams force explicitness about every arrow.
- Pair a `semPlot::semPaths()` chunk next to the lavaan syntax so students see *syntax → picture* as one object.
- Good for teaching identification rules visually (count free params, count knowns).

## 3. Tabsets for model comparison

Use `::: {.panel-tabset}` to lay Model A / Model B / Model C side-by-side on one page.

- Examples: correlated vs. orthogonal factors; configural vs. metric vs. scalar invariance; saturated vs. constrained.
- Critical thinking happens when students can flip between alternatives in one mental frame instead of scrolling.

## 4. Callouts for traps and assumptions

Recurring visual cues train students to *expect* the pitfall.

- `:::{.callout-warning}` — "Heywood cases live here"
- `:::{.callout-important}` — identification rules
- `:::{.callout-tip}` — "stop and predict the sign of this loading before running"
- `:::{.callout-note}` — assumption reminders (multivariate normality, missingness mechanism, etc.)

## 5. Code annotation (line-numbered, hoverable explanations)

Most underused, most immediately useful for lavaan syntax.

- Quarto annotates specific lines of a code block with margin commentary students can click/hover.
- For dense syntax like `f1 =~ NA*x1 + 1*x2 + a*x3`, annotating each operator individually is way more effective than a separate paragraph of prose.
- Docs: <https://quarto.org/docs/authoring/code-annotation.html>

## 6. Embedded self-check exercises

Inline MCQ or fill-in-the-blank with reveal-on-click answers.

- Options: `webexercises` extension, `quizzicus`, or hand-rolled fragment-based reveals.
- Sprinkle every 2-3 slides → converts passive reading into active retrieval → surfaces misconceptions before lab time.

## 7. Margin asides for "consider this" prompts

Quarto's `.column-margin` puts side notes next to the main flow.

- Use for open-ended provocations ("Why would a researcher *not* want a saturated model?") that aren't quiz questions but signal "pause and think" without breaking reading flow.

## Priority order

1. **webR/shinylive** — biggest lever for grad-level critical thinking; lets students interrogate models live.
2. **Code annotation** — most underused, immediate payoff for lavaan literacy.
3. **Path diagrams + tabsets** — together, these make alternative model specifications visually and computationally comparable.
4. **Callouts + margin asides + self-check exercises** — pedagogical polish; add as you build out individual lectures.
