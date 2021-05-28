FROM adoptopenjdk:8-jdk-hotspot-focal
LABEL maintainer="Atlassian Bamboo Team" \
      description="Official Bamboo Agent Docker Image"

ENV BAMBOO_USER=bamboo
ENV BAMBOO_GROUP=bamboo

ENV BAMBOO_USER_HOME=/home/${BAMBOO_USER}
ENV BAMBOO_AGENT_HOME=${BAMBOO_USER_HOME}/bamboo-agent-home

ENV INIT_BAMBOO_CAPABILITIES=${BAMBOO_USER_HOME}/init-bamboo-capabilities.properties
ENV BAMBOO_CAPABILITIES=${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties

RUN set -x && \
     addgroup ${BAMBOO_GROUP} && \
     adduser ${BAMBOO_USER} --home ${BAMBOO_USER_HOME} --ingroup ${BAMBOO_GROUP} --disabled-password

RUN set -x && \
     apt-get update && \
     apt-get install -y --no-install-recommends \
          curl \
          tini \
          wget \
          gnupg2 \
     && \
# create symlink for java home backward compatibility
     mkdir -m 755 -p /usr/lib/jvm && \
     ln -s "${JAVA_HOME}" /usr/lib/jvm/java-8-openjdk-amd64 && \
     rm -rf /var/lib/apt/lists/*


# mavem & git
RUN apt-get update && \
    apt-get install maven -y && \
    apt-get install git -y


# Atlas SDK
RUN echo "deb https://packages.atlassian.com/atlassian-sdk-deb stable contrib" >>/etc/apt/sources.list \
    && wget https://packages.atlassian.com/api/gpg/key/public  \
    && apt-key add public \
    && apt-get update \
    && apt-get install -y atlassian-plugin-sdk \
    && mkdir /opt/atlas \
    && cd /opt/atlas

# Node.js & Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash -
RUN apt-get install -y nodejs yarn

# Cypress dependencies
USER root
RUN apt-get install -y libgtk2.0-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 xvfb

USER root
COPY cleanup.sh cleanup.sh
RUN chmod +x ./cleanup.sh
RUN ./cleanup.sh

WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

ARG BAMBOO_VERSION
ARG DOWNLOAD_URL=https://packages.atlassian.com/maven-closedsource-local/com/atlassian/bamboo/atlassian-bamboo-agent-installer/${BAMBOO_VERSION}/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
ENV AGENT_JAR=${BAMBOO_USER_HOME}/atlassian-bamboo-agent-installer.jar

RUN set -x && \
     curl -L --silent --output ${AGENT_JAR} ${DOWNLOAD_URL} && \
     mkdir -p ${BAMBOO_USER_HOME}/bamboo-agent-home/bin

COPY --chown=bamboo:bamboo bamboo-update-capability.sh bamboo-update-capability.sh
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 1.8" ${JAVA_HOME}/bin/java
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.Maven 3.3" /usr/share/maven
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.git.executable" /usr/bin/git
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.atlas-package" /usr/bin/atlas-package
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.atlas-clean" /usr/bin/atlas-clean
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.atlas-integration-test" /usr/bin/atlas-integration-test
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.node.Node.js 16" /usr/bin/node

COPY --chown=bamboo:bamboo runAgent.sh runAgent.sh
ENTRYPOINT ["./runAgent.sh"]
