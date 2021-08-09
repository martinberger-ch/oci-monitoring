# Installation Guide for OCI Monitoring - DRAFT

Note: This is an experimental environment!

Installs a basic OCI monitoring solution with these components based on Ansible in Oracle Linux 8. The setup is tested for

- OL8 running in ESXi
- OL8 running in local VmWare

OL8 is a base installation.

Installed components by Ansible roles:

- Docker
- Steampipe
- Grafana
- Prometheus
- Push Gateway
- PostgreSQL

-> PLACEHOLDER FOR IMAGE

## Prerequisites

- root access by password
- /etc/hosts configured
- Ansible and Git configured
- Internet access

```bash
yum -y install yum-utils
yum -y install oracle-epel-release-el8
yum-config-manager --enable ol8_developer_EPEL
yum -y install ansible git
```

## Steps

1. Login as OS user root into Oracle Linux 8
2. Clone the repository to a local folder like /root/git
3. Change to subdirectory oci-monitoring
4. Adapt Ansible _hosts_ file with your ip and root password (ansible_ssh_pass) - required for local connections
5. Run _ansible-galaxy collection install -r roles/requirements.yml_
6. Run _ansible-playbook install.yml_

As OS user root, verify is all Docker containers are running:

```bash
# docker ps
CONTAINER ID   IMAGE              COMMAND                  CREATED             STATUS             PORTS                    NAMES
f7f2e137f4a1   prom/pushgateway   "/bin/pushgateway"       About an hour ago   Up About an hour   0.0.0.0:9091->9091/tcp   pushgateway
c6ecc72065c9   prom/prometheus    "/bin/prometheus --c…"   About an hour ago   Up About an hour   0.0.0.0:9090->9090/tcp   prometheus
3485de8cc1f9   grafana/grafana    "/run.sh"                About an hour ago   Up About an hour   0.0.0.0:3000->3000/tcp   grafana
8e821aa0044b   turbot/steampipe   "docker-entrypoint.s…"   About an hour ago   Up 30 minutes      0.0.0.0:9193->9193/tcp   steampipe
```

### Network Security

The Ansible playbooks open additionally these ports in the VM for access:

- 3000 - Grafana
- 9090 - Prometheus
- 9091 - Prometheus Push Gateway
- 9093 - Steampipe Service

## OCI Configuration

After the Ansible execution, put your personal OCI configuration and SSH key into directory ~/.oci. Replace the dummy values. Adapt file /home/steampipe/config/oci.spc with the correct SSH key file name.

Take care that owner and group of the OCI configuration file is OS user _steampipe_.

Example:

```bash
# pwd
/home/steampipe/.oci

# ll
total 8
-rw-r--r--. 1 steampipe steampipe  307 Aug  9 09:01 config
-rw-r--r--. 1 steampipe steampipe 1730 Aug  9 09:01 jurasuedfuss-20210809.pem
```

Restart Docker container for Steampipe:

```bash
# docker stop steampipe
# docker start steampipe
```

## Note: How to create the user for OCI access - based on OCI CLI

Here we create an OCI user for monitoring, and existing OCI CLI setup for an tenant administrator is required to execute the steps. The required SSH key in PEM format can be downloaded in OCI web interface. The user, group and policy can be created iun web interface too. All we need for steampipe is the OCI config file for the new user and his SSH key in PEM format.

### Create User

```bash
oci iam user create --name oci_user_readonly --description "OCI User with inspect all-resources." 
```

### Create Group

```bash
oci iam group create --name oci_group_readonly --description "OCI Group with inspect all-resources."
```

### Add User to Group

```bash
oci iam group add-user \
--user-id <your user OCID from created user above> \
--group-id <your group OCID from created group above> \
```

### Create Policy

```bash
oci iam policy create \
--compartment-id <your tenancy OCID> \
--name oci_policy_readonly \
--description "OCI Policy with inspect all-resources." \
--statements '[ "allow group oci_group_readonly to inspect all-resources on tenancy" ]' \
```

### Add API Key

![OCI API Key 01](images/oci_api_key_01.png)

Add API key.

![OCI API Key 02](images/oci_api_key_02.png)

Download the created private key in PEM format.

![OCI API Key 03](images/oci_api_key_03.png)

Copy the configuration file preview, the values are used for Steampipe OCI configuration.

## Steampipe

Here some commands to verify if streampipe is working properly and the connections works as expected. Execute as OS user root:

```bash
# docker exec -it steampipe steampipe plugin list
+--------------------------------------------+---------+---------------------------+
| Name                                       | Version | Connections               |
+--------------------------------------------+---------+---------------------------+
| hub.steampipe.io/plugins/turbot/oci@latest | 0.1.0   | oci_tenant_trivadisbdsxsp |
+--------------------------------------------+---------+---------------------------+
```

```bash
# docker exec -it steampipe steampipe query "select display_name,shape,region from oci_core_instance where lifecycle_state='RUNNING';"
+-----------------------------------+------------------------+----------------+
| display_name                      | shape                  | region         |
+-----------------------------------+------------------------+----------------+
| Instance-DB-1                     | VM.Standard1.2         | eu-frankfurt-1 |
| Instance-AS-1                     | VM.Standard1.1         | eu-frankfurt-1 |
+-----------------------------------+------------------------+----------------+
```

```bash
# docker exec -it steampipe steampipe query "select key,title,status from oci_region where is_home_region=true;"
+-----+----------------+--------+
| key | title          | status |
+-----+----------------+--------+
| FRA | eu-frankfurt-1 | READY  |
+-----+----------------+--------+
```

## Python Example Scripts

In subdirectory there are two basic examples how to get the data by Steampipe PostgreSQL service in Python3. Feel free to adapt the queries and files. Returned values are pushed to Prometheus Gateway to port 9091.

| Script                                 | Purpose                                              |   |   |   |
|----------------------------------------|------------------------------------------------------|---|---|---|
| pgsql-query-bv-zurich.py               | Summary of Block Volume in OCI Region Zurich         |   |   |   |
| pgsql-query-ci-running-zurich.py       | Summary of running Instances in OCI Region Zurich    |   |   |   |

## Troubleshooting

Coming soon...
