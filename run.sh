#!/usr/bin/env bash

# TODO: Enable area generation once caught up

# TODO: Consider <https://github.com/drolbr/Overpass-API/issues/387>

# TODO: Clean log files <https://github.com/drolbr/Overpass-API/issues/679>

REPLICATION_URL="https://planet.openstreetmap.org/replication/minute/"
METRICS_URL="https://influx-prod-24-prod-eu-west-2.grafana.net/api/v1/push/influx/write"

/overpass/bin/dispatcher --osm-base --db-dir="/data/db/" \
  --allow-duplicate-queries=yes \
  --rate-limit=0 &
dispatcher_pid=$!
echo "started dispatcher (pid=$dispatcher_pid)"

#cp -pR /overpass/rules /data/db/
#/overpass/bin/dispatcher --areas --db-dir="/data/db/" &
#areas_dispatcher_pid=$!

#/overpass/bin/rules_loop.sh "/data/db/" &
#areas_rules_loop_pid=$!

/overpass/bin/fetch_osc_and_apply.sh "$REPLICATION_URL" &
fetch_pid=$!
echo "started fetch_osc_and_apply.sh (pid=$fetch_pid)"

/usr/local/apache2/bin/httpd
echo "started apache"

function _term() {
  echo "Terminating"

  echo "stopping apache"
  /usr/local/apache2/bin/apachectl -k stop

  echo "stopping fetch_osc_and_apply.sh"
  kill -SIGTERM $fetch_pid
  wait $fetch_pid

#    kill -SIGTERM $areas_rules_loop_pid
#    wait $areas_rules_loop_pid
#
#    kill -SIGTERM $areas_dispatcher_pid
#    wait $areas_dispatcher_pid

  echo "stopping dispatcher"
  /overpass/bin/dispatcher --terminate
  wait $dispatcher_pid
}
trap _term EXIT

while true; do
  sleep 1

  latestSequenceNumber=$(curl -sL "$REPLICATION_URL/state.txt" | grep sequenceNumber | cut -d'=' -f2)
  if [ -z "$latestSequenceNumber" ]; then
    echo "Failed to get latest sequence number"
    continue
  fi
  sequenceNumber=$(cat /data/db/replicate_id)

  curl -s -X POST -H "Authorization: Bearer $METRICS_API_KEY" -H  "Content-Type: text/plain; version=0.0.4" "$METRICS_URL" \
     -d "overpass sequence_number=$sequenceNumber
         overpass latest_sequence_number=$latestSequenceNumber
         overpass replication_lag=$((latestSequenceNumber - sequenceNumber))";
done
