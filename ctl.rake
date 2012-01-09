namespace :ctl do
  desc "Start a running server; Will kill the previously started server if still running (alias: start)"
  task :run => ['ctl:kill'] do
    app_file = nil
    Dir[@app_file].each do |path|
      if !path.end_with? "-sources.jar" then
        app_file = path
      end
    end
    abort("Unable to find application version") if app_file.nil?
  
    CMD = "#{@java_cmd} -jar #{app_file} #{@app_opts}"
    p "Starting server with #{CMD}"
  
    pid = fork { exec( CMD ) }
    Process.detach(pid)
    File.open(".nakamura.pid", 'w') {|f| f.write(pid) }
  end

  task :start => 'ctl:run'
  
  desc "Kill the previously started server (alias: stop)"
  task :kill do
    kill(".nakamura.pid")
  end

  task :stop => 'ctl:kill'

  desc "Check the status of the last known running server (alias: stat)"
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

  task :stat => 'ctl:status'

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
end
