# Docker Boot Camp - REST cheet sheet

## Precondition

1. docker and docker-compose installed
2. swarm mode exercises need at least two docker hosts
3. download the image tar files from [support site](https://support.emc.com/search/?text=documentum%20docker) or retrieve from ECD internal registry during exercises
4. for SAML practice, load these images a customized shibboleth image  
	a. `docker pull dorowu/ubuntu-desktop-lxde-vnc`  
	b. `docker pull greggigon/apacheds`  
	c. `scp dmadmin@10.240.194.73:/home/dmadmin/ispecialist/rest/images/rest-shib-idp.tar /local/dir`



## Practice #1 - Run REST Container

1. load REST image if you want to load image from tar file instead of from registry; or jump to step #3

   ```bash
   tar -xvf RESTAPI_Docker_Ubuntu.tar

   docker load -i RESTAPI_Ubuntu.tar
   ```

2. list the images, and there should be one  `restapi_ubuntu:7.3.0000.0590`

   ```shell
   docker images
   ```

3. make work directory and config/logs directory

   ```
   mkdir -p ~/docker-ispecialist/rest/config
   mkdir -p ~/docker-ispecialist/rest/logs
   cd ~/docker-ispecialist/rest
   ```

4. prepare essential configuration file - dfc.properties

   ```shell
   vi ~/docker-ispecialist/rest/config/dfc.properties
   ```

   here is a sample of dfc.properties

   ```
   #Add the fully qualified hostname for the docbroker to the following key.
   dfc.docbroker.host[0]= 10.37.14.190
   #Add the port for the docbroker to the following key. default port is 1489
   dfc.docbroker.port[0]= 1489
   #Add the global registry repository name to the following key
   dfc.globalregistry.repository= REPO
   #Add the username of the global registry user to the following key
   dfc.globalregistry.username= dmadmin
   #Add an encrypted password value for the following key
   dfc.globalregistry.password= password

   dfc.session.secure_connect_default=try_native_first
   ```

5. start the container via command below

   *for image loaded from tar file*

   ```shell
   docker run --name rest -p 8080:8080 -d \
       -v `pwd`/config:/root/rest/config \
       -v `pwd`/logs:/root/rest/logs \
       restapi_ubuntu:7.3.0000.0590
   ```

   *or for image from registry*

   ```
   docker run --name rest -p 8080:8080 -d \
       -v `pwd`/config:/root/rest/config \
       -v `pwd`/logs:/root/rest/logs \
       10.8.46.202:5000/restapi/ubuntu/stateless/restapi:7.3.0000.0590
   ```

   ​

6. check container logs

   ```
   docker logs -f rest
   ```

   ​

7. verify REST services is up

   ```shell
   curl http://dmadmin:password@localhost:8080/dctm-rest/repositories/[REPO]
   ```

   ​

## Practice #2 - Re-configure REST container

Assuming there is a running REST container launched in Practice #1, in this exercise, we will enable basic-ct authentication mode and persist rest logs.

1. edit rest-api-runtime.properties

   ```
   vi ~/docker-ispecialist/rest/config/rest-api-runtime.properties
   ```

   add one line

   ```
   rest.security.auth.mode=basic-ct
   ```

2. edit log4j.properties

   ```
   vi ~/docker-ispecialist/rest/config/log4j.properties
   ```

   add the configuration (pay attend to the line `log4j.appender.R.File=/root/rest/logs/rest-api.log`)

   ```
   #
   # Copyright (c) 2016. EMC Corporation. All Rights Reserved.
   #

   # Set root logger to WARN and add an appender called A1.
   log4j.rootLogger=DEBUG, A1, R

   # You can add config to specify the log level for specific Service,
   # for example the following config is to assign DEBUG level for REST Service
   # log4j.logger.com.emc.documentum.rest=DEBUG

   # A1 is set to be a ConsoleAppender.
   log4j.appender.A1=org.apache.log4j.ConsoleAppender

   # A1 uses PatternLayout
   log4j.appender.A1.layout=org.apache.log4j.PatternLayout
   log4j.appender.A1.layout.ConversionPattern=%d %-4r [%t] %-5p %c %x - %m%n

   log4j.appender.R=org.apache.log4j.RollingFileAppender
   log4j.appender.R.File=/root/rest/logs/rest-api.log
   log4j.appender.R.MaxFileSize=100MB
   log4j.appender.R.MaxBackupIndex=3
   log4j.appender.R.layout=org.apache.log4j.PatternLayout
   log4j.appender.R.layout.ConversionPattern=%d %p %t %c - %m%n
   ```

3. restart the REST container

   ```
   docker restart rest
   ```

4. verify the basic-ct authentication mode

   ```
   curl -v http://dmadmin:password@localhost:8080/dctm-rest/repositories/[REPO]
   ```

   below HTTP header will show in the response.

   ```
   Set-Cookie: DOCUMENTUM-CLIENT-TOKEN=......
   ```

5. verify logs persistence

   ```
   vi ~/docker-ispecialist/rest/logs/rest-api.log
   ```




##Practice #3 - Enable HTTPS for REST container

If we finish Practice #2 and #3, we can stop and remove the running REST container by `docker rm -f rest`; or you can repeat step 1 - 4 of practice #1 and continue this practice

In this practice, we will enable SSL for REST services.

1. make a direcotry for keystore file

   ```
   mkdir -p ~/docker-ispecialist/rest/config/security
   ```
   and recover _rest-api-runtime.properties_ if necessary
   ```
   echo "" > ~/docker-ispecialist/rest/config/rest-api-runtime.properties
   ```
   ​

2. generate a keystore and key entry

   ```
   keytool -genkey -alias tomcat -keyalg RSA -keystore ~/docker-ispecialist/rest/config/security/myks
   ```

   ​

3. run the command to start REST container with HTTPS enabled

   *for image loaded from tar file*

   ```
   docker run --name rest -p 8080:8080 -p 8443:8443 -d \
           -v `pwd`/config:/root/rest/config \
           -v `pwd`/logs:/root/rest/logs \
           -e COMM_KEYSTORE_FILE=/root/rest/config/security/myks \
           -e COMM_KEYSTORE_PWD=password \
           -e COMM_KEY_ALIAS=tomcat \
           -e COMM_KEY_PWD=password \
           -e COMM_KEY_STORE_TYPE=JKS \
           restapi_ubuntu:7.3.0000.0590
   ```

   *or for image from registry*

   ```
   docker run --name rest -p 8080:8080 -p 8443:8443 -d \
           -v `pwd`/config:/root/rest/config \
           -v `pwd`/logs:/root/rest/logs \
           -e COMM_KEYSTORE_FILE=/root/rest/config/security/myks \
           -e COMM_KEYSTORE_PWD=password \
           -e COMM_KEY_ALIAS=tomcat \
           -e COMM_KEY_PWD=password \
           -e COMM_KEY_STORE_TYPE=JKS \
           10.8.46.202:5000/restapi/ubuntu/stateless/restapi:7.3.0000.0590
   ```

   ​

4. verify the HTTPS enabled REST services

   ```
    curl -k https://dmadmin:password@localhost:8443/dctm-rest/repositories/[REPO]
   ```

   ​

## Practice #4 - Integrate with all-in-one CS image

Actually this practice could include xPlore as well.

1. make a work directory

   ```
   mkdir -p ~/docker-ispecialist/all-in-one/rest/config/
   cd ~/docker-ispecialist/all-in-one
   ```

2. create a docker compose file

	```
	vi docker-compose.yml
	  
	version: '2'
	services:
	  cs:
	    image: ubuntupgrccs
	    ports: 
	      - "1689:1689"
	      - "1690:1690"
	      - "50000:50000"
	      - "50001:50001"
	      - "9080:9080"
	      - "9082:9082"
	      - "8489:8489"     
	    privileged: true
	    container_name: ubuntupgcs
	    hostname: ubuntupgcs
	    command: /bin/bash -c "./start-db ${ExternalIP}"
	  rest:
	    image: restapi_ubuntu:7.3.0000.0590
	    ports:
	      - "8080:8080"
	      - "8443:8443"
	    container_name: rest
	    hostname: rest
	    volumes: 
	      - ./rest/config:/root/rest/config
	      - ./rest/logs:/root/rest/logs
	    links:
	      - cs
	    depends_on:
	      - cs
	  primary: 
	    image: 10.8.46.202:5000/xplore/ubuntu/stateless/xplore:1.6.0000.0835
	    hostname: primary
	    container_name: primary
	    ports:
	      - "9300:9300"
	    volumes:
	      - xplore:/root/xPlore/rtdata
	    depends_on:
	      - cs
	  cps:
	    image: 10.8.46.202:5000/xplore/ubuntu/stateless/xplore:1.6.0000.0835
	    hostname: cps
	    container_name: cps
	    environment:
	      - role=cps
	      - primary_addr=primary
	    depends_on:
	      - primary
	  indexagent:
	    image: 10.8.46.202:5000/indexagent/ubuntu/stateless/indexagent:1.6.0000.0835
	    hostname: indexagent
	    container_name: indexagent
	    ports:
	      - "9200:9200"
	    environment:
	      - primary_addr=primary
	      - docbase_name=ubuntudb
	      - docbase_user=dmadmin
	      - docbase_password=password
	      - broker_host=ubuntupgcs
	      - broker_port=1489
	      - registry_name=ubuntudb
	      - registry_user=dm_bof_registry
	      - registry_password=password
	    depends_on:
	      - primary
	    volumes_from:
	      - primary
	volumes:
	  xplore: {}     
	```

3. set environment variable

   ```
   export ExternalIP=...
   ```

   ​

4. start CS container

   ```
   docker-compose up -d cs
   ```

   ​

5. start CS method server

   ```
   docker exec -d -it ubuntupgcs bash -c "/home/dmadmin/dctm/wildfly9.0.1/server/startMethodServer.sh"
   ```

   ​

6. copy dfc.properties file from CS container to REST config folder

   ```
   docker cp ubuntupgcs:/home/dmadmin/dctm/config/dfc.properties rest/config/
   ```

   ​

7. start REST container

   ```
   docker-compose up -d rest
   ```

   ​

8. about 3 minutes later, verify the REST services

   ```
   curl http://dmadmin:password@localhost:8080/dctm-rest/repositories/[REPO]
   ```

9. optional step to enable full-text search (*it's better to try this on server instead of laptop*)

   This will launch containers of xPlore and index agent. One manual step is needed to start index agent.

   Details can be found [here](https://iigwiki.corp.emc.com:8443/display/CMAAT/Docker+Elaboration#DockerElaboration-One-StopSolutionwithCSandxPlore)

   ```
   docker-compose up -d cps
   docker-compose up -d indexagent
   ```



## Practice #5 - REST container LB/HA/Scale/Upgrade
1. initialize swarm on the first Docker host

	```
	docker swarm init --advertise-addr 192.168.2.102
	```  
2. join the swarm on the second Docker host

	```
	docker swarm join \
    --token SWMTKN-1-3mfe5amyoo5gg9ux0os1iq43a1k79m4rus3ycb9ztuj7r344cn-15xsjz4oqiyx926nwbo1u44he \
    192.168.2.102:2377
	```
3. check the swarm by running the command on the FIRST Docker host

	```
	docker node ls
	```
4. make the folder

	```
	mkdir -p ~/docker-ispecialist/swarm/config
	cd ~/docker-ispecialist/swarm
	```
5. create Dockerfile for burning the configurationfiles

	```
	vi Dockerfile
	```
	
	```
	FROM 10.31.4.205:5000/restapi/ubuntu/stateless/restapi:7.3.0000.0590
	COPY config/ ${CONFIG_DIR}/
	```
6. create configuration file

	```
	cd ~/docker-ispecialist/swarm/config
	vi dfc.properties
	vi log4j.properties
	```
7. build the rest node image containing configuration file and push to registry

	```
	cd ~/docker-ispecialist/swarm/
	docker build -t 10.240.194.77:5000/rest-node .
	docker push 10.240.194.77:5000/rest-node
	```
8. create REST service

	```
	docker service create --replicas 2 --name rest-multinodes -p 8080:8080 \
	10.240.194.77:5000/rest-node
                
	```
9. check the service

	```
	docker service ps rest-multinodes
	```
10. consume REST service

	```
	curl http://[HOST]:8080/dctm-rest/repositories
	```
11. scale REST service

	```
	docker service scale rest-multinodes=3
	```
12. seamless upgrade needs an dummy new image

	```
	docker tag rest-node 10.240.194.77:5000/rest-node:new
	docker push 10.240.194.77:5000/rest-node:new
	```
13. update the upgrade stragety 

	```
	docker service update rest-multinodes --update-delay 20s --update-parallelism 1
	```
14. kick off upgrade

	```
	docker service update --image 10.240.194.77:5000/rest-node:new rest-multinodes
	```
15. check the upgrading

	```
	docker service ps rest-multinodes
	```


## Practice #6 - REST Docker Solution for SAML Scenario

1. create SAML user `samler` in CS

   ```
   iapi

   create,c,dm_user
   set,c,l,user_name
   samler
   set,c,l,user_login_name
   samler
   set,c,l,user_password
   password
   set,c,l,user_source
   dm_saml
   set,c,l,user_privileges
   16
   save,c,l
   ```

   *if the CS is in container, need to  run `source .../dm_set_server_env.sh` before `iapi`*

2. modify SAML configuration of CS

   ```
   vi .../saml.properties
   ```

   ```
   stackTrace = True
   certPath = /home/SAML/cert
   responseSkew = 60
   ```

   and make the corresponding directory

   ```
   mkdir -p /home/SAML/cert
   ```

   ​

3. clone the repository 

   ```
   git clone https://github.com/wangc31/docker-ispecialist.git ~/tmp
   ``` 

4. change to the work directory

   ```
   cd ~/tmp/saml-docker-compose
   ```

5. copy IdP signing cert to CS

   *if Content Server is in container cs*

   ```
   docker cp idp/shibboleth-idp/credentials/idp-signing.crt [CS]:/home/SAML/cert
   ```

   *or you need to copy it in other ways*

6. edit `dfc.properties` for REST

   ```
   vi ~/tmp/saml-docker-compose/rest/config/dfc.properties
   ```

   ​

7. start docker compose

   ```
   docker-compose up --build
   ```

   ​

8. login the client - open browser to visit `[DOCKER_HOST]:6080/vnc.html` (no password)

9. launch a firefox in the client and visit `https://rest-docker:8443/dctm-rest/repositories`

10. follow the response to visit one repository resource; it will redirect to IdP login page

11. the credential is `samler/passw0rd` 

12. after passing IdP verification, it will redirect back to REST services

*The authentication could fail on some Docker hosts (encrypt provider load issue), restart the rest container will workaround the issue `docker restart rest`*

## A Tiny Tool
Sometimes we want to pull images from individual registry, but don't know which images are available.
This is a tiny tool which can be always running in background.  

1. clone the project
	```
	git clone https://github.com/wangc31/docker-registry-viewer.git ~/registry-viewer
	```
2. change to the project folder  
```
cd ~/registry-viewer
```  
3. build the image  
```
docker build -t registry-viewer .
```  
4. run the registry viewer  
```
docker run --rm -p 5000:5000 --env REGISTRY_HOST=http://[REGISTRY_HOST]:[REGISTRY_PORT] registry-viewer
```  
5. view the registry `http://localhost:5000`
