###A Rakefile to manage updating, building and running Sakai OAE###

To get started, you'll need ruby and the bundle gem installed. Inside your OAE-Builder directory, simply run

    bundle install

and you'll have all the gems you need to run this. If you get an error about missing mysql dependencies you can either install your OS's equivalent of libmysqlclient-dev or use

    bundle install --without mysql

As the mysql gem is only needed if you set `db["driver"] = "mysql"` in the settings.rb file.

Make sure your sparsemapcontent, solr, and nakamura directories are siblings of the OAE-Builder directory. If you don't like the defaults you can adjust the paths used, upstream git repos, branches, etc by overriding them in settings.rb.

Then just run 

    rake

and the script will do a git pull on each project, build them and start the server.

If you want to stop the server run 

    rake kill

If you just re-run `rake` the kill job will automatically be run before starting the new server.

A full list of targets can be found by running `rake -T`
Some other handy targets are:

* `rake rebuild` To do a build without the git pull
* `rake fastrebuild` To just rebuild the app jar without rebuilding everything
* `rake clean` To clean up the sling, store, etc directories
* `rake setup` To create some test users, connections, and groups, and set up your fsresource

You can also specify multiple targets like `rake clean fastrebuild run`
