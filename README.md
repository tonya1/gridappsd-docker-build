# gridappsd/gridappsd_base container

This repository is used to build the base container for gridappsd.  

It also includes a few scripts one to create the releases and another to create a blazegraph container.

./scripts/release/create_release.sh - Requires github username and token.  
Release process:
  * List open pull requests
  * Create the release/$VERSION from develop
  * Test the releases/$VERSION
  * From the releases/$VERSION branch, create the pull request to master
  * Assign and close the pull requests
  * After the pull request's are approved then create the Tagged Releases

./create_blazegraph.sh - From the lyrasis/blazegraph:2.1.4 container, 
 * add a custom configuration file 
 * from https://github.com/GRIDAPPSD/Powergrid-Models/
   * import the XML files 
   * extract the measurements 
   * import measurements
   * add the houses
