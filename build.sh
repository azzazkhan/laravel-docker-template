clear
docker container prune --force
docker image rm --force app:latest
DOCKER_BUILDKIT=0 docker build --tag app:latest --file Dockerfile --rm .
