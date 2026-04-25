# Objective
Create a cross-platform application to view tricks in a sport from a database.

Users should be able to log in, track their progression of tricks, and submit new ones that an administrator can approve and modify if needed.

# Requirements
There should be a main page that shows all of the tricks categorized by difficulty tier.

Selecting a trick should show you all the information about the trick and allow you to watch an embedded video if a video is present for the trick.

# Data
Each trick should contain:
- id
- given name
- technical name
- difficulty tier
- date submitted
- data performed
- original performer
- preqrequisite trick ids
- description
- tips section
- video link
- start position
- end position

Each user account should be able to track:
- tricks performed
- consistency of each trick
# Tech Stack
Flutter should be used as this is intended for Android, iOS, and Web. I would like to use Supabase for the database.
