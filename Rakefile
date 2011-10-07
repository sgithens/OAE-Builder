require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'net/http'
require 'uri'
require './messaging'
require 'fileutils'
require 'socket'
require 'rexml/document'
require 'rexml/xpath'
require 'zlib'
require 'archive/tar/minitar'

# KERN-2260
if RUBY_VERSION =~ /^1\.8/
  class Dir
    class << self
      def exists? (path)
        File.directory?(path)
      end
      alias_method :exist?, :exists?
    end
  end
end

# Make sure we always start from where the Rakefile is
Dir.chdir(File.dirname(__FILE__))

builddir = ENV['builddir']
if not builddir then
  builddir = ".."
end 

sparse = {"path" => "#{builddir}/sparsemapcontent", "repository" => "git://github.com/sakaiproject/sparsemapcontent.git", "branch" => "master", "localbranch" => "master"}
solr = {"path" => "#{builddir}/solr", "repository" => "git://github.com/sakaiproject/solr.git", "branch" => "master", "localbranch" => "master"}
nakamura = {"path" => "#{builddir}/nakamura", "repository" => "git://github.com/sakaiproject/nakamura.git", "branch" => "master", "localbranch" => "master", "port" => "8080"}

ui = {"path" => "#{builddir}/3akai-ux", "repository" => "git://github.com/sakaiproject/3akai-ux.git", "branch" => "master", "localbranch" => "master"}
fsresources = ["/dev", "/devwidgets", "/tests"]

cle = {"path" => "#{builddir}/sakai-cle", "repository" => "https://source.sakaiproject.org/svn/sakai/branches/sakai-2.8.1", "port" => "8880", "ajp_port" => "8889" }
hybrid = {"path" => "#{cle["path"]}/hybrid", "repository" => "https://source.sakaiproject.org/svn/hybrid/branches/hybrid-1.1.x"}

db = {"driver" => "derby", "user" => "sakaiuser", "password" => "ironchef", "db" => "nakamura"}

tomcat = {"mirror" => "apache.mirrors.tds.net", "version" => "5.5.34"}

hostname = Socket.gethostname
# don't worry, no data gets sent to this google ip
# Since UDP is a stateless protocol connect() merely makes a system call
# which figures out how to route the packets
ip = UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }

templatePath = "./templates"

num_users_groups = 5
update_ui = true

Mustache.template_path = "./templates"

# setup java command and options
java_exec = "java"
java_opts = "-Xms256m -Xmx1024m -XX:PermSize=64m -XX:MaxPermSize=512m"
java_debug_opts = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8500,server=y,suspend=n"
java_debug = false

app_opts = ""

# Custom app jar file pattern
app_file = "#{nakamura["path"]}/app/target/org.sakaiproject.nakamura.app-*.jar"

# setup maven command and options
mvn_exec = "mvn"
mvn_opts = "-B -e -Dmaven.test.skip"
mvn_cmd = "#{mvn_exec} #{mvn_opts}"

# read in and evaluate an external settings file
eval File.open('./settings.rb').read if File.exists?('./settings.rb')

server = [sparse, solr, nakamura]

java_cmd = "#{java_exec} #{java_opts}"
if java_debug
  java_cmd += " #{java_debug_opts}"
end

if db["driver"] == "mysql"
  Bundler.require(:mysql)
end

CLEAN_FILES = ["./derby.log", "./sling", "./activemq-data", "./store", "./sakai2-demo", "./tmp", "./ui-conf"]

puts "Using settings:"
puts "JAVA: #{java_cmd}"
puts "MVN:  #{mvn_cmd}"
p ui
p server
puts ""

# include external rake file for custom tasks
Dir.glob('*.rake').each { |r| import r }

########################
##  Task Definitions  ##
########################
desc "Clone the repositories needed to build everything."
task :clone do
  cmds = []
  if ui.has_key? "path"
    if File.directory? ui["path"]
      puts "#{ui["path"]} already exists."
    elsif ui.has_key? "repository"
      puts "Cloning #{ui["repository"]} to #{ui["path"]}"
      Git.clone(ui["repository"], ui["path"])
      if ui.has_key? "remote" and ui["remote"] != "origin"
        cmds << "(cd #{ui["path"]} && git remote rename origin #{ui["remote"]})"
      end
    end
  end

  for p in server
    if p.has_key? "path"
      if File.directory? p["path"]
        puts "#{p["path"]} already exists."
      elsif p.has_key? "repository"
        puts "Cloning #{p["repository"]} to #{p["path"]}"
        Git.clone(p["repository"], p["path"])
        if p.has_key? "remote" and ui["remote"] != "origin"
          cmds << "(cd #{p["path"]} && git remote rename origin #{p["remote"]})"
        end
      end
    end
  end

  if !cmds.empty?
    puts "\nPlease issue the following commands:"
    cmds.each do |cmd|
      puts cmd
    end
    puts ""
  end
end

desc "Checkout CLE from SVN"
task :clone_cle do
  if cle.has_key? "path"
    if File.directory? cle["path"]
      puts "#{cle["path"]} already exists."
    elsif cle.has_key? "repository"
      system("svn -q checkout #{cle["repository"]} #{cle["path"]}")
      if hybrid.has_key? "path" and hybrid.has_key? "repository"
        system("svn -q checkout #{hybrid["repository"]} #{hybrid["path"]}")
      end
    end
  end
end

desc "Download Tomcat tarball"
task :dl_tomcat do
  tomcat["filename"] = "apache-tomcat-#{tomcat["version"]}.tar.gz"
  if not File.exists? tomcat["filename"]
    puts "Downloading #{tomcat["filename"]} from #{tomcat["mirror"]}"
    Net::HTTP.start(tomcat["mirror"]) do |http|
      resp = http.get("/tomcat/tomcat-5/v#{tomcat["version"]}/bin/#{tomcat["filename"]}")
      open("#{tomcat["filename"]}", "wb") do |file|
        file.write(resp.body)
      end
    end
  end
end

desc "Unpack Tomcat tarball"
task :unpack_tomcat => :dl_tomcat do
  puts "Unpacking #{tomcat["filename"]}"
  Dir.chdir(File.dirname(tomcat["filename"])) do
    tgz = Zlib::GzipReader.new(File.open(tomcat["filename"], 'rb'))
    Archive::Tar::Minitar.unpack(tgz, './tmp')
    FileUtils.mv("./tmp/apache-tomcat-#{tomcat["version"]}", "./sakai2-demo")
  end
end

desc "Configure the CLE to use NakamuraUserDirectoryProvider"
task :config_directoryprovider do #=> [:build_cle] do
  cXML = ""
  components = 'sakai2-demo/components/sakai-provider-pack/WEB-INF/components.xml'
  File.open(components) do |f|
    cXML = REXML::Document.new(f)
    beans = REXML::XPath.first(cXML, '//beans')
    bean = beans.add_element("bean", {
      "id" => "org.sakaiproject.user.api.UserDirectoryProvider",
      "class" => "org.sakaiproject.provider.user.NakamuraUserDirectoryProvider",
      "init-method" => "init"
    })
    prop1 = bean.add_element("property", {"name" => "threadLocalManager"})
    prop1.add_element("ref", {
      "bean" => "org.sakaiproject.thread_local.api.ThreadLocalManager"
    })
    prop2 = bean.add_element("property", {
      "name" => "serverConfigurationService"
    })
    prop2.add_element("ref", {
      "bean" => "org.sakaiproject.component.api.ServerConfigurationService"
    })
  end

  File.open(components, "w+") do |f|
    cXML.write f
  end

  FileUtils.rm("sakai2-demo/components/sakai-provider-pack/WEB-INF/components-demo.xml")
end

desc "Clean files and directories from a previous server start."
task :clean => [:kill, :clean_mysql] do
  touch CLEAN_FILES
  rm_r CLEAN_FILES
end

desc "Clean the build artifacts generated by the UI build."
task :cleanui do
  Dir.chdir ui["path"] do
    system("#{mvn_cmd} clean")
  end
end

desc "Clean the mysql db."
task :clean_mysql do
  if db["driver"] == "mysql"
    my = Mysql::new("localhost", db["user"], db["password"])
    my.query("drop database if exists #{db["db"]}")
    my.query("create database #{db["db"]} default character set 'utf8'")
  end
end

desc "[Alias to :update]"
task :up => :update do
end

desc "Update (git pull) all Nakamura and UI projects."
task :update do
  if update_ui then
    g = Git.open(ui["path"])
    remote = ui["remote"] || "origin"
    branch = remote + "/" + (ui["branch"] || "master")
    localbranch = ui["localbranch"] || "master"
    puts "Checkout out #{localbranch}"
    g.checkout(g.branch(localbranch))
    puts "Updating #{ui["path"]}:#{branch}"
    puts g.pull(remote, branch)
  end

  for p in server do
    g = Git.open(p["path"])
    remote = p["remote"] || "origin"
    branch = remote + "/" + (p["branch"] || "master")
    localbranch = p["localbranch"] || "master"
    puts "Checkout out #{localbranch}"
    g.checkout(g.branch(localbranch))
    puts "Updating #{p["path"]}:#{branch}"
    puts g.pull(remote, branch)
  end
end

desc "Update the SVN checkout of CLE"
task :update_cle do
  if cle.has_key? "path" and File.directory? cle["path"]
    puts "Updating #{cle["path"]}"
    system("svn -q update #{cle["path"]}")
    if hybrid.has_key? "path" and File.directory? hybrid["path"]
      puts "Updating #{hybrid["path"]}"
      system("svn -q update #{hybrid["path"]}")
    end
  end
end

desc "Rebuild the UI and Nakamura projects, using a release build for the UI."
task :release_build do
  Dir.chdir ui["path"] do
    system("#{mvn_cmd} clean install -P sakai-release")
  end
  for p in server do
    Dir.chdir p["path"] do
      system("#{mvn_cmd} clean install")
    end
  end
end

desc "Build the UI and Nakamura projects, make a webstart"
task :webstart => [:rebuild] do
  Dir.chdir nakamura["path"] do
    system("#{mvn_cmd} clean install")
  end
end

desc "Rebuild the UI and Nakamura projects."
task :rebuild => [:config] do
  Dir.chdir ui["path"] do
    system("#{mvn_cmd} clean install")
  end
  for p in server do
    Dir.chdir p["path"] do
      system("#{mvn_cmd} clean install")
    end
  end
end

desc "Rebuild just the app bundle to include any changed bundles without building everything."
task :fastrebuild => [:config] do
  Dir.chdir "#{builddir}/nakamura/app" do
    system("#{mvn_cmd} clean install")
  end
end

desc "Rebuild the CLE and its hybrid module"
task :rebuild_cle => [:config_cle] do
  deploydir = "#{Dir.pwd}/sakai2-demo"
  Dir.chdir(cle["path"]) do
    system("#{mvn_cmd} -Dmaven.tomcat.home=#{deploydir} clean install sakai:deploy")
  end
  Dir.chdir(hybrid["path"]) do
    system("#{mvn_cmd} -Dmaven.tomcat.home=#{deploydir} clean install sakai:deploy")
  end
end

desc "[Alias to :run]"
task :start => :run do
end

desc "Start a running server. Will kill the previously started server if still running."
task :run => [:kill] do
  Dir[app_file].each do |path|
    if !path.end_with? "-sources.jar" then
      app_file = path
    end
  end
  abort("Unable to find application version") if app_file.nil?

  CMD = "#{java_cmd} -jar #{app_file} #{app_opts}"
  p "Starting server with #{CMD}"

  pid = fork { exec( CMD ) }
  Process.detach(pid)
  File.open(".nakamura.pid", 'w') {|f| f.write(pid) }
end

desc "Start a CLE server. Will kill the previously started server if still running."
task :run_cle => [:kill_cle] do
  ENV['CATALINA_PID'] = ".sakai-cle.pid"
  pid = fork { exec( "./sakai2-demo/bin/startup.sh" ) }
  Process.detach(pid)
end

def kill(pidfile, signal="TERM")
  if File.exists?(pidfile)
    File.open(pidfile, "r") do |f|
      while (line = f.gets) do
        pid = line.to_i
        begin
          Process.kill(signal, pid)
          puts "Killing pid #{pid}"
          while (sleep 5) do
            begin
              Process.getpgid(pid)
            rescue
              break
            end
          end
        rescue
          puts "Didn't find pid #{pid}"
        end
      end
    end
    rm pidfile
  end
end

desc "[Alias to :kill]"
task :stop => :kill do
end

desc "Kill the previously started server."
task :kill do
  kill(".nakamura.pid")
end

desc "Kill the CLE server."
task :kill_cle do
  kill(".sakai-cle.pid", 9)
end

desc "Configure the CLE server"
task :config_cle => [:unpack_tomcat] do
  class SakaiProperties < Mustache
  end
  sakaiprops = SakaiProperties.new
  sakaiprops[:s2_tag] = cle["repository"].split('/')[-1]
  sakaiprops[:hybrid_tag] = hybrid["repository"].split('/')[-1]
  Dir.chdir(cle["path"]) do
    sakaiprops[:repo_rev] = /Revision.*$/.match(`svn info`).to_s
  end
  sakaiprops[:server] = hostname
  sakaiprops[:build_date] = Time.now
  sakaiprops[:k2_http_port] = nakamura["port"]
  sakaiprops[:external_ip] = ip
  if not Dir.exists? "./sakai2-demo/sakai"
    Dir.mkdir("./sakai2-demo/sakai")
  end
  File.open("./sakai2-demo/sakai/sakai.properties", 'w') do |f|
    f.write(sakaiprops.render())
  end

  sXML = ""
  # Read the default server.xml into memory replacing the default ports with the configured ones
  File.open("./sakai2-demo/conf/server.xml") do |f|
    sXML = REXML::Document.new f
    sXML.elements.each("Server/Service/Connector") do |el|
      if el.attributes["port"] == "8080"
        el.attributes["port"] = cle["port"]
      elsif el.attributes["port"] == "8009"
        el.attributes["port"] = cle["ajp_port"]
      end
    end
  end

  # Write the new server.xml
  File.open("./sakai2-demo/conf/server.xml", "w+") do |f|
    sXML.write f
  end

  File.open("./sakai2-demo/bin/setenv.sh", "w+") do |f|
    f.write("export JAVA_OPTS='-server -Xms512m -Xmx1028m -XX:NewSize=192m -XX:MaxNewSize=384m -XX:PermSize=96m -XX:MaxPermSize=512m'")
  end
end

desc "Configure nakamura"
task :config do
  FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/proxy")
  FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/http/usercontent")
  FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/lite/storage/jdbc")
  class TrustedLogin < Mustache
  end
  tl = TrustedLogin.new
  tl["httpd_port"] = cle["port"]
  File.open("./sling/config/org/sakaiproject/nakamura/proxy/TrustedLoginTokenProxyPreProcessor.config", 'w') do |f|
    f.write(tl.render())
  end

  class ServerProtection < Mustache
  end
  sp = ServerProtection.new
  sp["server"] = hostname
  sp["httpd_port"] = nakamura["port"]
  File.open("./sling/config/org/sakaiproject/nakamura/http/usercontent/ServerProtectionServiceImpl.config", 'w') do |f|
    f.write(sp.render())
  end

  if db["driver"] == "mysql"
    class StoragePool < Mustache
    end
    stp = StoragePool.new
    stp["dbuser"] = db["user"]
    stp["dbpass"] = db["password"]
    File.open("./sling/config/org/sakaiproject/nakamura/lite/storage/jdbc/JDBCStorageClientPool.config", 'w') do |f|
      f.write(stp.render())
    end
  end
end

def enableInPortal(path, server)
  json = ""
  resp = RestClient.get("#{server}/#{path}")
  json = JSON.parse(resp.to_str)
  json["personalportal"] = true
  postJsonAsFile(path, JSON.generate(json), server)
end

def enableInSakaiDoc(path, server)
  json = ""
  resp = RestClient.get("#{server}/#{path}")
  json = JSON.parse(resp.to_str)
  json["sakaidocs"] = true
  postJsonAsFile(path, JSON.generate(json), server)
end

def postJsonAsFile(path, json, server)
  filename = File.basename(path)
  # I'd rather not write out an intermediary file here, but I'm not sure it's
  # possible to avoid it.
  if not Dir.exists?("./tmp")
    Dir.mkdir("./tmp")
  end
  File.open("./tmp/#{filename}", "w") do |temp|
    temp.write(json)
  end

  RestClient.post("#{server}/#{File.dirname(path)}", filename => File.new("./tmp/#{filename}"), "#{filename}@TypeHint" => "nt:file")
  File.delete("./tmp/#{filename}")
end

desc "Enable Hybrid Widgets"
task :enable_hybrid do
  enableInPortal("devwidgets/mysakai2/config.json", "http://admin:admin@localhost:#{nakamura["port"]}")
  enableInSakaiDoc("devwidgets/basiclti/config.json", "http://admin:admin@localhost:#{nakamura["port"]}")
  enableInSakaiDoc("devwidgets/sakai2tools/config.json", "http://admin:admin@localhost:#{nakamura["port"]}")
end

# ==================
# = Set FSResource =
# ==================

def setFsResource(slingpath, fspath)
  # set fsresource paths
  # has to be a single URL POST, no post params (weird, I know)
  url = "/system/console/configMgr/[Temporary%20PID%20replaced%20by%20real%20PID%20upon%20save]"
  url += "?propertylist=provider.roots,provider.file,provider.checkinterval"
  url += "&provider.roots=#{slingpath}"
  url += "&provider.file=#{fspath}"
  url += "&provider.checkinterval=1000"
  url += "&apply=true"
  url += "&factoryPid=org.apache.sling.fsprovider.internal.FsResourceProvider"
  url += "&action=ajaxConfigManager"
  req = Net::HTTP::Post.new(url)
  req.basic_auth("admin", "admin")
  response = @localinstance.request(req)
  puts response.inspect
end

desc "Set the FSResource configs to use the UI files on disk."
task :setfsresource => [:setuprequests] do
  uiabspath = File.expand_path(ui["path"])
  fsresources.each do |dir|
    setFsResource(dir, "#{uiabspath}#{dir}")
  end
end

desc "Set fsresource just for the UI config"
task :setfsresource_uiconf => [:setuprequests] do
  if not Dir.exists?("./ui-conf")
    FileUtils.cp_r("#{ui["path"]}/dev/configuration/", "./ui-conf")
    FileUtils.cp("./templates/config_custom.js", "./ui-conf/")
  end
  setFsResource("/dev/configuration", "./ui-conf")
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
  @uri = URI.parse("http://localhost:#{nakamura["port"]}")
  @localinstance = Net::HTTP.new(@uri.host, @uri.port)
end

desc "Create #{num_users_groups} users."
task :createusers => [:setuprequests] do
  num_users_groups.times do |i|
    i = i+1
    puts "Creating User #{i}"
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
    puts response
  end
end

desc "Make connections between each user and the next sequential user id."
task :makeconnections => [:setuprequests] do
  num_users_groups.times do |i|
    i = i+1
    nextuser = i % num_users_groups + 1

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

desc "Create tons of connections for each user"
task :maketonsofconnections => [:setuprequests] do
  num_users_groups.times do |i|
    i = i+1
    (num_users_groups-1).times do |j|
      j=j+1
      unless i == j
        nextuser = j
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
  end
end

desc "Create #{num_users_groups} groups. Each is created by the user with the matching id."
task :creategroups => [:setuprequests] do
  num_users_groups.times do |i|
    i = i+1
    puts "Creating Group #{i}"
    req = Net::HTTP::Post.new("/system/userManager/group.create.html")
    req.set_form_data({
      ":name" => "group#{i}",
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

desc "Create 5 groups that are joinable."
task :createjoinablegroups => [:setuprequests] do
  5.times do |i|
    i = i+1
    puts "Creating Group #{i}"
    req = Net::HTTP::Post.new("/system/userManager/group.create.html")
    req.set_form_data({
      ":name" => "groupjoinable#{i}",
      ":sakai:manager" => "user#{i}",
      "sakai:group-title" => "Group Joinable #{i}",
      "sakai:group-description" => "Group Joinable #{i} description",
      "sakai:group-joinable" => "withauth",
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

desc "Send messages between users."
task :sendmessages => [:setuprequests] do
  num_users_groups.times do |i|
    i += 1
    nextuser = i % num_users_groups + 1

    puts "Sending internal message: user#{i} => user#{nextuser}"
    puts send_internal_message "user#{i}", "user#{nextuser}", "test #{i} => #{nextuser}", "test body #{i} => #{nextuser}"

    puts "Sending smtp message: user#{i} => user#{nextuser}"
    puts send_smtp_message "user#{i}", "user#{nextuser}", "test #{i} => #{nextuser}", "test body #{i} => #{nextuser}"

    puts "Sending internal message: user#{nextuser} => user#{i}"
    puts send_internal_message "user#{nextuser}", "user#{i}", "test #{nextuser} => #{i}", "test body #{nextuser} => #{i}"

    puts "Sending smtp message: user#{nextuser} => user#{i}"
    puts send_smtp_message "user#{nextuser}", "user#{i}", "test #{nextuser} => #{i}", "test body #{nextuser} => #{i}"
  end
end

desc "Send lots of messages to the specified user, from the specified user"
task :sendlotsofmessages => [:setuprequests] do
  if (!(ENV["to"] && ENV["from"] && ENV["num"])) then
    puts "Usage: rake sendlotsofmessages to=user1 from=user2 num=60"
  else
    to = ENV["to"]
    from = ENV["from"]
    num = ENV["num"].to_i
    puts "Sending #{num} messages from #{from} to #{to}"
    num.times do |i|
      puts send_internal_message "#{to}", "#{from}", "Message #{i} #{from} => #{to}", "Body of Message #{i} #{from} => #{to}"
    end
  end
end

desc "Add a lot of users as members to a group"
task :addalluserstogroup => [:setuprequests] do
  if (!(ENV["group"])) then
    puts "Usage: rake adduserstogroup group=groupid-role num=numusers"
  else
    group = ENV["group"]
    num_users_groups.times do |i|
      i = i+1
      puts "joining user#{i} to #{group}"
      req = Net::HTTP::Post.new("/system/userManager/group/#{group}.update.json")
      req.set_form_data({
        ":member" => "user#{i}",
        ":viewer" => "user#{i}",
        "_charset_" => "utf-8"
      })
      req.basic_auth("admin", "admin")
      response = @localinstance.request(req)
      puts response
    end
  end
end

desc "[Alias to :status]"
task :stat => :status do
end

desc "Check the status of the last known running server."
task :status do
  if File.exists? '.nakamura.pid'
    File.open('.nakamura.pid', 'r') do |f|
      while (line = f.gets) do
        pid = line.to_i
        begin
          Process.kill 0, pid
          puts "pid [#{pid}] is still running."
        rescue
          puts "pid [#{pid}] is no longer valid."
        end
      end
    end
  else
    puts ".nakamua.pid doesn't exist."
  end
end

desc "Update and rebuild the UI and Nakamura projects."
task :build => [:update, :rebuild]

desc "Update and rebuild the CLE"
task :build_cle => [:update_cle, :rebuild_cle]

desc "Build a hybrid server"
task :hybrid => [:build, :run, :build_cle, :config_directoryprovider, :run_cle, :setfsresource_uiconf, :enable_hybrid]

desc "Build a hybrid server from scratch, including checking out all the source."
task :hybrid_scratch => [:clone, :clone_cle, :hybrid]

desc "Create users, greate groups, make connections, send messages, set FSResource, clean the UI"
task :setup => [:createusers, :makeconnections, :sendmessages, :setfsresource, :cleanui]

desc "Create a release build of the UI, regular build of everything else, and run it."
task :release => [:clean, :update, :release_build, :run]

desc "Clean, build and run"
task :default => [:clean, :build, :run]

