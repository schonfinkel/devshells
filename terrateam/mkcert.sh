#!/usr/bin/env bash

# Create a Certificate Signing Request (CN=localhost)
umask u=rw,go= && \
    openssl \
        req -days 3650 \
        -new -text -nodes \
        -subj '/C=US/ST=Massachusetts/L=Bedford/O=Personal/OU=Personal/emailAddress=example@example.com/CN=localhost' \
        -keyout server.key \
        -out server.csr

# Generate self-signed certificate
umask u=rw,go= \
    && openssl \
        req -days 3650 \
        -x509 -text -in server.csr -key server.key -out server.crt

# Also make the server certificate to be the root-CA certificate
umask u=rw,go= && cp server.crt root.crt
