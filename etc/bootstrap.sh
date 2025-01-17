#!/bin/bash

docker service create                                         \
  --name emqx                                                 \
  --network nano                                              \
  -p 1883:1883                                                \
  -p 18083:18083                                              \
  -p 20041:20041                                              \
  -e EMQX_API_KEY__BOOTSTRAP_FILE=/opt/emqx/data/secret.conf  \
  --secret source=emqx-rest,target=/opt/emqx/data/secret.conf \
  ghcr.io/blabtm/emqx:5.8.3

