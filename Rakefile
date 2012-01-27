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
require 'logger'

# Our own little logger, because the default one is ugly
class SakaiLogger < Logger::Formatter
  def call(severity, time, program_name, message)
    datetime = time.strftime("%Y-%m-%d %H:%M")
    "[#{datetime}] #{severity}: #{String(message)}\n"
  end
end

# before settings is created
logger = Logger.new STDOUT
logger.formatter = SakaiLogger.new
logger.level = Logger::DEBUG

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

@oaebuilder_dir = File.expand_path('.')

@builddir = ENV['builddir']
unless @builddir then
  @builddir = ".."
end 

#sparse = {"path" => "#{@builddir}/sparsemapcontent", "repository" => "git://github.com/sakaiproject/sparsemapcontent.git", "branch" => "master", "localbranch" => "master"}
#solr = {"path" => "#{@builddir}/solr", "repository" => "git://github.com/sakaiproject/solr.git", "branch" => "master", "localbranch" => "master"}
nakamura = {"path" => "#{@builddir}/nakamura", "repository" => "git://github.com/sakaiproject/nakamura.git", "branch" => "master", "localbranch" => "master", "port" => "8080"}

ui = {"path" => "#{@builddir}/3akai-ux", "repository" => "git://github.com/sakaiproject/3akai-ux.git", "branch" => "master", "localbranch" => "master"}
fsresources = ["/dev", "/devwidgets", "/tests"]

cle = {"path" => "#{@builddir}/sakai-cle", "repository" => "https://source.sakaiproject.org/svn/sakai/branches/sakai-2.8.1", "port" => "8880", "ajp_port" => "8889" }
hybrid = {"path" => "#{cle["path"]}/hybrid", "repository" => "https://source.sakaiproject.org/svn/hybrid/branches/hybrid-1.1.x"}

db = {"driver" => "derby", "user" => "sakaiuser", "password" => "ironchef", "db" => "nakamura"}

tomcat = {"mirror" => "archive.apache.org", "prefix" => "dist", "version" => "5.5.34"}

hostname = Socket.gethostname

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

# read in and evaluate an external settings file
eval File.open('./settings.rb').read if File.exists?('./settings.rb')

server = [nakamura] if server.nil?

@mvn_cmd = "#{mvn_exec} #{mvn_opts}"

@java_cmd = "#{java_exec} #{java_opts}"
if java_debug
  @java_cmd += " #{java_debug_opts}"
end

if db["driver"] == "mysql"
  Bundler.require(:mysql)
end

CLEAN_FILES = ["./derby.log", "./sling", "./activemq-data", "./store", "./sakai2-demo", "./tmp", "./ui-conf"]

## copy some vars to a higher scope for commands defined in separate rake files
## we do it this way so changes in settings.rb are local vars and you don't have
## to keep track of the scope of the settings.
@nakamura = nakamura
@server = server
@ui = ui
@fsresources = fsresources
@cle = cle
@hybrid = hybrid
@db = db
@tomcat = tomcat
@hybrid = hybrid
@hostname = hostname
@templatePath = templatePath
@num_users_groups = num_users_groups
@update_ui = update_ui
@app_file = app_file
@app_opts = app_opts
@logger = logger

## log some initial values before reading in other task definitions
@logger.info "Using settings:"
@logger.info "  JAVA:   #{@java_cmd}"
@logger.info "  MVN:    #{@mvn_cmd}"
@logger.info "  UI:     #{ui.inspect}"
@logger.info "  SERVER: #{server.inspect}"

# include external rake file for custom tasks
Dir.glob('*.rake').each { |r| import r }

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

########################
##  Task Definitions  ##
########################
task :setuprequests do
  @uri = URI.parse("http://localhost:#{@nakamura["port"]}")
  @localinstance = Net::HTTP.new(@uri.host, @uri.port)
end

desc 'Create users, greate groups, make connections, send messages, set FSResource, clean the UI'
task :setup => ['data:setup', 'conf:fsresource:set', 'bld:clean:ui']

desc 'Clean, build and run'
task :default => ['bld:clean', 'bld:build', 'ctl:run']

## alias common tasks
desc 'Shortcut to ctl:run'
task :run => 'ctl:run'

desc 'Shortcut to ctl:kill'
task :kill => 'ctl:kill'

desc 'Shortcut to bld:update'
task :update => 'bld:update'

desc 'Shortcut to bld:clean'
task :clean => 'bld:clean'
