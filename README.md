###A Rakefile to manage updating, building and running Sakai OAE###

To get started, you'll need ruby and the bundle gem installed. Inside your OAE-Builder directory, simply run

> bundle install

and you'll have all the gems you need to run this.

Make sure your sparsemapcontent, solr, and nakamura directories are siblings of the OAE-Builder directory.

Then just run 

> rake

and the script will do a git pull on each project, build them and start the server.

If you want to stop the server run 

> rake kill

If you just re-run `rake` the kill job will automatically be run before starting the new server.

There are other handy targets, like:

* To do a build without the git pull

> rake rebuild

* To just rebuild the app jar without rebuilding everything

> rake fastrebuild

* To clean up the sling, store, etc directories

> rake clean

* To create some test users, connections, and groups, and set up your fsresource

> rake setup