namespace :pkg do
  desc "Build the UI and Nakamura projects, make a webstart"
  task :webstart => ['bld:rebuild'] do
    Dir.chdir @nakamura["path"] do
      system("#{@mvn_cmd} clean install")
    end
  end
end
