#!/bin/bash

### Run this script using the system user assigned to run the CloudBees Analytics server
### If you are not the user assigned to run the CloudBees Analytics, you can use `sudo su` to impersonate that user.
### For example: if system user is analytics ###
#
# sudo su analytics
#
### end of example ###

### Specify custom variables as environmental variables if required for your installation
# ES_DIR_CONF - conf dir which contains installed config yml files
# ES_DIR_BINS - dir with ElasticSearch binaries
# ES_JAVA_HOME - dir with java
# ES_PORT - the transport port used for communication between nodes, specify new port if it was not configured by default as 9300
# CONFIG_DIR_TMP - temporary folder with write permissions

### example ###
## If DOIS is installed in /opt/cloudbees/dois, then run:
#  ES_DIR_CONF=/opt/cloudbees/dois/conf/reporting/elasticsearch \
#  ES_DIR_BINS=/opt/cloudbees/dois/reporting/elasticsearch/bin \
#  ES_JAVA_HOME=/opt/cloudbees/dois/reporting/jre \
#  ./update-es-role-permissions.sh"
### end of example ###

function show_help() {
    echo "update_es_role_permissions.sh [-h]"
    echo  "-h show help"
    echo ""
    echo "****************************************************************"
    echo  "Run this script using the system user assigned to run the CloudBees Analytics server"
    echo  "If you are not the user assigned to run the CloudBees Analytics, you can use \`sudo su\` to impersonate that user."
    echo "### For example: if system user is analytics ###"
    echo ""
    echo "sudo su analytics"
    echo ""
    echo "### end of example ###"
    echo ""
    echo "Specify custom variables as environmental variables if required for your installation"
    echo "ES_DIR_CONF - conf dir which contains installed config yml files"
    echo "ES_DIR_BINS - dir with ElasticSearch binaries"
    echo "ES_JAVA_HOME - dir with java"
    echo "ES_PORT -  the transport port used for communication between nodes, specify new port if it was not configured by default as 9300"
    echo "CONFIG_DIR_TMP - temporary folder with write permissions"
    echo ""
    echo "### example ###"
    echo ""
    echo "# If DOIS is installed in /opt/cloudbees/dois, then run:"
    echo "ES_DIR_CONF=/opt/cloudbees/dois/conf/reporting/elasticsearch \ "
    echo "ES_DIR_BINS=/opt/cloudbees/dois/reporting/elasticsearch/bin \ "
    echo "ES_JAVA_HOME=/opt/cloudbees/dois/reporting/jre \ "
    echo "./update-es-role-permissions.sh"
    echo ""
    echo "### end of example ###"
    echo ""
    echo "****************************************************************"
}

while getopts "h?" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    esac
done

shift $((OPTIND-1))

# Default values if DOIS installed to the /opt/cloudbees/
ES_DIR_CONF_DEF="/opt/cloudbees/sda/conf/reporting/elasticsearch"
ES_DIR_BINS_DEF="/opt/cloudbees/sda/reporting/elasticsearch/bin"
ES_JAVA_HOME_DEF="/opt/cloudbees/sda/reporting/jre"
CONFIG_DIR_TMP_DEF="/tmp"
ES_PORT_DEF=9300

# Use default values if not specified
ES_DIR_CONF="${ES_DIR_CONF:-$ES_DIR_CONF_DEF}"
ES_DIR_BINS="${ES_DIR_BINS:-$ES_DIR_BINS_DEF}"
JAVA_HOME="${JAVA_HOME:-$JAVA_HOME_DEF}"
ES_JAVA_HOME="${ES_JAVA_HOME:-$ES_JAVA_HOME_DEF}"
JAVA_HOME="${JAVA_HOME:-$ES_JAVA_HOME}"
ES_PORT="${ES_PORT:-$ES_PORT_DEF}"
CONFIG_DIR_TMP="${CONFIG_DIR_TMP:-$CONFIG_DIR_TMP_DEF}"

echo "ES_DIR_CONF=$ES_DIR_CONF"
echo "ES_DIR_BINS=$ES_DIR_BINS"
echo "ES_JAVA_HOME=$ES_JAVA_HOME"
echo "ES_PORT=$ES_PORT"

SG_ROLES=$(cat <<EOF
---
# DLS (Document level security) is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/document-level-security

# FLS (Field level security) is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/field-level-security

# Masked fields (field anonymization) is NOT FREE FOR COMMERCIAL use, you need to obtain an compliance license
# https://docs.search-guard.com/latest/field-anonymization

# Kibana multitenancy is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/kibana-multi-tenancy


_sg_meta:
  type: "roles"
  config_version: 2

# Define your own search guard roles here
# or use the built-in search guard roles
# See https://docs.search-guard.com/latest/roles-permissions

CB_REPORT_USER:
  cluster_permissions:
    - "SGS_CLUSTER_MANAGE_INDEX_TEMPLATES"
    - "SGS_CLUSTER_MONITOR"
    - "SGS_CLUSTER_COMPOSITE_OPS"
    - "SGS_MANAGE_SNAPSHOTS"
  index_permissions:
    - index_patterns:
        - "*"
      allowed_actions:
        - "SGS_SEARCH"
    - index_patterns:
        - "ef-*"
      allowed_actions:
        - "indices:admin/refresh*"
        - "SGS_CRUD"
        - "SGS_CREATE_INDEX"

CB_READALL_USER:
  cluster_permissions:
    - "SGS_CLUSTER_MONITOR"
  index_permissions:
    - index_patterns:
        - "*"
      allowed_actions:
        - "indices:admin/mappings/get"
        - "SGS_SEARCH"
        - "SGS_READ"
        - "SGS_INDICES_MONITOR"
EOF
)

SG_ROLES_MAPPING=$(cat <<EOF
---
# In this file users, backendroles and hosts can be mapped to Search Guard roles.
# Permissions for Search Guard roles are configured in sg_roles.yml

_sg_meta:
  type: "rolesmapping"
  config_version: 2

# Define your roles mapping here
# See https://docs.search-guard.com/latest/mapping-users-roles

CB_REPORT_USER:
  reserved: false
  users:
    - "reportuser"

CB_READALL_USER:
  reserved: false
  users:
    - "kibanauser"

SGS_KIBANA_USER:
  reserved: false
  users:
    - "kibanauser"

SGS_KIBANA_SERVER:
  reserved: true
  users:
    - "kibanaserver"

SGS_ALL_ACCESS:
  reserved: true
  users:
    - "admin"
EOF
)

if [ ! -d "$ES_DIR_BINS" ]; then
    echo "Unable to determine Elasticsearch binary directory. Quit."
    exit 1
fi

if [ ! -d "$ES_JAVA_HOME" ]; then
    echo "Unable to determine Java Home directory. Quit."
    exit 1
fi

if [ ! -d "$ES_DIR_CONF" ]; then
    echo "Unable to determine config directory $ES_DIR_CONF. Quit."
    exit 1
fi

echo "Elasticsearch config dir: $ES_DIR_CONF"
echo "Java home:" $ES_JAVA_HOME
echo "Elasticsearch bin dir: $ES_DIR_BINS"

# Prepare temporary config folder
if [ ! -w "$CONFIG_DIR_TMP" ]; then
    if [ -w "$/var/tmp" ]; then
        CONFIG_DIR_TMP=/var/tmp
    else
        echo "Please provide writable directory via CONFIG_DIR_TMP, it can be /tmp or /var/tmp or custom... Quit."
        exit 1
    fi
fi

CONFIG_TMP="$CONFIG_DIR_TMP/elastic_tmp_config-$$"
echo "Creating temporary config directory $CONFIG_TMP"
mkdir -p $CONFIG_TMP

# Copy yml files to the temporary folder
cp -r $ES_DIR_CONF/*.yml $CONFIG_TMP/

# Prepare sg_roles_mapping.yml and sg_roles.yml
echo "Updating $CONFIG_TMP/sg_roles_mapping.yml"
echo "$SG_ROLES_MAPPING" > $CONFIG_TMP/sg_roles_mapping.yml

echo "Updating $CONFIG_TMP/sg_roles.yml"
echo "$SG_ROLES" > $CONFIG_TMP/sg_roles.yml

# Apply new roles
"$ES_JAVA_HOME/bin/java" \
    -Dio.netty.tryReflectionSetAccessible=false -Dio.netty.noUnsafe=true \
    -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=OFF \
    -cp "$ES_DIR_BINS/../plugins/search-guard-7/*:$ES_DIR_BINS/../lib/*" \
    com.floragunn.searchguard.tools.SearchGuardAdmin \
    -cd "$CONFIG_TMP" \
    -ks "$ES_DIR_CONF/admin-keystore.jks" -kspass "abcdef" \
    -ts "$ES_DIR_CONF/truststore.jks" -tspass "abcdef" \
    -h localhost -p $ES_PORT -nhnv -icl "$@"

echo "Clean temporary config folder"
# Comment out next block if you what to keep yml files in temp directory
rm -rf $CONFIG_TMP
