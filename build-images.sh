#!/bin/bash

#sudo docker build -f Dockerfile.zeromq -t gridappsd/zeromq .
#sudo docker build -f Dockerfile.fncs -t gridappsd/fncs .
#sudo docker build -f Dockerfile.gridappsd_base -t gridappsd/gridappsd_base .
#sudo docker build -f Dockerfile.gridappsd_viz -t gridappsd/viz .
sudo docker build -f Dockerfile.gridappsd -t gridappsd/gridappsd .
