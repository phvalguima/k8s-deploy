#!/bin/bash

lds_server=$(juju status | grep "landscape-haproxy/0" | awk '{print $5}')

echo "Landscape Server public IP is: ${lds_server}"

cert=$(juju run --unit landscape-haproxy/0 'cat /var/lib/haproxy/selfsigned_ca.crt')

echo "Landscape Server CRT: ${cert}"
echo "${cert}" > /tmp/cert_inter.out
echo "Landscape Server CRT base64:$(base64 /tmp/cert_inter.out)"

juju config landscape-client ssl-public-key="base64:$(base64 /tmp/cert_inter.out)"
juju config landscape-client ping-url=http://${lds_server}/ping
juju config landscape-client url=https://${lds_server}/message-system
