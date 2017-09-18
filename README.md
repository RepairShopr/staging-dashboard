# Staging Dashboard

Just a basic rails app, do rails stuff like rake db:migrate and push to heroku

Go in and add your servers

Then you can do stuff like;

POST "/api/deploy_log" with some params like server_git_remote, git_branch, git_user, git_commit_message 

Also see the slackbot in `app/controllers/slack_controller.rb` - you can do stuff like

- /staging list
- /staging reserve staging4 8hrs need to test the new point of sale module!

Super dope
