#!/bin/sh

CONF_FILE=/srv/dietstack/settings.sh

docker run --rm --net=host \
           -v ~/.ssh:/root/.ssh \
           -v /srv/dietstack/glance-images-osadmin:/app/glance-images \
           -v $CONF_FILE:/app/settings.sh \
           -it dietstack/osadmin /bin/bash

