# Description:
#   Karma script which keeps track of positive and negative points
#

module.exports = (robot) ->
  # Get the botname from the environment
  botname = process.env.HUBOT_SLACK_BOTNAME
  # symbolic match for a @USER++
  plusplus_re = /@([a-z0-9_\-\.]+)\+{2,}/ig
  # symbolic match for a @USER--
  minusminus_re = /@([a-z0-9_\-\.]+)\-{2,}/ig
  # symoblic match for either @USER++ or @USER--
  plusplus_minusminus_re = /@([a-z0-9_\-\.]+)[\+\-]{2,}/ig
  
  # Listen for either @USER++ or @USER-- to add or remove karma
  robot.hear plusplus_minusminus_re, (msg) ->
     res = ''

     while (match = plusplus_re.exec(msg.message))
         # USER++ becomes the data key for storing positive karma - "clever points"
         user = match[1].replace(/\-+$/g, '')+"++"
         
         # Check the username of the message sender and the username to apply karma to
         if msg.message.user.name == match[1].replace(/\-+$/g, '')
            # If they are the same, stop notify them and add negative karma

            # Create the correct user key
            user = match[1].replace(/\-+$/g, '')+"--"
            # First get the USER-- current score and increment
            count = (robot.brain.get(user) or 0) + 1
            # Set the new score with the key in the robot brain
            robot.brain.set user, count
            # Calculate the total score for leaderboards
            totscore = (robot.brain.get(match[1].replace(/\-+$/g, '')+"++") or 0) - count
            # Set the total score with the user name as key, for leaderboards
            robot.brain.set match[1].replace(/\-+$/g, ''), totscore
            # Set reply message notifying user of their stupid actions
            res += "You can't give yourself karma!\nhttps://i.imgur.com/lFc9wzr.jpg\n@#{user} [ouch! stupidity now at #{count}]\n"
         else
            # If the user is giving positive karma to another person, continue
            
            # First get the USER-- current score and increment
            count = (robot.brain.get(user) or 0) + 1
            # Set the new score with the key in the robot brain
            robot.brain.set user, count
            # Calculate the total score for leaderboards
            totscore = count - (robot.brain.get(match[1].replace(/\-+$/g, '')+"--") or 0)
            # Set the total score with the user name as key, for leaderboards
            robot.brain.set match[1].replace(/\-+$/g, ''), totscore
            # Set reply message
            res += "@#{user} [woot! cleverness now at #{count}]\n"
     
     while (match = minusminus_re.exec(msg.message))
         # USER-- becomes the data key for storing negative karma - "stupid points"

         # Create the correct user key
         user = match[1].replace(/\-+$/g, '')+"--"
         # First get the USER-- current score and increment
         count = (robot.brain.get(user) or 0) + 1
         # Set the new score with the key in the robot brain
         robot.brain.set user, count
         # Calculate the total score for leaderboards
         totscore = (robot.brain.get(match[1].replace(/\-+$/g, '')+"++") or 0) - count
         # Set the total score with the user name as key, for leaderboards
         robot.brain.set match[1].replace(/\-+$/g, ''), totscore
         # Set reply message notifying user of their stupid actions
         res += "@#{user} [ouch! stupidity now at #{count}]\n"
     
     # Send the response
     msg.send res.replace(/\s+$/g, '')

  # Print the score of another user
  robot.hear /// #{botname} \s+ @([a-z0-9_\-\.]+) ///i, (msg) ->
     # When the bot hears its own name, followed by another username, it will display the current
     # karma for that user.
     
     # Create keys for stupid points and clever points and collect the score
     user = msg.match[1].replace(/\-+$/g, '')
     s_user = user+"--"
     s_count = (robot.brain.get(s_user) or 0)

     c_user = user+"++"
     c_count = (robot.brain.get(c_user) or 0)

     score = c_count - s_count
     
     # As a double check, update the leaderboard score
     robot.brain.set user, score

     # If the results return **something**
     if score != null 
         # Build the return message
         s_point_label = if s_count == 1 then "point" else "points"
         c_point_label = if c_count == 1 then "point" else "points"
         msg.send "@#{user}: #{s_count} stupid " + s_point_label + " and #{c_count}" + " clever " + c_point_label + ". Total score: " + score
     else
         msg.send "@#{user} has no karma"

  robot.respond /leaderboard/i, (msg) ->
     # When the bot is asked for the leaderboard e.g.:
     # => @karmabot: leaderboard
     
     # Get a list of the users from the brain data
     users = robot.brain.data._private
     
     tuples = []
     
     for username, score of users
        # If username contains "+"...
        if (username.indexOf("+") > -1)
            # ...do nothing
            robot.logger.debug "contains +"
        # If username contains "-"...
        else if (username.indexOf("-") > -1)
            # ...do nothing
            robot.logger.debug "contains -"
        else
            # Add to the list
            tuples.push([username, score])
     
     # If no one has any karma...
     if tuples.length == 0
        msg.send "The lack of karma is too damn high!"
        return

     # Sort the end into descending order
     tuples.sort (a, b) ->
        if a[1] > b[1]
           return -1
        else if a[1] < b[1]
           return 1
        else
           return 0

     str = ''
     
     # The limit to who is included in the leaderboard
     #limit = 5
     
     # For each user in the tuples
     for i in [0...tuples.length]
        # Get the username and score
        username = tuples[i][0]
        points = tuples[i][1]

        # get the clever points
        c_points = robot.brain.get(username+"++") or 0

        # stupid points
        s_points = robot.brain.get(username+"--") or 0
        
        point_label = if points == 1 then "point" else "points"
        
        s_point_label = if s_points == 1 then "point" else "points"
        c_point_label = if c_points == 1 then "point" else "points"
        
        # Create the message strings for this user
        leader = if i == 0 then "All hail supreme leader!" else ""
        newline = if i < Math.min(limit, tuples.length) - 1 then '\n' else ''
        str += "##{i+1} @#{username} [#{points} " + point_label + "] " + "(#{s_points} stupid #{s_point_label} and #{c_points}" + " clever #{c_point_label}) " + leader + newline

     # Send the message
     msg.send(str)
    
  # Simple test response to check if the bot is alive
  robot.respond /wake up/i, (msg) ->
        msg.reply "I'm awake!"

  # Error message list
  errMessage = ["*ERROR: YOU MUST CONSTRUCT ADDITIONAL PYLONS*"]
  
  # Admin Test
  robot.respond /admin test/i, (msg) ->
        res = ""
        admin_name = process.env.HUBOT_KARMA_ADMIN_NAME
        # Check who's requesting the karma clear...
        if (msg.message.user.name == admin_name)
            #...if the usernames match, continue
            res+= "You have the power!"
        else
            #...if they dont, display an error message
            res += msg.random errMessage
        msg.send res  
  
  # This command will clear the karma score as long as you are the correct user
  # If you aren't the right user, it will display an error message
  robot.respond /clear karma/i, (msg)  ->
        res = ""
        admin_name = process.env.HUBOT_KARMA_ADMIN_NAME
        # Check who's requesting the karma clear...
        if (msg.message.user.name == admin_name)
            #...if the usernames match, continue
            users = robot.brain.data._private
            for username of users
                robot.brain.remove(username)
            res += "http://i.imgur.com/iS1Ntdx.gif\nStupidity and cleverness has been reset. Let's try not to be *quite* so stupid this time, shall we?"
        else
            #...if they dont, display an error message
            res += msg.random errMessage
        msg.send res
