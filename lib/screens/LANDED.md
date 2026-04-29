# Landed
If a user selects a consistency that shows they've landed a trick I want them to be able to optionally select a few other things to collect data.
This data should get saved in the user_tricks table alongside their consistency. All of these new columns will be optional.
## Difficulty
Here we allow users to vote on what they believe the difficulty is. Follow the existing schema for difficulty (integer 1-30 visually shown to users as 1-10 with +/- modifiers)
## Leash Position
This refers to where the user likes to keep their highline leash for the trick. Use a smallint for this in the table and refer to it in the code via an enum.
- Frontside
- Backside
- Center
## Video Link
Users can submit a video link of them landing the trick if they want.