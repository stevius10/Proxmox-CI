FROM debian:bookworm

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV PYTHONIOENCODING=utf8
ARG DEBIAN_FRONTEND=noninteractive

ENV IP=127.0.0.1
# ENV IP=172.17.0.1

STOPSIGNAL SIGRTMIN+3
ENV container=docker

RUN apt update -y && apt install -y sudo make curl jq git systemd vim wget net-tools procps && apt clean all && \
    rm -rf /var/cache/dnf/* /tmp/* /var/tmp/*

RUN rm -rf /lib/systemd/system/multi-user.target.wants/* ; \
  rm -rf /etc/systemd/system/*.wants/* ; \
  rm -rf /lib/systemd/system/local-fs.target.wants/* ; \
  rm -rf /lib/systemd/system/sockets.target.wants/*udev* ; \
  rm -rf /lib/systemd/system/sockets.target.wants/*initctl* ; \
  rm -rf /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* ; \
  rm -rf /lib/systemd/system/systemd-update-utmp*

RUN groupadd -f root && \
    useradd -M app && \
    useradd -m -G sudo,root config && \
    useradd -m -s /bin/bash -G sudo,root user && \
    echo "config ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/config && \
    echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user

RUN url=$(curl -s https://downloads.cinc.sh/files/stable/cinc/ | grep -oP 'href="\d.*/"' | sort -V | tail -n 1 | awk -F '"' '{print  $2 }' | awk -F '/' '{print  "https://downloads.cinc.sh/files/stable/cinc/" $1 "/debian/12/cinc_" $1 "-1_arm64.deb" }') && wget -O ./cinc-client.deb "$url" && dpkg -i ./cinc-client.deb && apt-get install -f -y

WORKDIR /

VOLUME [ "/tmp", "/run" ]

ENTRYPOINT ["/usr/lib/systemd/systemd"]
CMD ["/bin/bash"]