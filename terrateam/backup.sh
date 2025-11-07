#!/usr/bin/env bash

USER="postgres"
HOST="127.0.0.1"

pg_dump -c -C \
  "host=$HOST user=$USER dbname=terrateam" \
  >"$(pwd)/terrateam.$(date "+%Y%m%d-%H%M%S").dump"
