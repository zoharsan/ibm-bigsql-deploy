# ibm-bigsql-deploy

This repository provides the artifacts to automate a single node installation of IBM BigSQL on top of HDP.

## Prerequisites

- This script deploys HDP 2.6.4 with IBM BigSQL 5.0.2 using Ambari 2.6.1.0.
- This script has been tested on Hortonworks private Field Cloud, as well Amazon AWS using CentOS 7 image.
- The minimum specs for the VM are 2 to 4 cores, 16 GB RAM if only HDP+BigSQL are installed.
  - Minimum VM required on AWS is m4.xlarge.
  - Minimum VM required on Hortonworks private FieldCloud is m3.xlarge.
-These 3 files are needed for the installation to succeed:
  - The shell script install_hdp_bigsql_final.sh
  - The python script shell.bigsql.py
  - The BigSQL binary ibmdb2bigsqlnpe_5.0.2.bin. You need to obtain the IBM BigSQL 5.0.2 binary from IBM Passport Advantage, or other means.
- The script needs to be ran as root to simplify installation.

## Instructions


