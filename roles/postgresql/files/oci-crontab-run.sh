#!/bin/bash
/usr/bin/python3 /home/steampipe/py/pgsql-query-bv-frankfurt.py  >> /tmp/pgsql-query-bv-frankfurt.py.log
/usr/bin/python3 /home/steampipe/py/pgsql-query-bv-zurich.py  >> /tmp/pgsql-query-bv-zurich.py.log
/usr/bin/python3 /home/steampipe/py/pgsql-query-ci-running-frankfurt.py  >> /tmp/pgsql-query-ci-running-frankfurt.py.log
/usr/bin/python3 /home/steampipe/py/pgsql-query-ci-running-zurich.py  >> /tmp/pgsql-query-ci-running-zurich.py.log