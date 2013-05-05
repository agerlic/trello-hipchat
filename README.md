Link Trello and HipChat
============================

based on [rasky/trello-hipchat](https://github.com/rasky/trello-hipchat).

Send Trello activities to your HipChat room.

This script will monitor one Trello board and send notifications
to one HipChat room.

Currently, the following Trello activities are notified:

   * Card Creation
   * Comments being added to a card 
   * Attachments being added to a card
   * Moves of cards between lists
   * Completion of checklist items within a card


How to install
==============
 
  * Run bundle to install dependencies
  * Copy the sample configuration from `trello-hipchat.yml.sample` to 
    `trello-hipchat.yml`.
  * Run trello-hipchat.rb within cron. You can use `crontab -e` to edit
    the current user's crontab file, and add a line like this to run
    the program every 5 minutes and redirect logs to syslog:

         */5 * * * ruby /path/to/trello-hipchat.rb 2>&1 | logger
