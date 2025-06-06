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

docker pull hsj276/amigo-linux-image:latest

docker run -d -e HOST_MACHINE_ID=$MACHINE_ID --platform linux/amd64 --network host --cap-add CAP_NET_ADMIN hsj276/amigo-linux-image:latest