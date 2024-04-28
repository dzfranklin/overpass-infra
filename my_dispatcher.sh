#!/usr/bin/env bash
/overpass/bin/dispatcher --osm-base --db-dir="/overpass_data/db/" \
  --allow-duplicate-queries=yes \
  --rate-limit=0
