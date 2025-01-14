#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

# Since trino-connector needs to connect Gravitino service, get the default metalake
# Create metalake
response=$(curl -X POST -H "Content-Type: application/json" -d '{"name":"metalake_demo","comment":"comment","properties":{}}' http://gravitino:8090/api/metalakes)
if echo "$response" | grep -q "\"code\":0"; then
  true # Placeholder, do nothing
else
  echo "Metalake metalake_demo create failed"
  exit 1
fi

# Check metalake if created
response=$(curl -X GET -H "Content-Type: application/json" http://gravitino:8090/api/metalakes)
if echo "$response" | grep -q "metalake_demo"; then
  echo "Metalake metalake_demo successfully created"
else
  echo "Metalake metalake_demo create failed"
  exit 1
fi

# Create Hive catalog for experience Gravitino service
curl -X POST -H "Content-Type: application/json" -d '{"name":"catalog_hive","type":"RELATIONAL", "provider":"hive", "comment":"comment","properties":{"metastore.uris":"thrift://hive:9083"}}' http://gravitino:8090/api/metalakes/metalake_demo/catalogs


# Check catalog if created
response=$(curl -X GET -H "Content-Type: application/json" http://gravitino:8090/api/metalakes/metalake_demo/catalogs)
if echo "$response" | grep -q "catalog_hive"; then
  echo "Catalog catalog_hive successfully created"
else
  echo "Catalog catalog_hive create failed"
  exit 1
fi

# Create Postgresql catalog for experience Gravitino service
curl -X POST -H "Accept: application/vnd.gravitino.v1+json" -H "Content-Type: application/json" -d '{
    "name":"catalog_postgres",
    "type":"RELATIONAL",
    "provider":"jdbc-postgresql",
    "comment":"comment",
    "properties":{
        "jdbc-url":"jdbc:postgresql://postgresql/db",
        "jdbc-user":"postgres",
        "jdbc-password":"postgres",
        "jdbc-database":"db",
        "jdbc-driver": "org.postgresql.Driver"
    }
}' http://gravitino:8090/api/metalakes/metalake_demo/catalogs

response=$(curl -X GET -H "Content-Type: application/json" http://gravitino:8090/api/metalakes/metalake_demo/catalogs)
if echo "$response" | grep -q "catalog_postgres"; then
  echo "Catalog catalog_postgres successfully created"
else
  echo "Catalog catalog_postgres create failed"
  exit 1
fi

# Create Iceberg catalog for experience Gravitino service
curl -X POST -H "Accept: application/vnd.gravitino.v1+json" -H "Content-Type: application/json" -d '{
    "name":"catalog_iceberg",
    "type":"RELATIONAL",
    "provider":"lakehouse-iceberg",
    "comment":"comment",
    "properties":{
        "uri":"jdbc:mysql://mysql:3306/db",
        "catalog-backend":"jdbc",
        "warehouse":"hdfs://hive:9000/user/iceberg/warehouse/",
        "jdbc-user":"mysql",
        "jdbc-password":"mysql",
        "jdbc-driver":"com.mysql.cj.jdbc.Driver"
    }
}' http://gravitino:8090/api/metalakes/metalake_demo/catalogs

response=$(curl -X GET -H "Content-Type: application/json" http://gravitino:8090/api/metalakes/metalake_demo/catalogs)
if echo "$response" | grep -q "catalog_iceberg"; then
  echo "Catalog catalog_iceberg successfully created"
else
  echo "Catalog catalog_iceberg create failed"
  exit 1
fi

/etc/trino/update-trino-conf.sh
nohup /usr/lib/trino/bin/run-trino &

counter=0
while [ $counter -le 240 ]; do
  counter=$((counter + 1))
  trino_ready=$(trino --execute  "SHOW CATALOGS LIKE 'catalog_hive'"| grep "catalog_hive" | wc -l)
  if [ "$trino_ready" -eq 0 ];
  then
    echo "Wait for the initialization of services"
    sleep 5;
  else
    echo "Import the data of the Hive warehouse"
    trino < /tmp/trino/init.sql
    echo "Import ends"

    # persist the container
    tail -f /dev/null
  fi
done
exit 1
