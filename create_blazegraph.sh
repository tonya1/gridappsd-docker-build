#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 [-d]"
  /bin/echo "        -d      debug"
  exit 2
}

debug_msg() {
  msg=$1
  if [ $debug == 1 ]; then
    now=`date`
    echo "DEBUG : $now : $msg"
  fi
}

http_status_container() {
  cnt=$1

  echo " "
  echo "Getting $cnt status"
  if [ "$cnt" == "blazegraph" ]; then
    url=$url_blazegraph
  elif [ "$cnt" == "viz" ]; then
    url=$url_viz
  fi
  debug_msg "$cnt $url"
  status="0"
  count=0
  maxcount=10
  while [ $status -ne "200" -a $count -lt $maxcount ]
  do
    status=$(curl -s --head -w %{http_code} "$url" -o /dev/null)
    debug_msg "curl status: $status"
    sleep 1
    count=`expr $count + 1`
  done
  
  debug_msg "tried $url $count times, max is $maxcount"
  if [ $count -ge $maxcount ]; then
    echo "Error contacting $url ($status)"
    echo "Exiting "
    echo " "
    exit 1
  fi
}

url_viz="http://localhost:8080/"
blazegraph_models="EPRI_DPV_J1.xml IEEE123.xml R2_12_47_2.xml IEEE8500.xml"
url_blazegraph="http://localhost:8889/bigdata/"
data_dir="Powergrid-Models/blazegraph/Test"
debug=0
exists=0
# set the default tag for the gridappsd and viz containers
GRIDAPPSD_TAG=':dev'

# parse options
while getopts dpt: option ; do
  case $option in
    d) # enable debug output
      debug=1
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`


cwd=`pwd`

echo " "
echo "Getting blazegraph status"
status=$(curl -s --head -w %{http_code} "$url_blazegraph" -o /dev/null)
debug_msg "blazegraph curl status: $status"


docker pull lyrasis/blazegraph:2.1.4

TIMESTAMP=`date +'%y%m%d%H'`

echo "TIMESTAMP $TIMESTAMP"

docker build --build-arg TIMESTAMP="${TIMESTAMP}:${TRAVIS_BRANCH}" -t gridappsd/blazegraph:build -f Dockerfile.gridappsd_base_blazegraph .

echo " "
echo "Running the build container to load the data"

# start it with the proper conf file
did=`docker run -d -p 8889:8080 gridappsd/blazegraph:build`
status=$?

echo "$did $status"

if [ "$status" -gt 0 ]; then
  echo " "
  echo "Error starting container"
  echo "Exiting "
  exit 1
fi

if [ -d Powergrid-Models ]; then
  cd Powergrid-Models
  git pull -v
  cd $cwd
else
  git clone http://github.com/GRIDAPPSD/Powergrid-Models
fi


http_status_container 'blazegraph'

bz_load_status=0
echo " "
echo "Checking blazegraph data"

echo " "
# Check if blazegraph data is already loaded
rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
if [ x"$rangeCount" == x"0" ]; then
  for blazegraph_file in $blazegraph_models; do
    echo "Ingesting blazegraph data $data_dir/$blazegraph_file ${url_blazegraph}sparql ($rangeCount)"
    debug_msg "curl -s -D- -H 'Content-Type: application/xml' --upload-file \"$data_dir/$blazegraph_file\" -X POST \"${url_blazegraph}sparql\""
    curl_output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file "$data_dir/$blazegraph_file" -X POST "${url_blazegraph}sparql"`
    debug_msg "curl output: $curl_output"
    bz_status=`echo $curl_output | grep -c 'data modified='`

    if [ ${bz_status:-0} -ne 1 ]; then
      echo "Error could not load blazegraph data $data_dir/$blazegraph_file"
      echo $curl_output
      bz_load_status=1
    fi
    #echo "Verifying blazegraph data"
    rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
  done

  if [ ${rangeCount:-0} -gt 0  -a $bz_load_status == 0 ]; then
    echo "Finished uploading blazegraph data ($rangeCount)"
  else
    echo "Error loading blazegraph data ($rangeCount)"
    echo "Exiting "
    echo " "
    #echo $curl_output
    exit 1
  fi
else
  echo "Blazegrpah data has already been loaded ($rangeCount)"
fi

echo " "
echo "Done"




# load the measurements 
echo " "
echo "Loading the measurements"

echo " "
echo "Modifying the Powergrid-Models/Meas/constants.py file"
sed -i'.bak' -e 's/^blazegraph_url.*$/blazegraph_url = \"http:\/\/localhost:8889\/bigdata\/sparql\"/' Powergrid-Models/Meas/constants.py

cd Powergrid-Models/Meas
echo "----- list"
./listall.sh

echo "----- insertall"
./insertall.sh

echo "----- insert"
python InsertMeasurements.py ieee8500_rc1.bak

echo "----- list"
./listall.sh


echo " "
echo "Run these commands to commit the container and push the container to dockerhub"
echo "----"
echo "docker commit $did gridappsd/blazegraph:${TIMESTAMP} "
echo "docker stop $did"
echo "docker tag gridappsd/blazegraph:${TIMESTAMP} gridappsd/blazegraph:dev"
echo "docker push gridappsd/blazegraph:${TIMESTAMP}"
echo "docker push gridappsd/blazegraph:dev"

exit 0
