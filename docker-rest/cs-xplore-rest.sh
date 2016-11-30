#!/bin/bash

check_connectivity(){
    i=0
    status_code=0
    while [ "$status_code" -ne "$3" -a "$i" -le $4 ]
    do
        i=$((i+1))
        echo Checking if $1 is up...
        status_code=$(curl --connect-timeout 2 --write-out %{http_code} --silent --output /dev/null $2)
        #echo status code is $status_code
        sleep $5
    done

    if [ "$status_code" -eq "$3" ]
    then
        echo $1 is up...
    else
        echo $1 is not up... Please check the environment and configuration.
        exit 0
    fi
}

docker-compose up -d cs
sleep 10
docker exec -d -it ubuntupgcs bash -c "/home/dmadmin/dctm/wildfly9.0.1/server/startMethodServer.sh"

docker cp ubuntupgcs:/home/dmadmin/dctm/config/dfc.properties rest/config/
docker-compose up -d rest
check_connectivity "DCTM REST" "http://localhost:8080/dctm-rest/repositories/" 200 30 2


#if full text search is not needed, just remove the two line below.
docker-compose up -d cps
check_connectivity "xPlore" "http://localhost:9300/dsearch/" 259 60 5

docker-compose up -d indexagent
check_connectivity "Index Agent" "http://localhost:9200/IndexAgent/" 200 60 5

echo The full-text search enabled content server suite is ready...