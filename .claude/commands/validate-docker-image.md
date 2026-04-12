Run `mise run dev:validate-docker-image` to check that the Dockerfile builder image tag exists on Docker Hub and supports all required architectures (linux/amd64 and linux/arm64).

Report the results. If validation fails, explain which architecture is missing and suggest checking the available tags at https://hub.docker.com/r/hexpm/elixir/tags.
