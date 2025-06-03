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

RUN mkdir -p /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
COPY config /root/.ssh/config
COPY id_rsa_mobile /root/.ssh/id_rsa_mobile

RUN chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/config && \
    chmod 600 /root/.ssh/id_rsa_mobile

RUN mkdir /var/run/sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN mkdir -p /config
COPY docker-config.conf /config/amigo.conf

EXPOSE 22

# setup script to install python packages and clone repo
COPY setup-linux.sh .
COPY requirements.txt .
RUN chmod +x setup-linux.sh
RUN ./setup-linux.sh

COPY clone_repo.sh .
RUN chmod +x clone_repo.sh

# Default command
CMD /clone_repo.sh && cd $REPO_DIR && service ssh start && service cron start && /bin/bash
 