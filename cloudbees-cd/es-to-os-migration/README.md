# Estimate data size of legacy CloudBees Analytics indexes

In CloudBees CD/RO v2024.06.0, the CloudBees Analytics server was upgraded from Elasticsearch to OpenSearch. As part of the upgrade process from v2024.03.0 or earlier to v2024.06.0 or later, you must migrate your CloudBees Analytics to OpenSearch, as described on:

* [Traditional migrations](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/trad-upgrade-to-os)
* [Kubernetes migrations](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/k8s-upgrade-to-os)

To help roughly estimate the size of legacy CloudBees Analytics indexes data that will be migrated to your updated CloudBees Analytics server,  CloudBees has provided the [reporting-data-reindex.pl](reporting-data-reindex.pl) utility.

> **IMPORTANT**  
> As described in the [known issues of the data migration](https://docs.cloudbees.com/docs/cloudbees-cd/latest/troubleshooting/data-migration-es-to-os#data-migration-known-issues), the automated processes CloudBees has supplied to automate data migration have a timeout of `180 minutes` per index. This is roughly equivalent to `32,000,000` documents, which may vary based on the complexity of individual documents (number of fields, etc.).   
> 
> If your indexes contain vastly more than 32,000,000 documents, or you reach the timeout limit for specific indexes, it may be necessary to split the specific index into a set of smaller indexes. For more information on this process, refer to the [Elasticsearch Split index API](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/indices-split-index.html) documentation.



## Dependencies
This utility requires `cb-perl` to run, and is executable in any environment with a CloudBees CD/RO server or agent installation.

## Command Format

The format for launching the utility is as follows:

```sh
$ /opt/cloudbees/sda/bin/cb-perl ./reporting-data-reindex.pl --showStatistics=1 --sourceUrl=https://<hostname>:9200 --sourceAuthUser=reportuser --sourceAuthPassword=<password>
```

Where:

* `--showStatistics=1`: The required parameter, which selects the mode of displaying index statistics.

* `--sourceUrl=https://<hostname>:9200`: Specifies URL for the legacy CloudBees Analytics server.

* `--sourceAuthUser=reportuser`: Specifies the username to authenticate to the legacy CloudBees Analytics server. But default, it is `reportuser`.

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