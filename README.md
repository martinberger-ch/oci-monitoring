# Installation Guide for OCI Monitoring with Steampipe.io

This guide shows you how to install and setup a nice monitoring solution based on Steampipe.io, Docker and Co.

Steampipe - select * from cloud - is a powerful tool where you can interact to Cloud providers like Oracle Cloud Infrastructure, Azure, AWS and many more with SQL statements. Steampipe is an open source project and uses plugins to communicate with the providers. In the background, there is a PostgreSQL server running with the Steampipe Postgres Foreign Data Wrapper. The server provides an interface where you can run query against with other languages like Python. In this guide, we install the infrastructure as docker containers, configure the OCI access and gather information by Python scripts to monitor the result in a Grafana dashboard.

This guide is tested in OL 8 running on Oracle Cloud Infrastructure.

## How it works

![Architecture](images/architecture.png)

1. Execute Python script against steampipe.io by SQL syntax
2. Steampipe gathers the information from Oracle Cloud Infrastructure
3. The return value is pushed by the Python script to Prometheus Pushgateway
4. Prometheus scrapes the metric from the Pushgateway
5. Grafana reads the metric from Prometheus data source

## Installed components by Ansible roles

- Docker
- Steampipe
- Grafana
- Prometheus
- Pushgateway
- PostgreSQL

The Docker containers are started by docker-compose.

## New OS User Steampipe added

During the Ansible playbook execution, a new OS user called _steampipe_ is created automatically. This user is used for the OCI CLI and Steampipe.io configuration.

## Links

- [Steampipe](https://steampipe.io/)
- [Steampipe OCI Plugin](https://hub.steampipe.io/plugins/turbot/oci)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm)

## Compute Node Setup

- OL 8 Compute Instance up and running with Internet access
- SSH keys for user _opc_
- /etc/hosts configured (done by OCI)
- Ansible and Git packages installed

![OCI Compute Image](images/oci_compute_instance.jpg)

## Oracle Cloud Infrastructure IAM Requirements

- An OCI User and Group with _read all-resources_ and _request.operation='GetConfiguration'_ privileges is required to run steampipe.io - see section below.

## Oracle Cloud Infrastructure - Create the user for OCI API access - based on OCI CLI

First we need an OCI group, user and policy for monitoring. If you have admin privileges and an
already configured OCI CLI, you can do it by CLI commands.

- OCID of created user
- OCID of the tenancy

User, group and policy can be created in web interface too.

### Create Group

![OCI Group](images/oci_group_readonly.jpg)

```bash
oci iam group create --name oci_group_readonly --description "OCI Group with read all-resources privileges."
```

### Create IAM User

![OCI User](images/oci_user_readonly.jpg)

```bash
oci iam user create --name oci_user_readonly --description "OCI User with read all-resources." 
```

### Add User to Group

![OCI Group](images/oci_group_user.jpg)

```bash
oci iam group add-user \
--user-id <your user OCID from created user above> \
--group-id <your group OCID from created group above>
```

### Create Policy

According Steampipe.io: <https://hub.steampipe.io/plugins/turbot/oci>

![OCI Policy](images/oci_policy_readonly.jpg)

```bash
oci iam policy create \
--compartment-id <your root compartment OCID> \
--name oci_policy_readonly \
--description "OCI Policy with read all-resources." \
--statements '[ "allow group oci_group_readonly to read all-resources on tenancy","allow group oci_group_readonly to manage all-resources in tenancy where request.operation='GetConfiguration'" ]' \
```

### Gather Tenancy OCID Information

The tenancy OCID will be used later for the OCI CLI configuration.

Menu -> Governance & Administration -> Tenancy Details.

![OCI Policy](images/oci_tenancy_ocid.jpg)

## OS Packages - root

### Update the OS and install YUM Packages for Ansible and Git

```bash
sudo su -
dnf upgrade
dnf install -y ansible git
```

## GitHub Clone and Ansible Playbook Execution - opc

### Clone the GitHub repository to a local folder and change to subdirectory

As user _opc_, clone the repository and proceed the further steps.

```bash
mkdir git
cd git
git clone https://github.com/martinberger-ch/oci-monitoring.git

cd oci-monitoring
```

### Install Docker module from the Ansible Galaxy Collection

Installs the community docker module for Ansible.

```bash
ansible-galaxy collection install -r roles/requirements.yml
```

### Run the Ansible Playbook

Creates users and directories, installs required software and configures Docker containers. User is _opc_.

```bash
ansible-playbook install.yml
```

## Verification

Verify all Docker containers are running:

```bash
$ sudo docker ps
CONTAINER ID   IMAGE              COMMAND                  CREATED             STATUS             PORTS                    NAMES
f7f2e137f4a1   prom/pushgateway   "/bin/pushgateway"       About an hour ago   Up About an hour   0.0.0.0:9091->9091/tcp   pushgateway
c6ecc72065c9   prom/prometheus    "/bin/prometheus --c…"   About an hour ago   Up About an hour   0.0.0.0:9090->9090/tcp   prometheus
3485de8cc1f9   grafana/grafana    "/run.sh"                About an hour ago   Up About an hour   0.0.0.0:3000->3000/tcp   grafana
8e821aa0044b   turbot/steampipe   "docker-entrypoint.s…"   About an hour ago   Up 30 minutes      0.0.0.0:9193->9193/tcp   steampipe
```

### Network Security

The Ansible playbooks opens these ports inside the VM for external access. Take care: you need
to open these ports in the OCI VCN Security List too to get web access too.

- 3000 - Grafana
- 9090 - Prometheus
- 9091 - Prometheus Push Gateway
- 9093 - Steampipe Service

### Reachability Verification

Verify if Grafana is reachable by your workstation - IP: <http://your-custom-image-ip:3000>

![Grafana Login](images/grafana_login.jpg)

## OCI CLI - steampipe

As OS user _steampipe_, install the OCI CLI and configure it.

### Install OCI CLI

Install and configure the OCI CLI. Press _Enter_ when asked for directory, scripts, modify profile etc. Do not change the settings.

```bash
sudo su - steampipe
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

### Configure OCI CLI

Execute the setup with your user and tenant OCID, create a new API Signing Key Pair without password. This key is later used in OCI web interface. Do not change other settings and let the default values.

Use these parameters:

- OCID of created user _oci_user_readonly_ from above
- OCID of the tenancy from above
- Your preferred region - e.g.  _eu-zurich-1_.
- Config location: /home/steampipe/.oci/config

Important: Press Y=yes when asked for a new API Signing RSA key pair.

```bash
oci setup config
    This command provides a walkthrough of creating a valid CLI config file.

    The following links explain where to find the information required by this
    script:

    User API Signing Key, OCID and Tenancy OCID:

        https://docs.cloud.oracle.com/Content/API/Concepts/apisigningkey.htm#Other

    Region:

        https://docs.cloud.oracle.com/Content/General/Concepts/regions.htm

    General config documentation:

        https://docs.cloud.oracle.com/Content/API/Concepts/sdkconfig.htm


Enter a location for your config [/home/steampipe/.oci/config]: <ENTER>
Enter a user OCID: <USER OCID>
Enter a tenancy OCID: <TENANCY OCID>
Enter a region by index or name(e.g.
1: af-johannesburg-1, 2: ap-chiyoda-1, 3: ap-chuncheon-1, 4: ap-dcc-canberra-1, 5: ap-hyderabad-1,
6: ap-ibaraki-1, 7: ap-melbourne-1, 8: ap-mumbai-1, 9: ap-osaka-1, 10: ap-seoul-1,
11: ap-singapore-1, 12: ap-sydney-1, 13: ap-tokyo-1, 14: ca-montreal-1, 15: ca-toronto-1,
16: eu-amsterdam-1, 17: eu-dcc-milan-1, 18: eu-frankfurt-1, 19: eu-madrid-1, 20: eu-marseille-1,
21: eu-milan-1, 22: eu-paris-1, 23: eu-stockholm-1, 24: eu-zurich-1, 25: il-jerusalem-1,
26: me-abudhabi-1, 27: me-dcc-muscat-1, 28: me-dubai-1, 29: me-jeddah-1, 30: mx-queretaro-1,
31: sa-santiago-1, 32: sa-saopaulo-1, 33: sa-vinhedo-1, 34: uk-cardiff-1, 35: uk-gov-cardiff-1,
36: uk-gov-london-1, 37: uk-london-1, 38: us-ashburn-1, 39: us-gov-ashburn-1, 40: us-gov-chicago-1,
41: us-gov-phoenix-1, 42: us-langley-1, 43: us-luke-1, 44: us-phoenix-1, 45: us-sanjose-1): <YOUR REGION NUMBER>
Do you want to generate a new API Signing RSA key pair? (If you decline you will be asked to supply the path to an existing key.) [Y/n]: Y
Enter a directory for your keys to be created [/home/steampipe/.oci]: <ENTER>
Enter a name for your key [oci_api_key]: <ENTER>
Public key written to: /home/steampipe/.oci/oci_api_key_public.pem
Enter a passphrase for your private key (empty for no passphrase): <ENTER>
Private key written to: /home/steampipe/.oci/oci_api_key.pem
Fingerprint: 72:ef:ef:ad:32:17:23:ac:4d:3c:04:08:ce:e5:ab:aa
Config written to /home/steampipe/.oci/config


    If you haven't already uploaded your API Signing public key through the
    console, follow the instructions on the page linked below in the section
    'How to upload the public key':

        https://docs.cloud.oracle.com/Content/API/Concepts/apisigningkey.htm#How2


```

### Upload API Key

Copy the content of the public key file created by OCI CLI and add it to the user's API
configuration.

```bash
cat /home/steampipe/.oci/oci_api_key_public.pem
```

![API Key](images/oci_api_key.jpg)

Verify the functionality of the OCI CLI - get a list of subscribed OCI regions:

```bash
oci iam region-subscription list

{
  "data": [
    {
      "is-home-region": true,
      "region-key": "ZRH",
      "region-name": "eu-zurich-1",
      "status": "READY"
    }
  ]

}
```

### File /home/steampipe/config/oci.spc - Steampipe Region Filter - steampipe

The configuration is provided by Ansible and corresponds with the files created during OCI CLI setup. You can rename the connection and filter for your regions. Just edit the file _/home/steampipe/config/oci.spc_ and restart the Steampipe container - example:

```bash
connection "oci" {
  plugin                = "oci"
  config_file_profile   = "DEFAULT"          # Name of the profile
  config_path           = "~/.oci/config"    # Path to config file
  regions               = ["eu-zurich-1"]    # List of regions
}
```

How to restart the Docker container for Steampipe.io as OS user _root_:

```bash
sudo su -
# docker stop steampipe
# docker start steampipe
```

### Steampipe Verification - steampipe

Verify if Steampipe.io is working properly and the OCI plugin is is installed as expected. Execute as OS user _root_:

```bash
# docker exec -it steampipe steampipe plugin list

+--------------------------------------------+---------+-------------+
| Installed Plugin                           | Version | Connections |
+--------------------------------------------+---------+-------------+
| hub.steampipe.io/plugins/turbot/oci@latest | 0.17.2  | oci         |
+--------------------------------------------+---------+-------------+


```

Note: If the _Connections_ columns is empty, restart as user root the steampipe container again and wait a couple of
seconds before re-execute the statement.

```bash
# docker stop steampipe
# docker start steampipe
```

Verify the services are is up and running.

```bash
# docker exec -it steampipe steampipe service status
Steampipe service is running:

Database:

  Host(s):            localhost, 127.0.0.1, 172.18.0.4
  Port:               9193
  Database:           steampipe
  User:               steampipe
  Password:           ********* [use --show-password to reveal]
  Connection string:  postgres://steampipe@localhost:9193/steampipe

Managing the Steampipe service:

  # Get status of the service
  steampipe service status

  # View database password for connecting from another machine
  steampipe service status --show-password

  # Restart the service
  steampipe service restart

  # Stop the service
  steampipe service stop

```

Example query for any running Compute Instances in your defined region.

```bash
# docker exec -it steampipe steampipe query "select display_name,shape,region from oci_core_instance where lifecycle_state='RUNNING';"
+-----------------------+---------------------+-------------+
| display_name          | shape               | region      |
+-----------------------+---------------------+-------------+
| openvpn_access_server | VM.Standard.E2.1    | eu-zurich-1 |
| ci-automation-manager | VM.Standard.E4.Flex | eu-zurich-1 |
| ci-steampipe-v14      | VM.Standard.E4.Flex | eu-zurich-1 |
+-----------------------+---------------------+-------------+
```

Example query for your home region:

```bash
# docker exec -it steampipe steampipe query "select key,title,status from oci_region where is_home_region=true;"
+-----+-------------+--------+
| key | title       | status |
+-----+-------------+--------+
| ZRH | eu-zurich-1 | READY  |
+-----+-------------+--------+
```

Example query for MFA verification:

```bash
# docker exec -it steampipe steampipe query "select name, id, is_mfa_activated from oci_identity_user;"
+-----------------+------------------------+------------------+
| name            | id                     | is_mfa_activated |
+-----------------+------------------------+------------------+
| homer_simpson   | ocid1.user.oc1.aaaa... | false            |
| lisa_simpson    | ocid1.user.oc1.aaaa... | true             |
| ned_flanders    | ocid1.user.oc1.aaaa... | false            |
| nelson_muntz    | ocid1.user.oc1.aaaa... | false            |
+-----------------+------------------------+------------------+
```

Steampipe is now ready to gather data from the Oracle Cloud Infrastructure Account.

## Python Example Scripts

In subdirectory of new add OS user steampipe _/home/steampipe/py_ there are two basic examples with pre-configured PostgreSQL connect string. There you can see how to get the data from Steampipe PostgreSQL service in Python3 and push them to the Prometheus Pushgateway. Feel free to adapt the queries and files. You can verify the pushed data in browser by URL "http://your-public-ip:9091". If the port is not reachable, check your OCI Security List Ingress settings.

| Script                                    | Purpose                                              |
|-------------------------------------------|------------------------------------------------------|
| pgsql-example-block-volume-summary.py     | Summary of Block Volume in OCI Region Zurich         |
| pgsql-example-compute-instance-running.py | Summary of available Instances in OCI Region Zurich  |

Run the script as OS user _steampipe_, example:

```bash
$ cd /home/steampipe/py 
$ python3 psql-example-compute-instance-running.py
Connected to DB.
Query ran
3
Connection closed.
```

Behind the Python script - variables like _steamipe_connect_string are replaced during the Ansible deployment.

```bash
import psycopg2
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from prometheus_client import Summary

# set postgresql connect string
uri = f'{{ steampipe_connect_string }}'

try:
    # verify connection
    con = psycopg2.connect(uri)
    print(f'Connected to DB.')

    try:
        # execute sql query
        cur = con.cursor()
        cur.execute('SELECT sum(size_in_gbs) from oci_core_volume where lifecycle_state=\'AVAILABLE\';')
        print('Query ran')
    except:
        print('Query failed')
        raise
    else:
        # set variable with query return value
        bv_summary = cur.fetchone()[0]
        print(bv_summary)

        if bv_summary is None:
          bv_summary = 0

        # prepare pushgateway
        registry = CollectorRegistry()
        g = Gauge('oci_compute_blockvolumes_summary', 'OCI Compute Block Volumes Summary', registry=registry)
        g.set(int(bv_summary))

        # push data to pushgateway
        push_to_gateway('{{ ansible_default_ipv4.address }}:9091', job='oci_blockvolume', registry=registry)

    finally:
        con.close()
        print(f'Connection closed.')
except Exception as e:
    print('Something went wrong:', e)
```

The result is pushed as a metric, this can be verified on the Pushgateway homepage.

## Prometheus Push Gateway

According the Python script, new data is loaded in Prometheus Push Gateway to port 9091 and scraped by Prometheus port 9090. Example for Protheus Gateway where data is loaded by job _oci_compute_.

![OCI Prometheus Push Gateway 01](images/oci_pushgateway_01.png)

## Grafana

Grafana is reachable by "http://your-public-ip:3000".

- Username: admin
- Password: Welcome1

The Prometheus data source and a basic dashboard are configured during the Grafana Docker setup process. Example for dashboard _OCI Demo - eu-zurich-1_:

Prometheus data source:
![OCI Grafana 01](images/oci_grafana_01.png)

Sample dashboard OCI Demo:
![OCI Grafana 02](images/oci_grafana_02.png)

Here you can see the pushed metric from the Python script by name:
![OCI Grafana 03](images/oci_grafana_03.png)

## Troubleshooting

### Docker Logs

To verify if Steampipe is running properly:

```bash
# docker logs steampipe
```

User steampipe is not able to run docker commands:

```bash
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Get "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/steampipe/json": dial unix /var/run/docker.sock: connect: permission denied

```

Verify if the docker.sock file has permissions 0666 set.

### Steampipe Access Logs

The foreign data wrapper logs are stored locally on the Docker volume:

```bash
[root@ci-steampipe-v14 _data]# pwd
/var/lib/docker/volumes/docker_steampipe_logs/_data

[root@ci-steampipe-v14 _data]# ls -latr
total 24
-rw-r--r--. 1 steampipe root     0 Nov 10 22:39 plugin-2022-11-10.log
-rw-------. 1 steampipe root  6114 Nov 10 22:39 database-2022-11-10.log
drwx-----x. 3 root      root    19 Nov 16 20:18 ..
-rw-r--r--. 1 steampipe root     0 Nov 16 20:19 plugin-2022-11-16.log
drwxr-xr-x. 2 steampipe root   126 Nov 16 20:19 .
-rw-------. 1 steampipe root 16177 Nov 16 20:34 database-2022-11-16.log

```

### Steampipe Restart

```bash
Something went wrong: no connection config loaded for connection 'oci'
```

Restarting Steampipe as OS user root:

```bash
# docker stop steampipe
# docker start steampipe
```

Verify OCI CLI functionality first.
