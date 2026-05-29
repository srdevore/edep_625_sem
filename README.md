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

To render and show the teacher version of the slides: 

```{bash}
# renders 
quarto render lectures/test_lecture.qmd --profile teacher
```

In this presentation, press S to see the speaker notes version. 




```{bash}
#downloads
download _teacher/lectures/test_lecture.html
```


