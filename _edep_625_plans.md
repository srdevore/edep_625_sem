
# 5. Posit Cloud Space
- Free account at https://posit.cloud
- Create a Space: "EDEP 625 Fall 2026"
- Inside the space, create one Project per rlab (or one project with weekly subfolders — your call)
- Settings → Members → copy the **Space invite link**. This is the single link you give students all semester.
- Each week: drag the new rlab `.qmd` into the corresponding project. Students see it immediately.

### 6. Link the website to Posit Cloud
On each lab's page in the website, include:
- **"Open in Posit Cloud"** button → links to the project URL in your Space
- **"Download .qmd"** link → for students who prefer local
- The rendered lab embedded inline, so students can read along even before opening it

A minimal lab page template (`rlabs/w01-lavaan-basics.qmd`):
```markdown
---
title: "Lab 1: lavaan basics"
---

[Open in Posit Cloud](https://posit.cloud/spaces/XXX/content/YYY){.btn .btn-primary}
[Download .qmd](w01-lavaan-basics.qmd){.btn .btn-secondary}

## Setup
```{r}
library(lavaan)
```
... lab content ...
```


## Lecture-generating skill (custom Claude Code skill)

A repo-local skill that scaffolds new lecture `.qmd` files from a brief topic description, enforcing the pedagogical patterns demonstrated in `edep606_wk14_clustering2.rmd` (used as the reference model).

**Location:** `.claude/skills/generate-lecture/SKILL.md` in the new repo, with the reference lecture copied to `.claude/skills/generate-lecture/reference-lecture.rmd`.

**Trigger:** `/generate-lecture <topic>` (e.g. `/generate-lecture path analysis`).

**Pedagogy the skill enforces (not negotiable defaults):**

1. **Conceptual before technical.** Every new concept opens with a *"what are we doing"* slide in plain language with a visual analogy, *before* any math. Math appears only after the concept is grounded. Quasi-math/notation comes second; bare equations come third.
2. **Build knowledge incrementally.** Each lecture opens with a Review section tying back to prior weeks, introduces one or two new ideas with worked examples on a real dataset, ends with an Up Next bridge.
3. **Built-in processing breaks.** At least 2 explicit `# Pause & Recap` slides per lecture (one mid-lecture, one near the end), each posing a question students can answer with what they just learned.
4. **Heavy on visuals + analogies in the conceptual phase.** Every algorithmic step gets its own ggplot diagram. Every new abstract concept gets an analogy-grounded figure (e.g., Pythagorean theorem → high-d distance; map → clustering).
5. **Strengths-and-limitations framing.** Every method/algorithm gets a dedicated slide explicitly listing strengths AND limitations — discourages "this method is always best" thinking.
6. **Decision guide + best practices.** When a lecture covers multiple methods, end with a *"choosing the right method"* slide and a numbered best-practices slide.
7. **Speaker notes everywhere.** `::: notes` blocks on every content slide, 1–3 sentences in a teacher's voice — not a re-statement of what's on the slide, but the *thing you'd say out loud* to elaborate.

**Lecture skeleton the skill generates:**
```
Title slide
# Agenda
# Review (link back to prior week)
# Concept 1: <Name>
  - "What are we doing" (plain language + analogy + visual)
  - Steps (numbered, one visual per step)
  - Mathematical notation
  - Worked example on a real dataset
  - Evaluation / how you know it worked
# Pause & Recap
# Concept 1: Strengths and Limitations
# Concept 2: <Name>  (same template)
...
# Method Comparison (table + decision guide)
# Best Practices
# Pause & Recap (final)
# Up Next
```

**Visual/accessibility defaults the skill enforces:**

- **Color palette: Okabe-Ito** (the standard color-blind-safe palette): `#E69F00, #56B4E9, #009E73, #F0E442, #0072B2, #D55E00, #CC79A7, #999999`. Used via `scale_color_manual()` / `scale_fill_manual()`. Replaces the tomato/steelblue/darkgreen combo in the reference (which isn't fully color-blind safe — red/green is tricky for the most common form of color blindness).
- **Plot text sizes for projection**: plot titles ≥ 14pt, axis text ≥ 12pt, annotations ≥ 12pt. Default ggplot text is too small for the back of a classroom; the skill sets a base theme with these minimums.
- **Standard theme**: `theme_minimal()` + bold centered titles (matches the reference file's look).
- **Slide font sizes**: revealjs defaults work; the skill flags any slide where text would overflow and force shrinking.
- **Equations**: use `$$...$$` blocks with line breaks between premise and conclusion for readability — not jammed on one line.

**Skill artifact contents (what `.claude/skills/generate-lecture/SKILL.md` will say to Claude):**
- "Before generating, read `reference-lecture.rmd` end-to-end to internalize the structure"
- The pedagogical rules listed above, each as a checklist item
- The skeleton above, as a literal template
- An author-style note: "the teacher's voice is conversational, asks rhetorical questions, uses analogies. Don't lecture *at* the student — walk them through the discovery."
- A self-check at the end: "Before returning, verify the draft includes ≥ 2 Pause & Recap slides, an analogy in every conceptual section, the Okabe-Ito palette in every plot, and speaker notes on every content slide."

## Lab-generating skill (custom Claude Code skill)

A second repo-local skill that scaffolds new rlab `.qmd` files following APA 7th-edition reporting conventions and a consistent applied-analysis workflow.

**Location:** `.claude/skills/generate-rlab/SKILL.md`, with a representative rlab from the EDEP 606 2026 archive copied to `.claude/skills/generate-rlab/reference-rlab.qmd` as the in-house style reference.

**Trigger:** `/generate-rlab <topic>` (e.g. `/generate-rlab confirmatory factor analysis`).

**Standard 7-section structure every generated rlab follows:**

1. **Purpose** — one paragraph: what the lab teaches, what skills students should walk away with, the method's role in the broader SEM workflow.
2. **Research Question** — a concrete substantive question the analysis will address, framed in plain language (not just notation).
3. **Data and Variables** — brief description of the dataset, variables used, sample size, any preprocessing.
4. **Assumption Checks** — method-appropriate checks *before* fitting, each with R code + one-line interpretation of whether the assumption is met:
   - Path/SEM: missingness pattern (Little's MCAR if relevant), multivariate normality, linearity, multicollinearity, sample-size adequacy (≥ 10 cases per estimated parameter as rule of thumb)
   - CFA: factorability (KMO, Bartlett's), multivariate normality
   - Each violated assumption gets a "what to do about it" note (e.g., MLR estimator if non-normal)
5. **Model Building** — incremental:
   - Start with a baseline/saturated model
   - Then the theoretically specified model
   - Then any modifications (with explicit justification — modification indices are *guidance*, not gospel)
   - Each step: model spec → fit → one-sentence "what changed and why"
6. **Results Output** — APA-formatted tables and figures:
   - **Fit indices table**: χ²(df), p, CFI, TLI, RMSEA [90% CI], SRMR, with cutoff comparisons inline
   - **Path coefficients table**: unstandardized B, SE, standardized β, z, p, 95% CI
   - **Path diagram** via `semPlot` or `lavaanPlot`
   - **Modification indices** (if used) shown as a clearly-labeled table
7. **Interpretation** — APA-prose paragraph(s): which paths were significant, in what direction, with what magnitudes, and how this answers the RQ from section 2. Written in the register of a published paper, not a statistics homework.

**APA 7th-edition conventions the skill enforces:**

- Italicize statistical symbols: *χ²*, *p*, *β*, *r*, *N*, *df*, *M*, *SD*
- Report *p* as `p < .001` when below threshold; otherwise to 3 decimals (`p = .043`, never `p = 0.04` or `p = 0.000`)
- Report fit indices to 3 decimals (`CFI = .967`)
- RMSEA always with 90% CI: `RMSEA = .052, 90% CI [.041, .063]`
- Round descriptive statistics to 2 decimals
- Tables follow APA structure: short title *above*, no vertical lines, horizontal rules only at top, below header, and bottom
- Implementation: `kable(..., booktabs = TRUE)` or `gt`/`flextable` configured to APA style — a shared helper in `R/apa-tables.R` keeps this consistent
- Figures: descriptive caption, axes labeled with the *substantive variable name*, not the R object name

**Workflow checks built into the output:**

- Every model fit is *immediately* followed by a fit-indices interpretation against accepted cutoffs (CFI/TLI ≥ .95, RMSEA ≤ .06, SRMR ≤ .08)
- Every significant path is interpreted directionally and in original-scale terms, not just "significant"
- Every assumption-check result has the "if violated, do X" note attached
- Code chunks are commented to explain the *why*, not just the *what*

**Skill artifact contents (`.claude/skills/generate-rlab/SKILL.md` will instruct Claude to):**
- Read `reference-rlab.qmd` end-to-end before generating, to internalize the in-house style
- Use the 7-section template literally — do not add, remove, or reorder
- Apply the APA conventions checklist on every numeric output
- Self-check before returning: verify all 7 sections present and in order, every fit index reported with cutoff comparison, every *p*-value follows APA conventions, every table uses the shared APA helper, the final interpretation explicitly answers the RQ stated in section 2

**Shared infrastructure between the two skills:**
- `R/apa-tables.R` — APA-styled table helper (used by labs)
- `R/okabe-ito.R` — color-blind palette + ggplot theme (used by lectures)
- `R/class-dates.R` — date helper (used by syllabus + release-date pre-render)
All in one `R/` folder at the repo root, sourced by whichever `.qmd` files need them.

## Critical files to set up first (proof-of-concept order)
Build these before authoring real content, to validate the toolchain end-to-end:
1. `_quarto.yml` — navbar + theme
2. `_class-config.yml` — semester start date, class days, weeks
3. `_schedule.yml` — placeholder topic/reading rows for all weeks
4. `R/class-dates.R` — `compute_class_date()` helper (used by syllabus rendering + release-date pre-render script)
5. `index.qmd` — landing page reading from `_schedule.yml`
6. `syllabus.qmd` — auto-populated schedule table
7. `.github/workflows/publish.yml` — auto-deploy with daily cron
8. `R/okabe-ito.R`, `R/apa-tables.R` — shared helpers
9. `.claude/skills/generate-lecture/` — skill scaffold + reference lecture copied from EDEP 606's clustering2
10. `.claude/skills/generate-rlab/` — skill scaffold + reference rlab copied from a representative EDEP 606 2026 rlab
11. `lectures/w01-intro-to-sem.qmd` — first deck generated via `/generate-lecture` to validate the lecture skill
12. `rlabs/w01-example.qmd` — first rlab generated via `/generate-rlab`, mirrored into one Posit Cloud project, with the two buttons working

Once those five round-trip cleanly (push → site updates → click Posit Cloud button → lab opens and runs), every later week is just authoring content into the same templates.

## Verification (before semester starts)
1. `quarto preview` locally — full site renders, navbar works, slide deck loads
2. Push to GitHub → Action runs green → site is live at Pages URL
3. Incognito window (acting as student): visit the site, view slides, click the Posit Cloud button, confirm lab opens
4. Fresh Posit Cloud account (acting as student): use Space invite link, confirm you can see and copy the lab project
5. Run the full student flow with one friend or TA before week 1
