FROM haproxy:alpine

COPY configs/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg