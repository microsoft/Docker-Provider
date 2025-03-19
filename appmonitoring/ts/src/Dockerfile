# Golden Mariner container for NodeJs
# https://eng.ms/docs/products/mariner-linux/overview/mariner20
# https://eng.ms/docs/products/mariner-linux/gettingstarted/containers/marinercontainerimage
FROM mcr.microsoft.com/cbl-mariner/base/nodejs:18

ARG IMAGE_TAG
ENV IMAGE_TAG=$IMAGE_TAG

RUN tdnf upgrade -y && tdnf clean all

# Smoke test ensuring that NodeJS was installed.
RUN node --version && npm --version

WORKDIR /mutating-webhook

COPY ./out/* /mutating-webhook
COPY ./package.json /mutating-webhook
COPY ./node_modules /mutating-webhook/node_modules

EXPOSE 1337
CMD [ "node", "server.js" ]