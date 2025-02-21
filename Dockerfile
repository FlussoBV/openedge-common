FROM ubuntu:22.04 AS install

ENV JAVA_HOME=/opt/java/openjdk
COPY --from=eclipse-temurin:JDKVERSION $JAVA_HOME $JAVA_HOME
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# the running process (i.e. the github action) is responsible for placing the install .tar 
# in the correct location
ADD PROGRESS_OE.tar.gz /install/openedge/
ADD PROGRESS_PATCH_OE.tar.gz /install/patch/
ADD install-openedge.sh /install/

COPY response.ini /install/openedge/response.ini
ENV TERM=xterm

RUN /install/install-openedge.sh
RUN cat /install/install_oe.log

RUN ls -l /usr/
RUN ls -l /usr/wrk/

# multi stage build, this give the possibilty to remove all the slack from stage 0
FROM ubuntu:22.04 AS instance

LABEL maintainer="Bronco Oostermeyer <dev@bfv.io>"

ENV JAVA_HOME=/opt/java/openjdk
ENV DLC=/usr/dlc
ENV WRKDIR=/usr/wrk
ENV TERM=xterm

COPY --from=install $JAVA_HOME $JAVA_HOME
COPY --from=install $DLC $DLC
COPY --from=install $WRKDIR $WRKDIR

COPY protocols /etc/
COPY services /etc/
RUN chmod 644 /etc/protocols && \
    chmod 644 /etc/services

WORKDIR /usr/dlc/bin

RUN chown root _* && \
    chmod 4755 _* && \
    chmod 755 _sql* && \
    chmod -f 755 _waitfor || true

ENV TERM=xterm
ENV PATH=$DLC:$DLC/bin:$PATH:${JAVA_HOME}/bin:${PATH}

RUN groupadd -g 1000 openedge && \
    useradd -r -u 1000 -g openedge openedge

# allow for progress to be copied into $DLC
# kubernetes does not support volume mount of single files
RUN chown root:openedge $DLC
RUN chmod 775 $DLC

# create directories and files as root
RUN \
  mkdir /app/ 

# turn them over to user 'openedge'
RUN chown -R openedge:openedge /app/ 

USER openedge
