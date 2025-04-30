#!/usr/bin/env bash

# Create a Certificate Signing Request (CN=127.0.0.1)
umask u=rw,go= && \
    openssl \
        req -days 3650 \
        -new -text -nodes \
        -subj '/C=US/ST=Massachusetts/L=Bedford/O=Personal/OU=Personal/emailAddress=example@example.com/CN=127.0.0.1' \
        -keyout server.key -out server.csr
# Generate self-signed certificate
umask u=rw,go= && \
    openssl \
        req -days 3650 \
        -x509 -text \
        -in server.csr \
        -key server.key \
        -out server.crt

# Also make the server certificate to be the root-CA certificate
umask u=rw,go= && cp server.crt root.crt

# Remove the now-redundant CSR
rm server.csr

# Generate client certificates to be used by clients/connections
# Create a Certificate Signing Request (CN=terrateam)
umask u=rw,go= && \
    openssl \
        req -days 3650 \
        -new -nodes \
        -subj '/C=US/ST=Massachusetts/L=Bedford/O=Personal/OU=Personal/emailAddress=example@example.com/CN=terrateam' \
        -keyout client.key \
        -out client.csr

# Create a signed certificate for the client using our root certificate
umask u=rw,go= && \
    openssl \
        x509 -days 3650 \
        -req -CAcreateserial \
        -in client.csr \
        -CA root.crt \
        -CAkey server.key \
        -out client.crt

# Remove the now-redundant CSR
rm client.csr
