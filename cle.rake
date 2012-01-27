namespace :cle do
  desc "Checkout CLE from SVN"
  task :clone do
    if @cle.has_key? "path"
      if File.directory? @cle["path"]
        @logger.info "#{@cle["path"]} already exists."
      elsif @cle.has_key? "repository"
        system("svn -q checkout #{@cle["repository"]} #{@cle["path"]}")
        if @hybrid.has_key? "path" and @hybrid.has_key? "repository"
          system("svn -q checkout #{@hybrid["repository"]} #{@hybrid["path"]}")
        end
      end
    end
  end


  desc "Update the SVN checkout of CLE"
  task :update do
    if @cle.has_key? "path" and File.directory? @cle["path"]
      @logger.info "Updating #{@cle["path"]}"
      system("svn -q update #{@cle["path"]}")
      if @hybrid.has_key? "path" and File.directory? @hybrid["path"]
        @logger.info "Updating #{@hybrid["path"]}"
        system("svn -q update #{@hybrid["path"]}")
      end
    end
  end

  desc "Rebuild the CLE and its hybrid module"
  task :rebuild => 'cle:config' do
    deploydir = "#{Dir.pwd}/sakai2-demo"
    Dir.chdir(@cle["path"]) do
      system("#{@mvn_cmd} -Dmaven.tomcat.home=#{deploydir} clean install sakai:deploy")
    end
    Dir.chdir(@hybrid["path"]) do
      system("#{@mvn_cmd} -Dmaven.tomcat.home=#{deploydir} clean install sakai:deploy")
    end
  end

  desc "Start a CLE server. Will kill the previously started server if still running."
  task :run => 'cle:kill' do
    ENV['CATALINA_PID'] = ".sakai-@cle.pid"
    pid = fork { exec( "./sakai2-demo/bin/startup.sh" ) }
    Process.detach(pid)
  end

  desc "Kill the CLE server."
  task :kill do
    kill(".sakai-@cle.pid", 9)
  end

  desc "Configure the CLE server"
  task :config => 'tomcat:unpack' do
    class SakaiProperties < Mustache
    end
    sakaiprops = SakaiProperties.new
    sakaiprops[:s2_tag] = @cle["repository"].split('/')[-1]
    sakaiprops[:hybrid_tag] = @hybrid["repository"].split('/')[-1]
    Dir.chdir(@cle["path"]) do
      sakaiprops[:repo_rev] = /Revision.*$/.match(`svn info`).to_s
    end
    sakaiprops[:server] = @hostname
    sakaiprops[:build_date] = Time.now
    sakaiprops[:k2_http_port] = @nakamura["port"]

    # don't worry, no data gets sent to this google ip
    # Since UDP is a stateless protocol connect() merely makes a system call
    # which figures out how to route the packets
    ip = UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }
    sakaiprops[:external_ip] = ip
    unless Dir.exists? "./sakai2-demo/sakai"
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
          el.attributes["port"] = @cle["port"]
        elsif el.attributes["port"] == "8009"
          el.attributes["port"] = @cle["ajp_port"]
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

  desc "Update and rebuild the CLE"
  task :build => ['cle:update', 'cle:rebuild']

  namespace :hybrid do
    desc "Enable Hybrid Widgets and Config"
    task :enable => [:setuprequests] do
      enableInPortal("devwidgets/mysakai2/config.json", "http://admin:admin@localhost:#{@nakamura["port"]}")
      enableInSakaiDoc("devwidgets/basiclti/config.json", "http://admin:admin@localhost:#{@nakamura["port"]}")
      enableInSakaiDoc("devwidgets/sakai2tools/config.json", "http://admin:admin@localhost:#{@nakamura["port"]}")
      setFsResource("/dev/configuration/config_custom.js", "#{@oaebuilder_dir}/ui-conf/config_custom_@hybrid.js")
    end

    desc "Build a hybrid server"
    task :build => ['bld:build', 'ctl:run', 'cle:build', 'cle:config:directoryprovider', 'cle:run', 'conf:fsresource:uiconf', 'cle:hybrid:enable']

    desc "Build a hybrid server from scratch, including checking out all the source."
    task :scratch => ['bld:clean', 'bld:clone', 'cle:clone', 'cle:hybrid:build']
  end

  namespace :tomcat do
    desc "Unpack Tomcat tarball"
    task :unpack => 'cle:tomcat:dl' do
      @logger.info "Unpacking #{@tomcat["filename"]}"
      Dir.chdir(File.dirname(@tomcat["filename"])) do
        tgz = Zlib::GzipReader.new(File.open(@tomcat["filename"], 'rb'))
        Archive::Tar::Minitar.unpack(tgz, './tmp')
        FileUtils.mv("./tmp/apache-tomcat-#{@tomcat["version"]}", "./sakai2-demo")
      end
    end

    desc "Download Tomcat tarball"
    task :dl do
      @tomcat["filename"] = "apache-tomcat-#{@tomcat["version"]}.tar.gz"
      unless File.exists? @tomcat["filename"]
        @logger.info "Downloading #{@tomcat["filename"]} from #{@tomcat["mirror"]}"
        Net::HTTP.start(@tomcat["mirror"]) do |http|
          resp = http.get("/#{@tomcat["prefix"]}/tomcat/tomcat-5/v#{@tomcat["version"]}/bin/#{@tomcat["filename"]}")
          open("#{@tomcat["filename"]}", "wb") do |file|
            file.write(resp.body)
          end
        end
      end
    end
  end

  def enableInPortal(path, server)
    resp = RestClient.get("#{server}/#{path}")
    json = JSON.parse(resp.to_str)
    json["personalportal"] = true
    postJsonAsFile(path, JSON.generate(json), server)
  end

  def enableInSakaiDoc(path, server)
    resp = RestClient.get("#{server}/#{path}")
    json = JSON.parse(resp.to_str)
    json["sakaidocs"] = true
    postJsonAsFile(path, JSON.generate(json), server)
  end

  def postJsonAsFile(path, json, server)
    filename = File.basename(path)
    # I'd rather not write out an intermediary file here, but I'm not sure it's
    # possible to avoid it.
    unless Dir.exists?("./tmp")
      Dir.mkdir("./tmp")
    end
    File.open("./tmp/#{filename}", "w") do |temp|
      temp.write(json)
    end

    RestClient.post("#{server}/#{File.dirname(path)}", filename => File.new("./tmp/#{filename}"), "#{filename}@TypeHint" => "nt:file")
    File.delete("./tmp/#{filename}")
  end

  namespace :config do
    desc "Configure the CLE to use NakamuraUserDirectoryProvider"
    task :directoryprovider do #=> 'cle:build' do
      components = 'sakai2-demo/components/sakai-provider-pack/WEB-INF/components.xml'
      cXML = nil 
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
  end
end
