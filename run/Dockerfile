FROM rockylinux:9

ARG TARGETARCH=aarch64
ENV IP=127.0.0.1 \
 ANSIBLE_ROLES_PATH=/tmp/base \
 LC_ALL=C.UTF-8

STOPSIGNAL SIGRTMIN+3

RUN dnf -y update && \
 dnf -y install epel-release && \
 dnf -y install systemd python3 python3-pip ansible wget && \
 dnf clean all

RUN pip3 install proxmoxer
RUN pip3 install requests

RUN rm -rf /etc/systemd/system/multi-user.target.wants/* && \
 rm -rf /etc/systemd/system/*.wants/* && \
 rm -rf /lib/systemd/system/local-fs.target.wants/* && \
 rm -rf /lib/systemd/system/sockets.target.wants/*udev* && \
 rm -rf /lib/systemd/system/sockets.target.wants/*initctl* && \
 rm -rf /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* && \
 rm -rf /lib/systemd/system/systemd-update-utmp*

COPY ../base/roles /tmp/base

RUN ansible-galaxy collection install -p /usr/share/ansible/collections community.proxmox

RUN ssh-keygen -t ed25519 -f /tmp/id_ed25519 -N ''

RUN ansible localhost -m include_role -a name=base \
-e "ip=${IP}" -e "arch=${TARGETARCH}" -e "configure_ssh=false" \
-e "private_key=$(cat /tmp/id_ed25519)" -e "public_key=$(cat /tmp/id_ed25519.pub)"

WORKDIR /

VOLUME ["/tmp", "/run"]

ENTRYPOINT ["/usr/lib/systemd/systemd"]
CMD ["/bin/bash"]