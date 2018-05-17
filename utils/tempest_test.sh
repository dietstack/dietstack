#!/bin/bash
# Runs tempest tests against installed dietstack cloud
# It has to be run from control node.


IMAGE_REF=$(. versions/2; docker run --net=host --rm ${OSADMIN_VER} \
            bash -c ". /app/adminrc; openstack image list --name cirros -f value -c ID" | grep -v OSadmin)
PUBLIC_NETWORK_ID=$(. versions/2; docker run --net=host --rm ${OSADMIN_VER} \
                    bash -c ". /app/adminrc; openstack network list --name external -f value -c ID" | grep -v OSadmin)

docker run --net=host --rm -it -v /srv/dietstack/settings.sh:/app/settings.sh \
           -e IMAGE_REF=$IMAGE_REF -e PUBLIC_NETWORK_ID=$PUBLIC_NETWORK_ID dietstack/tempest:dev-pike \
           bash -c "cd /app/dietstack; tempest run"

