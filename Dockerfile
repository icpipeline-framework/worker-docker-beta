FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

ARG ICPW_USER_PW

# RUN apt-get update && apt install openssh-server sudo -y git curl rsync net-tools vim lsof psmisc zip build-essential cmake libjson-c-dev libwebsockets-dev
RUN apt update && apt install openssh-server sudo -y git curl rsync net-tools vim lsof psmisc zip build-essential cmake libjson-c-dev libwebsockets-dev
# relocated ssh-server into setup.sh, so each Worker will generate its own host key pair.
# RUN apt update && apt install sudo -y git curl rsync net-tools vim lsof psmisc zip

RUN groupadd icpipeline

RUN useradd -rm -d /home/icpipeline -s /bin/bash -g icpipeline -G sudo -u 1000 icpipeline

RUN echo "icpipeline:${ICPW_USER_PW}" | chpasswd

WORKDIR /home/icpipeline

COPY . .

RUN chmod +x ./setup.sh

CMD ["/bin/sh", "setup.sh"]
