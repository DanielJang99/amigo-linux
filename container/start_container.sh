#!/bin/bash

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed on this system"
    exit 1
fi

if ! sudo docker info &> /dev/null; then
    echo "Error: Docker service is not running. Please start Docker service first."
    exit 1
fi

echo "Checking Docker registry access..."
if ! sudo docker pull hsj276/amigo-linux-image:latest &> /dev/null; then
    echo "Warning: Cannot pull from Docker registry. Please check your internet connection and Docker login status."
    echo "If you need to login to Docker Hub, run: docker login"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Error: Please provide a unique MACHINE_ID as argument"
    echo "Usage: $0 <MACHINE_ID>"
    exit 1
fi

MACHINE_ID=$1

echo "Starting container..."

if [ -z "$MACHINE_ID" ]; then
    echo "Error: MACHINE_ID is not set"
    exit 1
fi

sudo docker run -d -e HOST_MACHINE_ID=$MACHINE_ID --platform linux/amd64 --network host --cap-add CAP_NET_ADMIN hsj276/amigo-linux-image:latest