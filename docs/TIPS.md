# Tips
This page lists out tips for freestylers that aren't specific to individual tricks.
# Content
This should be an easily filterable view to show various tips submitted by community members that have been approved by admins.
# Types
This should be an enum represented by a smallint in the database.
- General
- Rigging
- Health
# Data
- id (int)
- title (string) - Main title of the tip
- header (string) - Short descriptive header below the title
- body (string) - Actual tip content
- status (bool) - Approval status (false = pending, true = approved)
- type (smallint) - What category this tip falls under (see Types)
- submitted_on (date)
- submitted_by (int) - User id of submitter
- approved_on (date)
- approved_by (int) - User id of approver
- last_updated (date)
- last_updated_by (int) - User id of last updater
# Visible Data
When viewing the list of tips all that should be visible are the title, header, and type. The body should be hidden until clicked on.

When viewing a specific tip the title, header, body, type, submitted_by, and submitted_on should be visible to users.
# Admins
Can see posts in their admin panel and approve, edit, or decline them. Declining should delete the row entirely.
# Users
Can submit a tip on the tips screen for approval.
# Notes
The body of the tip should be able to embed content such as an image hosted on another site or a video from a video hosting service like YouTube. Supporting Markdown would be a plus.