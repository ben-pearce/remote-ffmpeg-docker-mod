## remote-ffmpeg-docker-mod

A docker image 'mod' for [LinuxServer.io](https://fleet.linuxserver.io/) docker images which allows any call to the containers' `ffmpeg` installation to be commandeered and ran in a remote execution environment with very little effort. Once the mod is enabled on the container, the remote machine need only be running a supported Linux distribution with `sshfs` installed, and an SSH key for authentication.

The intended use case is to allow the container to take advantage of extra compute resources of a remote machine (such as discrete graphics), or within a Virtual Machine on the same host, but without the need to resort to complicated setups like GPU passthrough in order to take advantage of hardware transcoding.

## Setup

Simply add the required entry to the containers `DOCKER_MODS` environment variable, and then the additional variables for SSH authentication:

```yaml
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - JELLYFIN_PublishedServerUrl=http://192.168.0.5 #optional
      - DOCKER_MODS=ghcr.io/ben-pearce/remote-ffmpeg-docker-mod:jellyfin
      - REMOTE_FFMPEG_USER=root
      - REMOTE_FFMPEG_HOST=renderer.host
      - REMOTE_FFMPEG_FORWARD_HOSTS=8080:some-other-container:8080
    volumes:
      - /path/to/jellyfin/library:/config
      - /path/to/tvseries:/data/tvshows
      - /path/to/movies:/data/movies
    ports:
      - 8096:8096
      - 8920:8920 #optional
      - 7359:7359/udp #optional
      - 1900:1900/udp #optional
    restart: unless-stopped
```

[Generate an SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key), and place the private key within the `/config/.ssh` directory of your container.

## Environment variables

- `REMOTE_FFMPEG_USER` - The SSH user to login to the remote host as, must have sufficient privileges to run `chroot`. (default: `root`)
- `REMOTE_FFMPEG_HOST` - The hostname or IP address of the remote host where execution takes place. (default: `''`)
- `REMOTE_FFMPEG_FORWARD_HOSTS` - Comma seperated list of port forwards to enable (TCP only). Allows traffic to flow from the remote exeuction environment to the container. (Syntax: `local_port:remote_address:remote_port`). (default: `''`)
- `REMOTE_FFMPEG_SSH_KEY_PATH` - Override the SSH key path. (default: `/config/.ssh/id_*`)
- `REMOTE_FFMPEG_BINARY` - Override the container ffmpeg path. (default: `$(which ffmpeg)`) 

## Supported tags

In theory, all LinuxServer.io images are supported, the mod will search for the `ffmpeg` binary using `which`. For some images / applications, this is not sufficient, so additional flavors of the mod are provided to assist with setup.

- `:latest` - Version for use with all LinuxServer.io containers.
- `:jellyfin` - Version for use specifically with [Jellyfin](https://docs.linuxserver.io/images/docker-jellyfin/) media server.

## Planned functionality
- Local FFMPEG failover
- Round robin load balancing with multiple remote hosts
- Automatic retrying when remote is unavailable with configurable timeouts.
- Manipulation of ffmpeg flags on a per-host basis, using regex replacements.
