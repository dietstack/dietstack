#!/bin/sh

docker run --rm --net=host \
           -v ~/.ssh:/root/.ssh -v /srv/dietstack/glance-images-osadmin:/app/glance-images \
           -it osadmin /bin/bash
