#!/bin/bash

#To run - export any variables then execute below:
#curl -sSL https://gist.github.com/abajwa-hw/7794ea013c96f3f41c4a8b10aeeccd4d/raw | sudo -E sh 

set -x

#Registry Variables
export ambari_password=${ambari_password:-BadPass#1}     #Ambari password
export AMBARI_PWD=${ambari_password}
export CLUSTER_NAME=hdp
export host_count=${host_count:-1}   #choose number of nodes
export ambari_services=${ambari_services:-HDFS HIVE PIG SPARK MAPREDUCE2 TEZ YARN ZOOKEEPER ZEPPELIN HBASE KNOX SQOOP SLIDER}  #AMBARI_METRICS can be added post-install
export hdp_ver=${hdp_ver:-2.6}
export ambari_version=2.6.1.0 #Do not choose 2.6.1.5 as there are some sporadic ambari-agent crashes during BigSQL installation.

export HOST_FQDN=`hostname -f`
export AMBARI_HOST=localhost

export bigsqlbinary=${bigsqlbinary:-/root/ibmdb2bigsqlnpe_5.0.2.bin}

#Components to install 0 for yes 1 for no
export deploybasestack=0
export pwdlesssh=0
export bigsql=0
export dsm=0
export sampleds=0
export bigsqlzep=0

waitForServiceToStart () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED ]]; then
        	until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 10
        done
       	fi
}

waitForServiceToInstall () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == INSTALLED ]]; then
        	until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == INSTALLED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 20
        done
       	fi
}

getServiceStatus () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $SERVICE_STATUS
}


stopService () {
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Stopping Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == STARTED ]; then
        TASKID=$(curl -u admin:$AMBARI_PWD -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Stop $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"INSTALLED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Stop $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Stop $SERVICE Task Status $TASKSTATUS"
            sleep 5
        done
        echo "*********************************$SERVICE Service Stopped..."
       	elif [ "$SERVICE_STATUS" == INSTALLED ]; then
       	echo "*********************************$SERVICE Service Stopped..."
       	fi
}

startService () {
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:$AMBARI_PWD -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Start $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:$AMBARI_PWD -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            if [ "$SERVICE" == HDFS ]; then
            		if [ `hdfs dfsadmin -safemode get | grep 'Safe mode is ON' | wc -l` -eq 1 ]; then
            	    	su - hdfs -c 'hdfs dfsadmin -safemode leave'
            	    fi
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 5
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

SetPasswordlessSsh() {

filename="id_rsa"
path="$HOME/.ssh"
host_name=`hostname -f`
username=root

# Generate rsa files
if [ -f $path/$filename ]
then
    echo "RSA key exists on $path/$filename, using existing file"
else
    ssh-keygen -t rsa -f "$path/$filename" -q -N ""
    echo RSA key pair generated
fi

cat "$path/$filename.pub" >> $path/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

echo "Testing passwordless ssh"

ssh -o "StrictHostKeyChecking no" "$host_name" -l "$username" 'echo Test_OK'
status=$?

if [ $status -eq 0 ]
then
    echo "Set up complete"
else
    echo "an error has occured"
fi

}

InstallBigSql() {

#Create BigSQL Service
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services/BIGSQL

#Create BIGSQL_HEAD Component
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services/BIGSQL/components/BIGSQL_HEAD

#CREATE BIGSQL_WORKER Component
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services/BIGSQL/components/BIGSQL_WORKER

#Create BiSQL Configuration bigsql-env
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type": "bigsql-env", "tag": "INITIAL", "version": 1, "properties": { "bigsql_continue_on_failure": "true", "bigsql_db_path": "/var/ibm/bigsql/database", "bigsql_ha_port": "20008", "bigsql_hdfs_poolname": "autocachepool", "bigsql_hdfs_poolsize": "0", "bigsql_initial_install_mln_count": "1", "bigsql_java_heap_size": "2048", "bigsql_log_dir": "/var/ibm/bigsql/logs", "bigsql_mln_inc_dec_count": "1", "bigsql_resource_percent": "25", "db2_fcm_port_number": "28051", "db2_port_number": "32051","dfs.datanode.data.dir": "/hadoop/hdfs/data","enable_auto_log_prune": "true","enable_auto_metadata_sync": "true","enable_impersonation": "false","enable_metrics": "false", "enable_yarn": "false","public_table_access": "false","scheduler_admin_port": "7054","scheduler_service_port": "7053"}, "properties_attributes": { "final": { "fs.defaultFS": "true" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL Configuration bigsql-users-env
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d "{ \"type\" : \"bigsql-users-env\", \"tag\" : \"INITIAL\", \"version\" : 1, \"properties\" : { \"ambari_user_login\" : \"admin\", \"ambari_user_password\" : \"$AMBARI_PWD\", \"bigsql_admin_group_name\" : \"bigsqladm\", \"bigsql_admin_group_id\" : "43210", \"bigsql_user\" : \"bigsql\", \"bigsql_user_id\" : \"2824\", \"bigsql_user_password\" : \"bigsql\", \"enable_ldap\" : \"false\", \"bigsql_setup_ssh\" : \"true\" }, \"properties_attributes\" : { \"ambari_user_password\" : { \"toMask\" : \"false\" }, \"bigsql_user_password\" : { \"toMask\" : \"false\" } }}" http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL Configuration bigsql-slider-env
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type" : "bigsql-slider-env","tag" : "INITIAL", "version" : 1, "properties" :{ "bigsql_container_mem" : "4192", "bigsql_container_vcore" : "2", "bigsql_yarn_label" : "bigsql", "bigsql_yarn_queue" : "default", "enforce_single_container" : "false", "use_yarn_node_labels" : "false" }}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL Configuration bigsql-slider-flex
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type" : "bigsql-slider-flex", "tag" : "INITIAL", "version" : 1, "properties" : { "bigsql_capacity" : "70" }}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL bigsql-head-env
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{  "type" : "bigsql-head-env", "tag" : "INITIAL",  "version" : 1, "properties" : { "bigsql_active_primary" : "localhost" } }' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL Configuration bigsql-conf
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type" : "bigsql-conf", "tag" : "INITIAL", "version" : 1, "properties" : { "biginsights.stats.auto.analyze.concurrent.max" : "1", "biginsights.stats.auto.analyze.newdata.min" : "50", "biginsights.stats.auto.analyze.post.load" : "ONCE", "biginsights.stats.auto.analyze.post.syncobj" : "DEFERRED", "biginsights.stats.auto.analyze.task.retention.time" : "1MONTH", "bigsql.load.jdbc.jars" : "/tmp/jdbcdrivers", "fs.sftp.impl" : "org.apache.hadoop.fs.sftp.SFTPFileSystem", "javaio.textfile.extensions" : ".snappy,.bz2,.deflate,.lzo,.lz4,.cmx", "scheduler.autocache.ddlstate.file" : "/var/ibm/bigsql/logs/.AutoCacheDDLStateDoNotDelete", "scheduler.autocache.poolname" : "autocachepool", "scheduler.autocache.poolsize" : "0", "scheduler.cache.exclusion.regexps" : "None", "scheduler.cache.splits" : "true", "scheduler.client.request.IUDEnd.timeout" : "600000", "scheduler.client.request.timeout" : "120000", "scheduler.java.opts" : "-Xms512M -Xmx2G", "scheduler.log4j.server" : "false","scheduler.log4j.server.port" : "-1", "scheduler.maxWorkerThreads" : "1024", "scheduler.minWorkerThreads" : "8", "scheduler.parquet.rgSplits" : "true", "scheduler.parquet.rgSplits.minFileSize" : "2147483648", "scheduler.service.timeout" : "3600000", "scheduler.tableMetaDataCache.numTables" : "1000", "scheduler.tableMetaDataCache.timeToLive" : "1200000" }, "properties_attributes" : { }}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL Configuration bigsql-logsearch-conf
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type" : "bigsql-logsearch-conf", "tag" : "INITIAL", "version" : 1, "properties" : { "component_mappings" : "BIGSQL_HEAD:bigsql_fmp,bigsql_scheduler;BIGSQL_WORKER:bigsql_fmp", "content" : "\n{\n  \"input\":[\n    {\n     \"type\":\"bigsql_server\",\n     \"rowtype\":\"service\",\n     \"path\":\"/var/ibm/bigsql/logs/bigsql.log*\"\n    },\n    {\n     \"type\":\"bigsql_scheduler\",\n     \"rowtype\":\"service\",\n     \"path\":\"/var/ibm/bigsql/logs/bigsql-sched.log*\"\n    }\n  ],\n  \"filter\":[\n   {\n      \"filter\":\"grok\",\n      \"conditions\":{\n        \"fields\":{\n            \"type\":[\n                \"bigsql_server\",\n                \"bigsql_scheduler\"\n              ]\n            }\n      },\n      \"log4j_format\":\"%d{ISO8601} %p %c [%t] : %m%n\",\n      \"multiline_pattern\":\"^(%{TIMESTAMP_ISO8601:logtime})\",\n      \"message_pattern\":\"(?m)^%{TIMESTAMP_ISO8601:logtime}%{SPACE}%{LOGLEVEL:level}%{SPACE}%{JAVACLASS:logger_name}%{SPACE}\\\\[%{DATA:thread_name}\\\\]%{SPACE}:%{SPACE}%{GREEDYDATA:log_message}\",\n      \"post_map_values\":{\n        \"logtime\":{\n         \"map_date\":{\n          \"target_date_pattern\":\"yyyy-MM-dd HH:mm:ss,SSS\"\n         }\n       }\n     }\n    }\n   ]\n}", "service_name" : "IBM Big SQL" }, "properties_attributes" : { } }' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Create BigSQL bigsql-log4j
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{  "type" : "bigsql-log4j", "tag" : "INITIAL", "version" : 1, "properties" : { "bigsql_log4j_content" : "\n# This file control logging for all Big SQL Java I/O and support processes\n# housed within FMP processes\nlog4j.rootLogger=WARN,verbose\n\nlog4j.appender.verbose=com.ibm.biginsights.bigsql.log.SharedRollingFileAppender\nlog4j.appender.verbose.file={{bigsql_log_dir}}/bigsql.log\nlog4j.appender.verbose.jniDirectory=/usr/ibmpacks/current/bigsql/bigsql/lib/native\nlog4j.appender.verbose.pollingInterval=30000\nlog4j.appender.verbose.layout=com.ibm.biginsights.bigsql.log.SharedServiceLayout\nlog4j.appender.verbose.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.verbose.MaxFileSize={{bigsql_log_max_backup_size}}MB\nlog4j.appender.verbose.MaxBackupIndex={{bigsql_log_number_of_backup_files}}\n\n# Setting this to DEBUG will cause ALL queries to be traced, INFO will cause\n# only sessions that specifically request it to be traced\nlog4j.logger.bigsql.query.trace=INFO\n\n# Silence warnings about trying to override final parameters\nlog4j.logger.org.apache.hadoop.conf.Configuration=ERROR\n\n# log4j.logger.com.ibm.biginsights.catalog=DEBUG\n# log4j.logger.com.ibm.biginsights.biga=DEBUG", "bigsql_log_max_backup_size" : "32", "bigsql_log_number_of_backup_files" : "15", "bigsql_scheduler_log4j_content" : "\n# Logging is expensive, so by default we only log if the level is >= WARN.\n# If you want any other logging to be done, you need to set the below 'GlobalLog' logger to DEBUG,\n# plus any other logger settings of interest below.\nlog4j.logger.com.ibm.biginsights.bigsql.scheduler.GlobalLog=WARN\n\n# Define the loggers\nlog4j.rootLogger=WARN,verbose\nlog4j.logger.com.ibm.biginsights.bigsql.scheduler.server.RecurringDiag=INFO,recurringDiagInfo\nlog4j.additivity.com.ibm.biginsights.bigsql.scheduler.server.RecurringDiag=false\n\n# Suppress unwanted messages\n#log4j.logger.javax.jdo=FATAL\n#log4j.logger.DataNucleus=FATAL\n#log4j.logger.org.apache.hadoop.hive.metastore.RetryingHMSHandler=FATAL\n\n# Verbose messages for debugging purpose\n#log4j.logger.com.ibm=ALL\n#log4j.logger.com.thirdparty.cimp=ALL\n#log4j.logger.com.ibm.biginsights.bigsql.io=WARN\n#log4j.logger.com.ibm.biginsights.bigsql.hbasecommon=WARN\n#log4j.logger.com.ibm.biginsights.catalog.hbase=WARN\n\n# Uncomment this to print table-scan assignments (node-number to number-of-blocks)\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Assignment=DEBUG\n\n# setup the verbose logger\nlog4j.appender.verbose=org.apache.log4j.RollingFileAppender\nlog4j.appender.verbose.file={{bigsql_log_dir}}/bigsql-sched.log\nlog4j.appender.verbose.layout=org.apache.log4j.PatternLayout\nlog4j.appender.verbose.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.verbose.MaxFileSize={{bigsql_log_max_backup_size}}MB\nlog4j.appender.verbose.MaxBackupIndex={{bigsql_log_number_of_backup_files}}\n\n# setup the recurringDiagInfo logger\nlog4j.appender.recurringDiagInfo=org.apache.log4j.RollingFileAppender\nlog4j.appender.recurringDiagInfo.file={{bigsql_log_dir}}/bigsql-sched-recurring-diag-info.log\nlog4j.appender.recurringDiagInfo.layout=org.apache.log4j.PatternLayout\nlog4j.appender.recurringDiagInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\nlog4j.appender.recurringDiagInfo.MaxFileSize=10MB\nlog4j.appender.recurringDiagInfo.MaxBackupIndex=1\n\n# Setting this to DEBUG will cause ALL queries to be traced, INFO will cause\n# only sessions that specifically request it to be traced\nlog4j.logger.bigsql.query.trace=INFO\n\n# Silence hadoop complaining about forcing hive properties\nlog4j.logger.org.apache.hadoop.conf.Configuration=ERROR\n\n# Uncomment and restart bigsql to get the details. Use INFO for less detail, DEBUG for more detail, TRACE for even more\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Dev.Assignment=DEBUG,AssignStatInfo\n#log4j.appender.AssignStatInfo=org.apache.log4j.RollingFileAppender\n#log4j.appender.AssignStatInfo.file={{bigsql_log_dir}}/dev_pestats.log\n#log4j.appender.AssignStatInfo.layout=org.apache.log4j.PatternLayout\n#log4j.appender.AssignStatInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\n#log4j.appender.AssignStatInfo.MaxFileSize=10MB\n#log4j.appender.AssignStatInfo.MaxBackupIndex=1\n\n# Uncomment and restart bigsql to get the details. Use INFO for less detail, DEBUG for more detail, TRACE for even more\n#log4j.logger.com.ibm.biginsights.bigsql.scheduler.Dev.PEStats=DEBUG,PEStatInfo\n#log4j.appender.PEStatInfo=org.apache.log4j.RollingFileAppender\n#log4j.appender.PEStatInfo.file={{bigsql_log_dir}}/dev_pestats.log\n#log4j.appender.PEStatInfo.layout=org.apache.log4j.PatternLayout\n#log4j.appender.PEStatInfo.layout.ConversionPattern=%d{ISO8601} %p %c [%t] : %m%n\n#log4j.appender.PEStatInfo.MaxFileSize=10MB\n#log4j.appender.PEStatInfo.MaxBackupIndex=1" }, "properties_attributes" : { } }' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Apply BigSQL Configuration
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-env", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-users-env", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-slider-env", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-slider-flex", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-head-env", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-conf", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-logsearch-conf", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "bigsql-log4j", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

#Create host components for BIGSQL_HEAD
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST_FQDN/host_components/BIGSQL_HEAD

#Create host components for BIGSQL_WORKER
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST_FQDN/host_components/BIGSQL_WORKER

#Install BigSQL
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -i -X PUT -d '{ "RequestInfo": { "context": "Install BigSQL service " }, "Body": { "ServiceInfo": { "state": "INSTALLED" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services/BIGSQL
}

InstallDSM() {

#Create DATASERVERMANAGER Service
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/hdp/services/DATASERVERMANAGER

#Create DSM_Master Component
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/hdp/services/DATASERVERMANAGER/components/DSM_Master

#Create DSM Configuration dsm-config
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST -d '{ "type": "dsm-config", "tag": "INITIAL", "version": 1, "properties": { "dsm_admin_user": "admin", "dsm_server_port": "11080", "dsm_user": "dsmuser", "dsm_group": "hadoop" }, "properties_attributes": { "final": { "dsm_user": "true", "dsm_group": "true" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/configurations

#Apply DSM Configuration
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X PUT -d '{ "Clusters": { "desired_configs": { "type": "dsm-config", "tag": "INITIAL" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME

#Create host components for DSM_Master
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -X POST http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST_FQDN/host_components/DSM_Master

#Install IBM DSM
curl -u admin:$AMBARI_PWD -i -H "X-Requested-By: ambari" -i -X PUT -d '{ "RequestInfo": { "context": "Install IBM Data Server Manager" }, "Body": { "ServiceInfo": { "state": "INSTALLED" }}}' http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services/DATASERVERMANAGER

}

DeploySampleDataSet() {

cat << EOF > sample_setup.txt
bigsql
EOF
su - bigsql -c '/usr/ibmpacks/bigsql/5.0.2.0/bigsql/samples/setup.sh -u bigsql -s `hostname -f` -n 32051 -d BIGSQL' < sample_setup.txt

}

CreateBigsqlZeppelin() {

export sessionid=`curl -i --data 'userName=admin&password=admin' -X POST http://localhost:9995/api/login | grep JSESSIONID | grep -v deleteMe | tail -1| sed 's/Set-Cookie: //g' | awk '{ print $1 }'`
curl -i  -b $sessionid -X POST -d '{ name: "bigsql", group: "jdbc", properties: { default.password: "bigsql", default.user: "bigsql",  default.url: "jdbc:db2://localhost:32051/bigsql", default.driver: "com.ibm.db2.jcc.DB2Driver", common.max_count: "1000" }, interpreterGroup: [ { name: "sql", class: "org.apache.zeppelin.jdbc.JDBCInterpreter" }], dependencies: [ { groupArtifactVersion: "/usr/ibmpacks/current/bigsql/db2/java/db2jcc.jar" }]}' http://localhost:9995/api/interpreter/setting

}

if [ $deploybasestack -eq 0 ]
then
yum install -y git python-argparse mysql-connector-java* ksh redhat-lsb-core
cd ~
git clone https://github.com/seanorama/ambari-bootstrap.git

#remove unneeded repos for some AMIs
if [ -f /etc/yum.repos.d/zfs.repo ]; then
  rm -f /etc/yum.repos.d/zfs.repo
fi

if [ -f /etc/yum.repos.d/lustre.repo ]; then
  rm -f /etc/yum.repos.d/lustre.repo
fi  
	
#install MySql community rpm
sudo rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

export install_ambari_server=true

curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/ambari-bootstrap.sh | sudo -E sh

echo "Waiting 30s for Ambari to come up..."
sleep 30

#echo "Changing Ambari password..." 
curl -iv -u admin:admin -H "X-Requested-By: Ambari" -X PUT -d "{ \"Users\": { \"user_name\": \"admin\", \"old_password\": \"admin\", \"password\": \"${AMBARI_PWD}\" }}" http://localhost:8080/api/v1/users/admin

sudo ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar

if [ $bigsql -eq 0 ]
then
	#Circumventing code page conversion issues with utf8 in bigsql installation script
	cp /usr/lib/python2.6/site-packages/resource_management/core/shell.py /usr/lib/python2.6/site-packages/resource_management/core/shell.py.orig
	cp shell.bigsql.py /usr/lib/python2.6/site-packages/resource_management/core/shell.py
fi

#echo "Setting recommendation strategy..."
export ambari_stack_version=${hdp_ver}
export recommendation_strategy="ALWAYS_APPLY_DONT_OVERRIDE_CUSTOM_VALUES"

#echo "Generating BP and deploying cluster..."
cd ~/ambari-bootstrap/deploy
cat << EOF > configuration-custom.json
{
  "configurations" : {
    "core-site": {
        "hadoop.proxyuser.root.users" : "admin",
        "fs.trash.interval": "4320"
    },
    "hdfs-site": {
      "dfs.replication": "1",
      "dfs.namenode.safemode.threshold-pct": "0.99"
    },
    "hive-site": {
        "hive.server2.transport.mode" : "binary"
    }
 }
}
EOF
	
./deploy-recommended-cluster.bash

fi
 

if [ $bigsql -eq 0 ]
then
if [ $deploybasestack -eq 0 ]
then
 #Sleeping for a good 10 minutes before 'are we there yet'
 echo "Sleeping for 13 mins before starting BigSQL installation"
 echo "Logon to Ambari at URL http://"$HOST_FQDN":8080 using credentials admin/"$AMBARI_PWD "to monitor progress"
 sleep 780

#Wait for core services to install before attempting BigSQL installation
waitForServiceToStart HDFS

waitForServiceToStart YARN

waitForServiceToStart HIVE

waitForServiceToStart ZOOKEEPER

waitForServiceToStart HBASE

waitForServiceToStart KNOX
fi

#set passwordless ssh
if [ $pwdlesssh -eq 0 ]
then 
   SetPasswordlessSsh
fi

#Install BigSQL Package
echo "Installing BigSQL Package" ${bigsqlbinary} "..."
chmod +x ${bigsqlbinary}
cat << EOF > input_bigsql_package_install.txt
y
1
n
EOF
${bigsqlbinary} < input_bigsql_package_install.txt

#Enable BigSQL Extension
echo "Enabling BigSQL Extension..."
cd /var/lib/ambari-server/resources/extensions/IBM-Big_SQL/5.0.2.0/scripts/
cat << EOF > input_bigsql_ext.txt
y
EOF

./EnableBigSQLExtension.py -u admin -p $AMBARI_PWD < input_bigsql_ext.txt

#Run BigSQL precheck utility
/var/lib/ambari-server/resources/extensions/IBM-Big_SQL/5.0.2.0/services/BIGSQL/package/scripts/bigsql-precheck.sh -V

#Bigsql requires write to /hadoop/hdfs/data. Doing it this way for now as bigsql user may not exist
chmod 770 /hadoop/hdfs/data

#Check ambari-agent status and start if needed
if [ `ambari-agent status | grep 'not running' | wc -l` -eq 1 ]
then
    echo "ambari-agent has crashed ! Not Good ! Restarting it..."
    ambari-agent start
	sleep 10
fi

#Install BigSQL
InstallBigSql

echo "Give it a good 18 minutes for BigSQL to install before waking up and checking status. This installation can take up to 1 hour."
sleep 1080

#Starting BIGSQL Service
waitForServiceToInstall BIGSQL

#Give it 10 seconds for Bigsql SSH setup to complete
sleep 15

#Fixing permissions on /hadoop/hdfs/data
echo "Fixing permissions on /hadoop/hdfs/data the proper way before starting the service"
chmod 750 /hadoop/hdfs/data
setfacl -m user:bigsql:rwx /hadoop/hdfs/data

#Starting BIGSQL
startService BIGSQL

#Start Demo LDAP
curl -i -u admin:$AMBARI_PWD -H "X-Requested-By: Ambari" -X POST -d "{\"RequestInfo\":{\"context\":\"Start Demo LDAP\",\"command\":\"STARTDEMOLDAP\"},\"Requests/resource_filters\":[{\"service_name\":\"KNOX\",\"component_name\":\"KNOX_GATEWAY\",\"hosts\":\"$HOST_FQDN\"}]}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests
sleep 15
fi

if [ $dsm -eq 0 ]
then

echo "Deploying IBM Data Server Manager..."
InstallDSM

#Wait for DSM to install
waitForServiceToInstall DATASERVERMANAGER

#Starting DSM
startService DATASERVERMANAGER

#Setup Knox
/usr/ibmpacks/bin/3.0.8.453/knox_setup.sh -u admin -p $AMBARI_PWD -y

echo "DSM Install Complete. Please use credentials admin/admin-password to login to DSM..."
echo "************************************************************************************"
	
fi

if [ $bigsqlzep -eq 0 ]
then
echo "Creating bigsql Zeppelin interpreter..."
CreateBigsqlZeppelin
fi

echo "Final Step: Recycling Hadoop services left in an inconsistent state..."

#Recycling Services left in inconsistent state
stopService YARN
startService YARN

stopService MAPREDUCE2
startService MAPREDUCE2

stopService HIVE
startService HIVE

stopService HBASE
startService HBASE

stopService HDFS
startService HDFS

if [ $sampleds -eq 0 ]
then
echo "Deploying BigSQL Sample Data set..."
DeploySampleDataSet
fi

echo "Installation Complete... Your bigsql credentials are user:bigsql, password:bigsql... Enjoy"
