require 'rubygems'
require 'git'
require 'net/http'
require 'uri'
require 'curb'

projects = [{"path" => "../sparsemapcontent"},
  {"path" => "../solr"},
  {"path" => "../nakamura", "remote" => "sakaiproject"}]

UI = "../3akai-ux"

JAVA_OPTS = "-Xms256m -Xmx1024m -XX:PermSize=64m -XX:MaxPermSize=512m"

CLEAN_FILES = ["./derby.log", "./sling", "./activemq-data", "./store"]

task :clean do
  touch CLEAN_FILES
  rm_r CLEAN_FILES
end

task :cleanui do
  system("cd #{UI} && mvn clean")
end

task :update do
  for p in projects do
    g = Git.open(p["path"])
    remote = p["remote"] || "origin"
    branch = p["branch"] || "master"
    puts g.pull(remote, branch)
  end
end

task :rebuild do
  system("cd #{UI} && mvn clean install")
  for p in projects do
    system("cd #{p["path"]} && mvn clean install -Dmaven.test.skip")
  end
end

task :fastrebuild do
  system("cd ../nakamura/app && mvn clean install -Dmaven.test.skip")
end

task :run => [:kill] do
  pid = fork{exec("java #{JAVA_OPTS} -jar ../nakamura/app/target/org.sakaiproject.nakamura.app-0.11-SNAPSHOT.jar")}
  Process.detach(pid)
  File.open(".nakamura.pid", 'w') {|f| f.write(pid) }
end

task :kill do
  pidfile = ".nakamura.pid"
  if File.exists?(pidfile)
    File.open(pidfile, "r") do |f|
      while (line = f.gets) do
        pid = line.to_i
        Process.kill("HUP", pid)
        while (sleep 5) do
          begin
            Process.getpgid(pid)
          rescue
            break
          end
        end
      end
    end
    rm pidfile
  end
end

# ==================
# = Set FSResource =
# ==================

task :setfsresource => [:setuprequests] do
  # set fsresource paths
  # has to be a single URL POST, no post params (weird, I know)
  uiabspath = `cd #{UI} && pwd`.chomp
  ["/dev", "/devwidgets", "/tests"].each do |dir|
    url = "/system/console/configMgr/[Temporary%20PID%20replaced%20by%20real%20PID%20upon%20save]"
    url += "?propertylist=provider.roots,provider.file,provider.checkinterval"
    url += "&provider.roots=#{dir}"
    url += "&provider.file=#{uiabspath}#{dir}"
    url += "&provider.checkinterval=1000"
    url += "&apply=true"
    url += "&factoryPid=org.apache.sling.fsprovider.internal.FsResourceProvider"
    url += "&action=ajaxConfigManager"
    req = Net::HTTP::Post.new(url)
    req.basic_auth("admin", "admin")
    response = @localinstance.request(req)
    puts response.inspect
  end
end

# ===========================================
# = Creating users and groups =
# ===========================================

# Fix header setting for Net::HTTP
module Net::HTTPHeader
  def initialize_http_header(initheader)
      @header = { "Referer" => ["http://localhost:8080"] }
      return unless initheader
      initheader.each do |key, value|
        warn "net/http: warning: duplicated HTTP header: #{key}" if key?(key) and $VERBOSE
        @header[key.downcase] = [value.strip]
      end
  end
end

task :setuprequests do
  @uri = URI.parse("http://localhost:8080")
  @localinstance = Net::HTTP.new(@uri.host, @uri.port)
end

task :createusers => [:setuprequests] do
  5.times do |i|
    i = i+1
    puts "Creating User #{i}"
    req = Net::HTTP::Post.new("/system/userManager/user.create.html")
    req.set_form_data({
      ":name" => "user#{i}",
      "pwd" => "test",
      "pwdConfirm" => "test",
      "email" => "user#{i}@sakaiproject.invalid",
      ":sakai:pages-template" => "/var/templates/site/defaultuser",
      "firstName" => "User",
      "lastName" => "#{i}",
      "locale" => "en_US",
      "timezone" => "America/Los_Angeles",
      "_charset_" => "utf-8",
      "sakai:profile-import" => "{'basic': {'access': 'everybody', 'elements': {'email': {'value': 'user#{i}@sakaiproject.invalid'}, 'firstName': {'value': 'User'}, 'lastName': {'value': '#{i}'}}}}"
    })
    req.basic_auth("admin", "admin")
    response = @localinstance.request(req)
    puts response
  end
end

task :makeconnections => [:setuprequests] do
  5.times do |i|
    i = i+1
    nextuser = i%5+1

    puts "Requesting connection between User #{i} and User #{nextuser}"
    req = Net::HTTP::Post.new("/~user#{i}/contacts.invite.html")
    req.set_form_data({
      "fromRelationships" => "Classmate",
      "toRelationships" => "Classmate",
      "targetUserId" => "user#{nextuser}",
      "_charset_" => "utf-8"
    })
    req.basic_auth("user#{i}", "test")
    response = @localinstance.request(req)
    puts response

    puts "Accepting connection between User #{i} and User #{nextuser}"
    req = Net::HTTP::Post.new("/~user#{nextuser}/contacts.accept.html")
    req.set_form_data({
      "targetUserId" => "user#{i}",
      "_charset_" => "utf-8"
    })
    req.basic_auth("user#{nextuser}", "test")
    response = @localinstance.request(req)
  end
end

task :creategroups => [:setuprequests] do
  5.times do |i|
    i = i+1
    puts "Creating Group #{i}"
    req = Net::HTTP::Post.new("/system/userManager/group.create.html")
    req.set_form_data({
      ":name" => "group#{i}",
      ":sakai:pages-template" => "/var/templates/site/defaultgroup",
      ":sakai:manager" => "user#{i}",
      "sakai:group-title" => "Group #{i}",
      "sakai:group-description" => "Group #{i} description",
      "sakai:group-joinable" => "yes",
      "sakai:group-visible" => "public",
      "sakai:pages-visible" => "public",
      "_charset_" => "utf-8"
    })
    req.basic_auth("admin", "admin")
    response = @localinstance.request(req)
    puts response

    ["anonymous", "everyone"].each do |grant|
      req = Net::HTTP::Post.new("/~group#{i}.modifyAce.html")
      req.set_form_data({
        "principalId" => "#{grant}",
        "privilege@jcr:read" => "granted",
        "_charset_" => "utf-8"
      })
      req.basic_auth("admin", "admin")
      response = @localinstance.request(req)
      puts response
    end
  end
end

task :build => [:update, :rebuild]
task :setup => [:createusers, :creategroups, :makeconnections, :setfsresource, :cleanui]
task :default => [:clean, :build, :run]
