FROM debian:latest as build
LABEL maintanier="nikitai@google.com"

USER root
ENV HOME /home/build

# RUN apk --update add gcc make python g++ ccache valgrind doxygen tar zip curl wget git bash bsd-compat-headers

RUN apt-get update && \
    mkdir -p /usr/share/man/man1 && \
    DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade >/dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get -q -y install >/dev/null \
    wget \
    git \
    build-essential \
    maven \
    openjdk-11-jdk \
    ca-certificates-java \
    rsync \
    python

RUN mkdir -p /home/build

# Install git-lfs
RUN build_deps="curl" && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} ca-certificates && \
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git-lfs && \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove ${build_deps} && \
    rm -r /var/lib/apt/lists/*

ENV GIT_LFS_SKIP_SMUDGE 1

# Clone cldr, cldr-staging and icu repos and checkout release-36/maint-66 revisions
RUN cd /home/build && \
    git clone --depth=1 --branch release-65-1 https://github.com/unicode-org/icu.git && \
    (cd icu; git lfs install; git lfs pull) && \
    git clone --depth=1 --branch release-36 https://github.com/unicode-org/cldr.git && \
    (cd cldr; git lfs install; git lfs pull) && \
    git clone --depth=1 --branch release-36 https://github.com/unicode-org/cldr-staging.git && \
    (cd cldr-staging; git lfs install; git lfs pull)

RUN cd $HOME && \
    mkdir -p misc && cd misc && \
    wget https://www.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.tar.gz && \
    tar -xzf apache-ant-1.10.6-bin.tar.gz

ENV PATH /home/build/misc/apache-ant-1.10.6/bin:$PATH

RUN sed -i 's/PSEUDOLOCALES_DIRECTORY = "pseudolocales";/PSEUDOLOCALES_DIRECTORY = ".";/g' $HOME/cldr/tools/java/org/unicode/cldr/tool/CLDRFilePseudolocalizer.java

RUN sed -i 's!<property name="env.CLDR_TMP_DIR" location="${env.CLDR_DIR}/../cldr-aux" />!<property name="env.CLDR_TMP_DIR" location="${env.CLDR_DIR}/../cldr-staging" />!g' $HOME/icu/icu4c/source/data/build.xml

# Build tool from cldr repo
RUN ant -f $HOME/icu/icu4j/build.xml jar cldrUtil

ENV CLASSPATH $HOME/icu/icu4j/icu4j.jar:$HOME/icu/icu4j/out/cldr_util/lib/utilities.jar:$CLASSPATH
ENV CLDR_DIR $HOME/cldr

RUN cp -r $HOME/cldr-staging/production/* $HOME/cldr/

RUN ant -f $HOME/cldr/tools/java/build.xml jar AddPseudolocales

ENV CLDR_CLASSES $HOME/cldr/tools/java/classes

RUN ant -f $HOME/icu/icu4c/source/data/build.xml all

# I expect to find en_XA.txt and ar_XB.txt
RUN find $HOME/icu -name 'en_XA*' -o -name 'ar_XB*'

# RUN cd $HOME && mkdir -p build-icu && cd build-icu && \
#     ICU_DATA_BUILDTOOL_OPTS=--include_uni_core_data $HOME/icu/icu4c/source/runConfigureICU Linux && \
#     make -j`nproc`

