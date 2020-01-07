# gridappsd/gridappsd_base container

This repository is used to build the base container for gridappsd.  

It also includes a few scripts one to create the releases and another to create a blazegraph container.

./scripts/release/create_release.sh - Requires github username and token.  

To create a release, the create_release.sh script is run multiple times, between each run there are manual testing and validation steps.

1.  Clone the build repository 
```
git clone https://github.com/GRIDAPPSD/gridappsd-docker-build
```

1.  Clone the gridappsd-docker repository
```
git clone https://github.com/GRIDAPPSD/gridapspd-docker
```

1.  Edit the create_release.sh script to update the version and add GitHub username and token.
```
cd gridappsd-docker-build/scripts/release
vi create_release.sh
```

1.  Run the create_release.sh script to create the release branches  
```
./create_release.sh
```
  - pulls the latest gridappsd/blazegraph:develop container and tags as releases_VERSION and pushes to docker hub
  - clone the GitHub repositories develop branches and create the releases/VERSION branches
  - Update the default version for the run.sh script in gridappsd-docker

1.  Verify the containers were built and test the releases_VERSION
```
cd ../../../gridappsd-docker
./run.sh -t releases_VERSION
```

1.  Run the create_release.sh script to create the pull requests
```
cd ../gridapspd-docker-build/scripts/release
./create_release.sh
```
 - Update the gridappsd/blazegraph:master container
 - Create the pull requests from releases/VERSION to master

1.  Assign and merge the pull requests on GitHub    

1.  Run the create_release.sh script to create the tagged releases
```
./create_release.sh
```
  - Create the tagged releases
  - Create the gridappsd/blazegraph:vVERSION container 

1.  Verify the containers have been built and test the released version
```
cd ../../../gridappsd-docker
./run.sh -t vVERSION
```

./create_blazegraph.sh - From the lyrasis/blazegraph:2.1.4 container, 
 * add a custom configuration file 
 * from https://github.com/GRIDAPPSD/Powergrid-Models/
   * import the XML files 
   * extract the measurements 
   * import measurements
   * add the houses
