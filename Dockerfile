## Buildstage ##
FROM ghcr.io/linuxserver/baseimage-alpine:3.19 as buildstage

# copy local files
COPY root/ /root-layer/

# ## Single layer deployed image ##
FROM scratch

# # Add files from buildstage
COPY --from=buildstage /root-layer/ /