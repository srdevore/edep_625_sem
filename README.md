# Class setup template

Template for course website linked to course materials with features to generate teacher/student versions of slide decks, auto-populate course info, etc. 

## Features: 

1. Lectures, labs, etc are .qmd files that are rendered on a puplic website and can be downloaded as PDFs by students. 
2. Profiles: teacher and student profiles allow for student version (i.e. without notes and answers to questions) to be rendered on the site and teacher version (with notes and answers) in html.

    - students can download the student version from the website as pdf or view as html. They never see teacher version 
    - Includes examples of lecture slides with show on click in the teacher profile so teacher can show answers in class that are not rendered on student version.

3. Class schedule: Weeks and dates automatically populated based on semester start/end date and class cadence. 
4. Schedule release of materials. Create materials in advance and don't show on student-facing site until after a specific week. 

    - show week X: automatically shows one hour before first class of week starts (must push within 1 hr of class start)
    - add release: week N

# Quickstart
Start by building your own copy of the template. 

## 1. Create your own version:

Go to [github](https://github.com/). Log in or create an account. This is referred to as the "Github UI" below.

Navigate to the [template](https://github.com/srdevore/class_setup_template) 
-> click green "use this template" button in top right 
-> create a new repository

Fill in the form with your own title and description. You MUST leave it set as public in order to create a free website.  

## 2. Set up the web site
This sets up a **public** web site that you can link others' to. Don't post anything sensitive. 

### part a: select method
In the github UI, go to Settings > pages > Build and deployment section
In the dropdown where it says "deploy from a branch", click "Github Actions"

### part b: first deployment

Github UI > Actions > All workflows > "initial commit" probably shows failed. 

Click into the initial commit and click re-run jobs > re-run all jobs > in the popup click 're-run jobs'. 

Takes ~5 min to build first time because it's installing dependencies.

Once build & deploy finish, the url will appear under deploy. Follow link to confirm it worked. This should show you a site that looks exactly like the template.

After this, updates will automatically be updated on push. 

## 3. Personalize it

1. Start a codespace
This is one easy way to get started personalizing your site. 

In the github UI > your repo > code (tab) > code (green button) > create codespace > click the auto-generated codespace name
Alternately: clone and work in your preferred IDE

2. Configure the class

Open `_class-config.yml` and fill in your class time, dates, instructor name, semester start, class meeting day(s), timezone, holidays, etc. These values propagate to the syllabus, lecture headers, navbar title, and release-date gating.


## 4. Update site

After you make changes in the repo, they need to be updated on the student-facing site. 

Site auto-redeploys on git push. Follow your usual process (git add . > git commit -m"your message here" > git push)

Go to the github UI > actions > All workflows 

click the top one. When deploy is green, the url will show up and the updates are live. 

You. may need to do a hard refresh (cmd + R) 

## 5. Render Teacher version of slides

Anything inside `::: {.content-visible when-profile="teacher"}` is **stripped**
from a normal render. "Teacher" is a per-render flag, not a mode you stay in.

The teacher profile also writes to a **different folder**: `_teacher/`, not
`_site/`. Rendering from the Quarto button or Cmd+Shift+K uses the default
(student) profile, so notes will be missing — that is the usual reason they
"disappear".

```{bash}
# renders 
quarto render lectures/w02_regression_review.qmd --profile teacher
```

Open `_teacher/lectures/<deck>.html` — not `_site/...` — and press **S** for
the speaker-notes view (allow popups).

```{bash}
#downloads
download _teacher/lectures/test_lecture.html
```

### Speaker notes are never in the downloadable PDF

The PDF on the Lectures page is built by CI from the **student** render
(`publish.yml` runs decktape over `_site/lectures/*.html`), and decktape does
not print `aside.notes` in any case.

For a printable teacher copy with notes, add this to the deck's YAML and render
with `--profile teacher`:

```yaml
format:
  revealjs:
    show-notes: separate-page
```

**Do not commit that setting enabled.** It makes notes visible to all viewers,
and because it lives in the document it applies to the student build too — it
would publish your answer keys.

## 6. Unstage the Python virtualenv

`.venv/` was missing from `.gitignore`, so a `git add .` staged every file in
`site-packages` (thousands of them). `.gitignore` now excludes it, but that
only applies to untracked files -- anything already staged has to be removed
from the index by hand.

To unstage **everything** you just staged, run `git reset` with no flags and no
paths. It empties the index, leaves every file on disk untouched, and does not
alter any commit -- safe because none of this was committed yet:

```{bash}
git reset
```

Then re-stage deliberately, now that `.gitignore` excludes `.venv/`:

## 6. Unstage the Python virtualenv

`.venv/` was missing from `.gitignore`, so a `git add .` staged every file in
`site-packages` (thousands of them). `.gitignore` now excludes it, but that
only applies to untracked files -- anything already staged has to be removed
from the index by hand.

To unstage **everything** you just staged, run `git reset` with no flags and no
paths. It empties the index, leaves every file on disk untouched, and does not
alter any commit -- safe because none of this was committed yet:

```{bash}
git reset
```

Then re-stage deliberately, now that `.gitignore` excludes `.venv/`:

## 7. Hide a WIP page you already committed

A half-finished `.qmd` breaks the site render (Quarto builds every `.qmd` in the
project) and, if committed, publishes to the public site. To keep one private
until it is ready, do all three:

1. **Stop the render** -- add an exclusion line under `project: render:` in
   `_quarto.yml` (order matters; the `!` line comes after the `**/*.qmd` glob):

    ```yaml
    render:
      - "**/*.qmd"
      - "!rlabs/w05_interpretation.qmd"  # WIP draft -- excluded from render
    ```

2. **Ignore it going forward** -- add the path to `.gitignore`.

3. **Untrack the already-committed copy** -- `.gitignore` only affects
   *untracked* files, so a file that is already committed keeps being tracked.
   `git rm --cached` removes it from the index while leaving your local copy on
   disk:

    ```{bash}
    git rm --cached rlabs/w05_interpretation.qmd lectures/w05_interpretation.qmd
    git commit -m "Untrack WIP w05 interpretation files; exclude from render"
    ```

When the page is ready, reverse it: delete its lines from `.gitignore` and
`_quarto.yml`, then `git add` the file.


rm -rf lectures/_freeze lectures/.quarto lectures/w05_mvpa_interpretation_files
quarto render lectures/w05_mvpa_interpretation.qmd --profile teacher --cache-refresh


## Fixing a push rejected for a file over 100 MB

GitHub rejects any push containing a file over 100 MB
(`GH001: Large files detected`), *even if the file was deleted in a later
commit*, because it is still in the unpushed history. Example: 
`data/pisa22_USA_GBR_KSV.csv` (104.7 MB).

1. **Ignore it** -- make sure the path is in `.gitignore`.

2. **Untrack it** (keeps your local copy on disk):

    ```{bash}
    git rm --cached data/pisa22_USA_GBR_KSV.csv
    ```

3. **Remove it from the unpushed commits.** Pick one:

    Option A -- rewrite only the unpushed commits:

    ```{bash}
    git filter-branch --index-filter \
      'git rm --cached --ignore-unmatch data/pisa22_USA_GBR_KSV.csv' \
      origin/class_planning..HEAD
    ```

    Option B -- squash the unpushed commits into one (simpler):

    ```{bash}
    git reset --soft origin/class_planning
    git rm --cached data/pisa22_USA_GBR_KSV.csv
    git commit -m "w7 lecture, lab, and data updates"
    ```

4. **Push**, then open a PR from `class_planning` into `main`:

    ```{bash}
    git push
    ```

Check other data files are under 100 MB first: `ls -la data/`.

## Running the CFA playground widget (teacher version)

From the repo root, serve the teacher version locally:

```{bash}
python3 -m http.server 8000 --directory widgets/_src
```

Then open `cfa_playground_teacher.html` on port 8000 (Codespaces: Ports tab or
Simple Browser). Add `?preset=cfa` to the URL to start from the two-factor CFA.

To regenerate the student and teacher versions after editing the template:

```{bash}
python3 widgets/_src/build_cfa_playground.py
```
