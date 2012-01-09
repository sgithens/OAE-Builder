namespace :conf do
  desc "Configure nakamura"
  task :config do
    FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/proxy")
    FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/http/usercontent")
    FileUtils.mkdir_p("./sling/config/org/sakaiproject/nakamura/lite/storage/jdbc")
    class TrustedLogin < Mustache
    end
    tl = TrustedLogin.new
    tl["httpd_port"] = @cle["port"]
    File.open("./sling/config/org/sakaiproject/nakamura/proxy/TrustedLoginTokenProxyPreProcessor.config", 'w') do |f|
      f.write(tl.render())
    end

    class ServerProtection < Mustache
    end
    sp = ServerProtection.new
    sp["server"] = @hostname
    sp["httpd_port"] = @nakamura["port"]
    File.open("./sling/config/org/sakaiproject/nakamura/http/usercontent/ServerProtectionServiceImpl.config", 'w') do |f|
      f.write(sp.render())
    end

    if @db["driver"] == "mysql"
      class StoragePool < Mustache
      end
      stp = StoragePool.new
      stp["dbuser"] = @db["user"]
      stp["dbpass"] = @db["password"]
      File.open("./sling/config/org/sakaiproject/nakamura/lite/storage/jdbc/JDBCStorageClientPool.config", 'w') do |f|
        f.write(stp.render())
      end
    end
  end

  namespace :fsresource do
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
    task :set => [:setuprequests] do
      uiabspath = File.expand_path(@ui["path"])
      @fsresources.each do |dir|
        setFsResource(dir, "#{uiabspath}#{dir}")
      end
    end

    desc "Set fsresource just for the UI config"
    task :uiconf => [:setuprequests] do
      if not Dir.exists?("./ui-conf")
        FileUtils.cp_r("#{@ui["path"]}/dev/configuration/", "./ui-conf")
      end
      setFsResource("/dev/configuration", "#{@oaebuilder_dir}/ui-conf")
    end
  end
end
