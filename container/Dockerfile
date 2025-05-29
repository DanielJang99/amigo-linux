FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV REPO_URL=https://github.com/DanielJang99/amigo-linux.git
ENV REPO_DIR=/amigo-linux

RUN apt-get update && \
apt-get install -y --no-install-recommends \
openssh-client \
openssh-server \
git \
sudo \
iproute2 \
vim \
mtr-tiny \
python3 \
python3-pip \
tcpdump \
nodejs \
curl \
wireless-tools \
cron \
iputils-ping \
tshark && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*

# Cron
COPY cronjobs /etc/cron.d/cronjobs
RUN chmod 0644 /etc/cron.d/cronjobs
RUN crontab /etc/cron.d/cronjobs

# setup script to install python packages and clone repo
COPY setup-linux.sh .
RUN chmod +x setup-linux.sh
RUN ./setup-linux.sh

# Set working directory to the repo
WORKDIR $REPO_DIR

# Default command
CMD service cron start && /bin/bash
