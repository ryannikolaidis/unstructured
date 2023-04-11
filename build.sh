TAG="${1:-amd}"
echo "tag: $TAG"
DOCKER_BUILD_REPOSITORY=quay.io/unstructured-io/build-unstructured
PIP_VERSION="22.2.1"
DOCKER_BUILDKIT=1 docker buildx build --platform=linux/amd64 --load \
    --build-arg PIP_VERSION=$PIP_VERSION \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --progress plain \
    --cache-from $DOCKER_BUILD_REPOSITORY:amd \
    -t $DOCKER_BUILD_REPOSITORY:$TAG .


