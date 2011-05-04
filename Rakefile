require 'rubygems'
require 'git'

projects = [{"path" => "./sparsemapcontent"},
  {"path" => "./solr"},
  {"path" => "./nakamura", "remote" => "sakai"}]

JAVA_OPTS = "-Xms256m -Xmx1024m -XX:PermSize=64m -XX:MaxPermSize=512m"

CLEAN_FILES = ["./derby.log", "./sling", "./activemq-data", "./store"]
task :clean do
  touch CLEAN_FILES
  rm_r CLEAN_FILES
end

task :update do
  for p in projects do
    g = Git.open(working_dir = p["path"])
    remote = p["remote"] || "origin"
    puts g.pull(remote = remote)
  end
end

task :rebuild do
  for p in projects do 
    system("cd #{p["path"]} && mvn clean install")
  end
end

task :fastrebuild do
  system("cd ./nakamura/app && mvn clean install")
end

task :run => [:kill] do
  pid = fork{exec("java #{JAVA_OPTS} -jar ./nakamura/app/target/org.sakaiproject.nakamura.app-0.11-SNAPSHOT.jar")}
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

task :build => [:update, :rebuild]
task :default => [:build, :run]
