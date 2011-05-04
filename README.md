###A Rakefile to manage updating, building and running Sakai OAE###

(Chris Roby edit: Stuart had a directory structure like /opt/OAE-Builder/nakamura, whereas mine is /opt/OAE-Builder/ and /opt/nakamura, so the following line has changed:)

To use it copy your sparsemapcontent, solr, and nakamura (and load if you'd like) directories as siblings of the OAE-Builder directory.

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
