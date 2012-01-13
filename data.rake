namespace :data do
  desc "Create initial content (users, connections, messages)"
  task :setup => ['data:users:create', 'data:connections:make', 'data:messages:send', 'data:groups:create']

  namespace :connections do
    desc "Make connections between each user and the next sequential user id"
    task :make => [:setuprequests] do
      @num_users_groups.times do |i|
        i = i+1
        nextuser = i % @num_users_groups + 1
  
        @logger.info "Requesting connection between User #{i} and User #{nextuser}"
        req = Net::HTTP::Post.new("/~user#{i}/contacts.invite.html")
        req.set_form_data({
          "fromRelationships" => "Classmate",
          "toRelationships" => "Classmate",
          "targetUserId" => "user#{nextuser}",
          "_charset_" => "utf-8"
        })
        req.basic_auth("user#{i}", "test")
        response = @localinstance.request(req)
        @logger.info response
  
        @logger.info "Accepting connection between User #{i} and User #{nextuser}"
        req = Net::HTTP::Post.new("/~user#{nextuser}/contacts.accept.html")
        req.set_form_data({
          "targetUserId" => "user#{i}",
          "_charset_" => "utf-8"
        })
        req.basic_auth("user#{nextuser}", "test")
        response = @localinstance.request(req)
      end
    end

    desc "Create tons of connections for each user"
    task :maketons => [:setuprequests] do
      @num_users_groups.times do |i|
        i = i+1
        (@num_users_groups-1).times do |j|
          j=j+1
          unless i == j
            nextuser = j
            @logger.info "Requesting connection between User #{i} and User #{nextuser}"
            req = Net::HTTP::Post.new("/~user#{i}/contacts.invite.html")
            req.set_form_data({
              "fromRelationships" => "Classmate",
              "toRelationships" => "Classmate",
              "targetUserId" => "user#{nextuser}",
              "_charset_" => "utf-8"
            })
            req.basic_auth("user#{i}", "test")
            response = @localinstance.request(req)
            @logger.info response
    
            @logger.info "Accepting connection between User #{i} and User #{nextuser}"
            req = Net::HTTP::Post.new("/~user#{nextuser}/contacts.accept.html")
            req.set_form_data({
              "targetUserId" => "user#{i}",
              "_charset_" => "utf-8"
            })
            req.basic_auth("user#{nextuser}", "test")
            response = @localinstance.request(req)
          end
        end
      end
    end
  end

  # ===========================================
  # = Creating users and groups =
  # ===========================================
  namespace :groups do
    desc "Add a lot of users as members to a group"
    task :addallusers => [:setuprequests] do
      if (!(ENV["group"])) then
        @logger.info "Usage: rake adduserstogroup group=groupid-role num=numusers"
      else
        group = ENV["group"]
        @num_users_groups.times do |i|
          i = i+1
          @logger.info "joining user#{i} to #{group}"
          req = Net::HTTP::Post.new("/system/userManager/group/#{group}.update.json")
          req.set_form_data({
            ":member" => "user#{i}",
            ":viewer" => "user#{i}",
            "_charset_" => "utf-8"
          })
          req.basic_auth("admin", "admin")
          response = @localinstance.request(req)
          @logger.info response
        end
      end
    end
    
    desc "Create #{@num_users_groups} groups; Each is created by the user with the matching id"
    task :create => [:setuprequests] do
      @num_users_groups.times do |i|
        i = i+1
        @logger.info "Creating Group #{i}"
        req = Net::HTTP::Post.new("/system/world/create")
        json = {
          "id" => "group#{i}",
          "title" => "Group #{i}",
          "description" => "Group #{i} description",
          "joinability" => "yes",
          "visibility" => "public",
          "tags" => [],
          "worldTemplate" => "/var/templates/worlds/group/simple-group",
          "_charset_" => "utf-8",
          "usersToAdd" => [{
            "userid" => "user#{i}",
            "name" => "User #{i}",
            "firstname" => "User",
            "role" => "manager",
            "roleString" => "Manager",
            "creator" => "true"
          }]
        }
        req.set_form_data({ "data" => JSON.generate(json) })
        req.basic_auth("admin", "admin")
        response = @localinstance.request(req)
        @logger.info response
      end
    end
  end

  namespace :messages do
    desc "Send messages between users"
    task :send => [:setuprequests] do
      @num_users_groups.times do |i|
        i += 1
        nextuser = i % @num_users_groups + 1
  
        @logger.info "Sending internal message: user#{i} => user#{nextuser}"
        @logger.info send_internal_message("user#{i}", "user#{nextuser}", "test #{i} => #{nextuser}", "test body #{i} => #{nextuser}")
  
        @logger.info "Sending smtp message: user#{i} => user#{nextuser}"
        @logger.info send_smtp_message("user#{i}", "user#{nextuser}", "test #{i} => #{nextuser}", "test body #{i} => #{nextuser}")
  
        @logger.info "Sending internal message: user#{nextuser} => user#{i}"
        @logger.info send_internal_message("user#{nextuser}", "user#{i}", "test #{nextuser} => #{i}", "test body #{nextuser} => #{i}")
  
        @logger.info "Sending smtp message: user#{nextuser} => user#{i}"
        @logger.info send_smtp_message("user#{nextuser}", "user#{i}", "test #{nextuser} => #{i}", "test body #{nextuser} => #{i}")
      end
    end
  
    desc "Send lots of messages to the specified user, from the specified user"
    task :sendlots => [:setuprequests] do
      if (!(ENV["to"] && ENV["from"] && ENV["num"])) then
        @logger.info "Usage: rake sendlotsofmessages to=user1 from=user2 num=60"
      else
        to = ENV["to"]
        from = ENV["from"]
        num = ENV["num"].to_i
        @logger.info "Sending #{num} messages from #{from} to #{to}"
        num.times do |i|
          @logger.info send_internal_message("#{to}", "#{from}", "Message #{i} #{from} => #{to}", "Body of Message #{i} #{from} => #{to}")
        end
      end
    end
  end

  namespace :users do
    desc "Create #{@num_users_groups} users"
    task :create => [:setuprequests] do
      @num_users_groups.times do |i|
        i = i+1
        @logger.info "Creating User #{i}"
        req = Net::HTTP::Post.new("/system/userManager/user.create.html")
        req.set_form_data({
          ":name" => "user#{i}",
          "pwd" => "test",
          "pwdConfirm" => "test",
          "email" => "user#{i}@sakaiproject.invalid",
          "firstName" => "User",
          "lastName" => "#{i}",
          "locale" => "en_US",
          "timezone" => "America/Los_Angeles",
          "_charset_" => "utf-8",
          ":sakai:profile-import" => "{'basic': {'access': 'everybody', 'elements': {'email': {'value': 'user#{i}@sakaiproject.invalid'}, 'firstName': {'value': 'User'}, 'lastName': {'value': '#{i}'}}}}"
        })
        req.basic_auth("admin", "admin")
        response = @localinstance.request(req)
        @logger.info response
      end
    end
  end
end
