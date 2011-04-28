require 'rubygems'
require 'git'

projects = ["./sparsemapcontent", "./solr", "./nakamura"]

CLEAN_FILES = ["./derby.log", "./sling", "./activemq-data", "./store"]
task :clean do
  touch CLEAN_FILES
  rm_r CLEAN_FILES
end

task :update do
  for p in projects do
    g = Git.open(working_dir = p)
    puts g.pull()
  end
end

task :rebuild do
  for p in projects do 
    system("cd #{p} && mvn clean install")
  end
end

task :fastrebuild do
  system("cd ./nakamura/app && mvn clean install")
end

task :run => [:kill] do
  pid = fork{exec("java -jar ./nakamura/app/target/org.sakaiproject.nakamura.app-0.10-SNAPSHOT.jar")}
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
