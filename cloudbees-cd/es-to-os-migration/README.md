# Estimate data size of legacy CloudBees Analytics indexes

In CloudBees CD/RO v2024.06.0, the CloudBees Analytics server was upgraded from Elasticsearch to OpenSearch. As part of the upgrade process from v2024.03.0 or earlier to v2024.06.0 or later, you must migrate your CloudBees Analytics to OpenSearch, as described in:

* [Traditional migrations](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/trad-upgrade-to-os)
* [Kubernetes migrations](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/k8s-upgrade-to-os)

CloudBees has provided the [reporting-data-reindex.pl](reporting-data-reindex.pl) utility to help you roughly estimate the size of legacy CloudBees Analytics indexes data that will be migrated to your updated CloudBees Analytics server.

> [!IMPORTANT]
> As described in the [known issues of the data migration](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/data-migration-es-to-os#data-migration-known-issues), the migration options provided by CloudBees have a timeout of `180 minutes` per index to avoid unexpected hangs.
> In cases where an index contains a considerably large amount of data, and its migration does not complete within the timeout duration, the migration process fails.
>
> This may result in having to split such indexes into multiple smaller indexes. If you encounter multiple timeout issues, contact CloudBees support.

## Dependencies
This utility requires `cb-perl` to run, and is executable in any environment with a v10.3 or later CloudBees CD/RO server or agent installation.

## Command Format

The format for launching the utility is as follows:

```sh
$ <cdro-install-dir>/bin/cb-perl ./reporting-data-reindex.pl --showStatistics=1 --sourceUrl=https://<hostname>:9200 --sourceAuthUser=reportuser --sourceAuthPassword=<password>
```

Where:
* `<cdro-install-dir>`: Directory where the CloudBees CD/RO server or agent is installed.
* `--showStatistics=1`: *_Required_*. Specifies to display the index statistics.

* `--sourceUrl=https://<hostname>:9200`: Specifies the legacy CloudBees Analytics server URL.

* `--sourceAuthUser=reportuser`: Specifies the username to authenticate to the legacy CloudBees Analytics server. By default, it is `reportuser`.

* `--sourceAuthPassword=<password>`: Specifies the password for the username to authenticate to the legacy CloudBees Analytics server.

### Output Tables

After checking the indexes, the following tables will be shown:

- **Node Disk Usage:** This table shows the disk space occupied on each node:
```
| Node Name        |  Indexes Size  |
|------------------|----------------|
| <NODE-NAME>      | <INDEXES-SIZE> |
```

- **Index Document Count:** This table shows the number of documents in each index and the total number of documents across all indexes:
```
| Index Name       | Count           |
|------------------|-----------------|
| <INDEX-NAME>     |  <INDEX-COUNT>  |
| **Total**        |  <TOTAL-COUNT>  |
```

## Example

The following example demonstrates running the `reporting-data-reindex.pl` script and the expected outputs:

### Command example

```sh
$ /opt/cloudbees/sda/bin/cb-perl ./reporting-data-reindex.pl --showStatistics=1 --sourceUrl=https://prod-server.com:9200 --sourceAuthUser=reportuser --sourceAuthPassword=changeme
```

### Output example
```
Reporting data reindex tool for CloudBees Software Delivery Automation Analytics Server version 2024.06.0
Copyright (C) 2009-2024 CloudBees, Inc.
All rights reserved.

2024-06-07 09:43:48.223255 [INFO ] Index statistics from the next server will be shown::
2024-06-07 09:43:48.223364 [INFO ]   * URL: https://prod-server.com:9200
2024-06-07 09:43:48.223415 [INFO ]   * Server type: Elasticsearch version 7.17.18
2024-06-07 09:43:48.223460 [INFO ] Checking disk usage on the source server...
2024-06-07 09:43:48.287737 [INFO ] Checking available indices from the source server...
2024-06-07 09:43:48.342485 [INFO ] [  1/ 18] Checking the index 'ef-build-2021' ...
2024-06-07 09:43:48.786829 [INFO ] [  2/ 18] Checking the index 'ef-build-2022' ...
...
2024-06-07 09:43:50.542369 [INFO ] [ 18/ 18] Checking the index 'ef-pipelinerun-2023' ...
2024-06-07 09:43:50.647893 [INFO ] The source server contains 18 indices with 80,000 documents.

Node Name            | Indices Size
---------------------| ------------
prod-server.internal | 62.4mb

Index Name          | Count
------------------- | -----
ef-build-2021       | 10
ef-defect-2021      | 5
ef-deployment-2020  | 9
...
ef-pipelinerun-2023 | 16097
------------------- | -----
Total               | 80000

```
