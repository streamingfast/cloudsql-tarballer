# cloudsql-tarballer
Toolset to dump postgresql data into a pgdata tarball

# HOW TO USE
* you need a service account with permissions to create a clone postgres SQL
* copy the yaml file from samples/ and adjust parameters to your infrastructure
* apply the yaml to your cluster to:
 1. create an SQL clone
 2. dump the whole database locally (watch out, you will need a PVC on disk if that DB is larger than a few GBs)
 3. pg_restore that whole database into a local (in-pod) postgresql instance and stop it
 4. tarball the PGDATA folder
 5. Upload that tarball to google storage

Then, you are ready to use that tarball in an integration test, with https://github.com/streamingfast/graphnode-operator
