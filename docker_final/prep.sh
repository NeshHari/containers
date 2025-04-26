echo "Saving Docker images..."
docker save -o config-server-image.tar config-server-image:latest
docker save -o dev-container-image.tar dev-container-image:latest
echo "Images saved as .tar files."
