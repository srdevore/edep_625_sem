# edep_625_SEM

Template for course website linked to course materials with features to generate teacher/student versions of slide decks, auto-populate course info, etc. 

## Features: 

1. Lectures, labs, etc are .qmd files that are rendered on a puplic website and can be downloaded as PDFs by students. 
2. Profiles: teacher and student profiles allow for student version (i.e. without notes and answers to questions) to be rendered on the site and teacher version (with notes and answers) in html.

- students can download the student version from the website as pdf or view as html. They never see teacher version 
- Includes examples of lecture slides with show on click in the teacher profile so teacher can show answers in class that are not rendered on student version.

3. Class schedule: Weeks and dates automatically populated based on semester start/end date and class cadence. 
4. Shedule release of materials. Create materials in advance and don't show on student-facing site until after a specific week. 

- show week X: automatically shows one hour before first class of week starts (must push within 1 hr of class start)
- add release: week N

# Quickstart
## Start by building a template site

1. Create your own repo:
Go to [github](https://github.com/). Log in or create an account. This is referred to as the "Github UI" below.


Navigate to the [template](https://github.com/srdevore/class_setup_template) 
-> click green "use this template" button in top right 
-> create a new repository

Fill in the form with the repo title, etc you want to use. 

2. Set up page
This sets up a **public** web page that you can link others' to. Don't post anything sensitive. 

In the github UI got to Settings > pages > build & deployment
Select "Github Actions"

Github UI > Actions > All workflows > "initial commit"

Takes ~5 min to build first time because it's installing dependencies.

Once build & deploy finish, the url will appear under deploy. Follow link to confirm it worked. 

## Personalize

1. Start a codespace
This is one easy way to get started personalizing your site. 

In the github UI > your repo > code (tab) > code (green button) > create codespace > click the auto-generated codespace name
Alternately: clone and work in your preferred IDE

2. Configure class

Open `_class-config.yml` and fill in your class time, dates, instructor name, semester start, class meeting day(s), timezone, holidays, etc. These values propagate to the syllabus, lecture headers, navbar title, and release-date gating.


3. Set up R cloud environment for students OR skip to 4 (Posit Cloud; optional)
Out of the box, this repo sets up r labs as .qmd files that students can download and upload into their local machine. If you want a no-install startup, you can also set up Posit Cloud. 

Set up one Space and one invite link per semester. This project that contains all labs.

- Create a free account at https://posit.cloud
- Create a Space named e.g. `EDEP 625 Fall 2026`
- Inside the Space: **New Project → New Project from Git Repository** → paste this repo's URL. The project clones the repo so students see your `rlabs/` folder. **One project, not one per lab.**
- **Space → Settings → Members → copy the Space invite link.** This is the single link you share with students all semester
- In `rlabs/`, each lab page on the website includes an `Open in Posit Cloud` button linking to that one project URL — students click it, land in the project, and pick the current week's `.qmd` from `rlabs/`
- Each week's update flow: push the new `rlabs/wXX-*.qmd` to `main` → students hit `Tools → Version Control → Pull` in their Posit Cloud session → the new lab appears alongside prior weeks. Students see all released labs and select the current one.

(Optional) For authoring locally instead of in the codespace: R 4.4+ from https://cran.r-project.org, RStudio Desktop from https://posit.co/download/rstudio-desktop/, Quarto CLI from https://quarto.org/docs/get-started/, then in R: `install.packages(c("tidyverse", "lavaan", "yaml", "knitr", "rmarkdown"))`. The codespace already has all of this preinstalled.

4. Update site

After you make changes in the repo, they need to be updated on the student-facing site. 

Site auto-redeploys on git push. 

You can see the progress on the github UI under

actions > All workflows 

click the first one. When deploy is green, the url will show up and the updates are live. 

You. may need to do a hard refresh (cmd + R) 


# Teacher version of slides

To render and show the teacher version of the slides: 

```{bash}
# renders 
quarto render lectures/test_lecture.qmd --profile teacher
```



```{bash}
#downloads
download _teacher/lectures/test_lecture.html
```
in presentation, press S to see the speaker notes version. 

morph, cyorg, sketchy, slate, solar