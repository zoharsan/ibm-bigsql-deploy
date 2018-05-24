# ibm-bigsql-deploy

This repository provides the artifacts to automate a single node installation of IBM BigSQL on top of HDP.

## Prerequisites

- This script deploys latest IBM BigSQL 5.0.2 on top of the latest HDP 2.6.5 using Ambari 2.6.1.0, along with IBM Data Server Manager. The script also deploys an IBM BigSQL sample demo data set, as well as a Zeppelin jdbc based bigsql interpreter.
- This script has been tested on Hortonworks private Field Cloud, as well Amazon AWS using CentOS 7 image.
- The minimum specs for the VM are 2 to 4 cores, 16 GB RAM, and 20GB Storage if only HDP+BigSQL are installed.
  - Minimum VM required on AWS is m4.xlarge.
  - Minimum VM required on Hortonworks private FieldCloud is m3.xlarge.
- These 3 files are needed for the installation to succeed:
  - The shell script install_hdp_bigsql_final.sh
  - The python script shell.bigsql.py
  - The BigSQL binary ibmdb2bigsqlnpe_5.0.2.bin. You need to obtain the IBM BigSQL 5.0.2 binary from IBM Passport Advantage, or other means.
- The script needs to be ran as root to simplify installation.

## Instructions
The following variables in the script help control the components to install:
```
#Components to install 0 for yes 1 for no
export deploybasestack=0  #Base HDP stack
export pwdlesssh=0        #Passwordless ssh
export bigsql=0           #BigSQL
export dsm=0              #IBM Data Server Manager Console
export sampleds=0         #Deploys the Outdoor Company sample data set
export bigsqlzep=0        #Deploys a Zeppelin BigSQL jdbc based interpreter
```
Please point the bigsqlbinary variable to the absolute path of the BigSQL binary:
```
export bigsqlbinary=${bigsqlbinary:-/root/ibmdb2bigsqlnpe_5.0.2.bin}
```
Run the script as following:
```
sudo -i
cp /tmp/ibmdb2bigsqlnpe_5.0.2.bin /root
chmod +x /root/ibmdb2bigsqlnpe_5.0.2.bin
yum install -y git
git clone https://github.com/zoharsan/ibm-bigsql-deploy.git
cd ibm-bigsql-deploy
chmod +x *bigsql*
./install_hdp_bigsql_final.sh
```

Depending on the VM performance, the installation can take anywhere between 40 minutes to 1 hour. If deploying the sample data set, it could take up to an extra hour.

## Additional Resources
IBM BigSQL 5.0.2 Documentation:
https://www.ibm.com/support/knowledgecenter/en/SSCRJT_5.0.2/com.ibm.swg.im.bigsql.welcome.doc/doc/welcome.html


