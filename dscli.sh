#!/bin/sh

CONF_FILE=/srv/dietstack/settings.sh

if [ -f $CONF_FILE ]; then
    echo "Loading settings file $CONF_FILE"
    . $CONF_FILE
else
    echo "ERROR: settings file $CONF_FILE not found!"
    exit 1
fi

if [ -z $EXTERNAL_IP ]; then
    echo "ERROR: EXTERNAL_IP variable must be set!"
    exit 2
fi

JUST_EXTERNAL_IP=$(echo $EXTERNAL_IP | cut -d"/" -f 1)

docker run --rm --net=host \
           -v ~/.ssh:/root/.ssh \
            -v /srv/dietstack/glance-images-osadmin:/app/glance-images \
           -e JUST_EXTERNAL_IP=$JUST_EXTERNAL_IP \
           -it dietstack/osadmin /bin/bash

