FROM redhat/ubi9-minimal AS ubi9

LABEL name="neon" \
      description="neon" \
      vendor="neon" \
      summary="neon" \
      org.opencontainers.image.authors="info@percona.com"

ENV PGV 14

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
        && percona-release setup pdps-8.0

RUN set -ex; \
        curl -Lf -o /tmp/pgdg-redhat-repo-latest.noarch.rpm https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
        ls -la /tmp; \
        rpm -i /tmp/pgdg-redhat-repo-latest.noarch.rpm; \
        microdnf install -y postgresql${PGV}-server

RUN set -ex; \
    microdnf install -y \
        which \
        vim-minimal \
        procps-ng \
        nodejs \
        python3 \
        perl \
	nc \
	jq

RUN set -ex; \
    curl -Lf -o /tmp/neondatabase-neon-pg${PGV}-1.0.0-1.el9.x86_64.rpm https://jenkins.percona.com/downloads/neon/neondatabase-neon-pg${PGV}-1.0.0-1.el9.x86_64.rpm; \
    rpm -i /tmp/neondatabase-neon-pg${PGV}-1.0.0-1.el9.x86_64.rpm; \
    rm -rf /tmp/*.rpm; \
    microdnf clean all; \
    rm -rf /var/cache

STOPSIGNAL SIGUSR1

COPY dockerdir /

VOLUME ["/opt/neondatabase-neon/"]
USER root
RUN mkdir -p /data \
 && chown -R neonuser /data

VOLUME ["/data"]
USER neonuser
EXPOSE 6400
EXPOSE 9898
EXPOSE 55432

ENV PATH="$PATH:/opt/neondatabase-neon/target/release/"

CMD ["/entrypoint.sh"]
