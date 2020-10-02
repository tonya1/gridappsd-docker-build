#!/bin/bash

####
# pull the lyrasis/blazegraph:2.1.4 container
# create a intermediate build container and add the gridappsd configuration file
# start the build container and import the xml files
# checkout the Powergrid-Models 
#  update the constants.py
#  load the measurements
# print instructions for committing the build container, tagging and pushing to dockerhub
####

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
    sleep 2
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


build_dir=bzbuild/build_$(date +"%Y%m%d%H%M%S")

if [ -d $build_dir ]; then
  echo "$build_dir exists"
  echo "Exiting..."
  exit 1
fi

mkdir -p $build_dir
cp $0 $build_dir
cp Dockerfile.gridappsd_blazegraph $build_dir
cp -rp ./conf/rwstore.properties $build_dir
cd $build_dir

# Close STDOUT file descriptor
exec 1<&-
# Close STDERR FD
exec 2<&-

# Open STDOUT as $LOG_FILE file for read and write.
exec 1<>create.log

# Redirect STDERR to STDOUT
exec 2>&1

date

url_viz="http://localhost:8080/"
blazegraph_models="ACEP_PSIL.xml EPRI_DPV_J1.xml IEEE123_PV.xml IEEE123.xml IEEE13_Assets.xml IEEE13.xml IEEE8500_3subs.xml IEEE8500.xml R2_12_47_2.xml Transactive.xml"

url_blazegraph="http://localhost:8889/bigdata/"
data_dir="Powergrid-Models/blazegraph/test"
debug=0
exists=0
# set the default tag for the gridappsd and viz containers
GRIDAPPSD_TAG=':develop'

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

echo " "
echo "Getting blazegraph status"
status=$(curl -s --head -w %{http_code} "$url_blazegraph" -o /dev/null)
debug_msg "blazegraph curl status: $status"


docker pull lyrasis/blazegraph:2.1.4

TIMESTAMP=`date +'%y%m%d%H'`

echo "TIMESTAMP $TIMESTAMP"

docker build --build-arg TIMESTAMP="${TIMESTAMP}_${GITHASH}" -t gridappsd/blazegraph:build -f Dockerfile.gridappsd_blazegraph .

echo " "
echo "Running the build container to load the data"

# start it with the proper conf file
did=`docker run --cpuset-cpus "0-3" -d -p 8889:8080 gridappsd/blazegraph:build`
status=$?

echo "$did $status"

if [ "$status" -gt 0 ]; then
  echo " "
  echo "Error starting container"
  echo "Exiting "
  exit 1
fi

cwd=`pwd`

if [ -d Powergrid-Models ]; then
  cd Powergrid-Models
  git pull -v
  cd $cwd
else
  git clone http://github.com/GRIDAPPSD/Powergrid-Models -b develop
  #git clone http://github.com/GRIDAPPSD/Powergrid-Models -b feature/1289
  #git clone http://github.com/GRIDAPPSD/Powergrid-Models -b issue/1173
fi

GITHASH=`git -C Powergrid-Models log -1 --pretty=format:"%h"`

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
      echo "Error could not ingest blazegraph data file $data_dir/$blazegraph_file"
      echo $curl_output
      bz_load_status=1
    fi
    #echo "Verifying blazegraph data"
    rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
  done

  if [ ${rangeCount:-0} -gt 0  -a $bz_load_status == 0 ]; then
    echo "Finished ingesting blazegraph data files ($rangeCount)"
  else
    echo "Error ingesting blazegraph data files ($rangeCount)"
    echo "Exiting "
    echo " "
    #echo $curl_output
    exit 1
  fi
else
  echo "Error Blazegrpah already contains data ($rangeCount)"
  exit 1
fi

echo " "
echo "docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}_models "
docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}_models
echo " "

# load the measurements 
echo " "
echo "Loading the measurements"

echo " "
echo "Modifying the Powergrid-Models/Meas/constants.py file for loading data into local docker container"
sed -i'.bak' -e 's/^blazegraph_url.*$/blazegraph_url = \"http:\/\/localhost:8889\/bigdata\/sparql\"/' Powergrid-Models/Meas/constants.py

cd Powergrid-Models/Meas
if [ ! -d tmp ]; then 
  mkdir tmp
else
  rm tmp/*txt 2> /dev/null
fi
cd tmp

echo " "
echo "Generating measurements files"
python3 ../ListFeeders.py | grep -v 'binding keys' | while read line; do
  echo "  Generating measurements files for $line"
  python3 ../ListMeasureables.py $line
done

echo " "
echo "Measurements found"
#shasum * | shasum | cut -d' ' -f1
wc -l *txt | grep total | awk '{print $1}'

echo " "
echo "Loading measurements files"
ls -1 *txt | xargs -P 12 -n 1 -I, bash -c 'echo "  Loading measurments file ,";python3 ../InsertMeasurements.py ,'

echo " "
rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
echo "Finished loading blazegraph measurements ($rangeCount)"
echo " "
echo "docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}_measurements "
docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}_measurements

cd ../../houses
# assign random climate zones (1-5) to lookup
zone_ieee123pv=5
zone_ieee8500=3
zone_ieee123transactive=2
zone_test9500new=3
zone_sourceckt=2
zone_acep_psil=1
zone_ieee123=2
zone_ieee13nodeckt=4
zone_ieee13nodecktassets=5
zone_j1=1
#zone_ieee8500new_335=4

echo " "
echo "Loading houses"
python3 ../Meas/ListFeeders.py | grep -v 'binding keys' | while read fdrname fdrid ; do
  # use lookup
  climate_zone="zone_$fdrname"
  echo "  Loading houses for $fdrname : $fdrid : ${!climate_zone}"
  python3 insertHouses.py $fdrid ${!climate_zone}
  status=$?
  if [ $status -gt 0 ]; then
    echo " "
    echo "  Failed loading houses for $fdrname: python3 insertHouses.py $fdrid ${!climate_zone}"
    echo " "
  fi
done

echo " "
rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
echo "Finished loading blazegraph houses ($rangeCount)"


echo " "
echo "----"
echo "docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH} "
docker commit $did gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}
echo "docker stop $did"
docker stop $did
echo " "
echo "Run these commands to commit the container and push the container to dockerhub"
echo "----"
echo "docker tag gridappsd/blazegraph:${TIMESTAMP}_${GITHASH} gridappsd/blazegraph:develop"
echo "docker push gridappsd/blazegraph:${TIMESTAMP}_${GITHASH}"
echo "docker push gridappsd/blazegraph:develop"

date
exit 0
