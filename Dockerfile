FROM golang:1.10.0-alpine3.7

RUN apk update && apk add --no-cache bash curl g++ gcc git make openrc supervisor unzip zip

RUN mkdir -p /run/openrc && \
    touch /run/openrc/softlevel

RUN mkdir -p $GOPATH/src/github.com/hashicorp && \
    cd $! && \
    git clone https://github.com/hashicorp/consul.git $GOPATH/src/github.com/hashicorp/consul && \
    cd $GOPATH/src/github.com/hashicorp/consul && \
    go install && \
    make

COPY consul.json $GOPATH/src/github.com/hashicorp/consul
COPY consul.service /etc/init.d/consul

RUN chmod +x /etc/init.d/consul

ENV VAULT_ADDR http://127.0.0.1:8200
RUN git clone https://github.com/hashicorp/vault.git $GOPATH/src/github.com/hashicorp/vault
RUN cd $GOPATH/src/github.com/hashicorp/vault && \
    go install && \
    make bootstrap V=1

COPY vault.json $GOPATH/src/github.com/hashicorp/vault
COPY vault.service /etc/init.d/vault

RUN sed -i "s~CONSUL_ENCRYPT~$(consul keygen)~g" $GOPATH/src/github.com/hashicorp/consul/consul.json

RUN chmod +x /etc/init.d/vault

RUN rc-status && \
    /etc/init.d/consul start && \
    /etc/init.d/vault start && \
    vault operator init -key-shares=1 -key-threshold=1

RUN vault operator unseal # Deve utilizar o Unseal key gerado no output do comando vault operator init
RUN vault login # Deve utilizar o token gerado no output do comando vault operator init

EXPOSE 8200
EXPOSE 8500

CMD supervisord