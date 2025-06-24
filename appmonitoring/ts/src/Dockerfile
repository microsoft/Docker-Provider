# Golden Mariner container for NodeJs
# https://eng.ms/docs/products/mariner-linux/overview/mariner20
# https://eng.ms/docs/products/mariner-linux/gettingstarted/containers/marinercontainerimage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:18

ARG IMAGE_TAG
ENV IMAGE_TAG=$IMAGE_TAG

ARG TARGETARCH
ENV ARCH=$TARGETARCH

ARG WEBHOOK_PORT=1337
ENV WEBHOOK_PORT=$WEBHOOK_PORT

ARG PROM_PORT=4000
ENV PROM_PORT=$PROM_PORT

RUN tdnf upgrade -y && tdnf clean all

# Smoke test ensuring that NodeJS was installed.
RUN node --version && npm --version

WORKDIR /mutating-webhook

COPY ./out/* /mutating-webhook
COPY ./package.json /mutating-webhook
COPY ./node_modules /mutating-webhook/node_modules

EXPOSE $WEBHOOK_PORT
EXPOSE $PROM_PORT
CMD [ "node", "server.js" ]