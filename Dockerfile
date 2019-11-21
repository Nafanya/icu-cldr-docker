FROM debian:stretch as build
LABEL maintanier="nikitai@google.com"

USER root
ENV HOME /home/build

# RUN apk --update add gcc make python g++ ccache valgrind doxygen tar zip curl wget git bash bsd-compat-headers

RUN apt-get update && \
    mkdir -p /usr/share/man/man1 && \
    DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade >/dev/null && \
    DEBIAN_FRONTEND=noninteractive apt-get -q -y install >/dev/null \
    git \
    build-essential \
    ant \
    maven \
    openjdk-8-jdk \
    ca-certificates-java

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
    git clone --depth=1 --branch maint/maint-66 https://github.com/unicode-org/icu.git && \
    (cd icu; git lfs install; git lfs pull) && \
    git clone --depth=1 --branch release-36 https://github.com/unicode-org/cldr.git && \
    (cd cldr; git lfs install; git lfs pull) && \
    git clone --depth=1 --branch release-36 https://github.com/unicode-org/cldr-staging.git && \
    (cd cldr-staging; git lfs install; git lfs pull)

# Build tool from cldr repo
RUN ant -f $HOME/icu/icu4j/build.xml jar cldrUtil

ENV CLASSPATH $HOME/icu/icu4j/icu4j.jar:$HOME/icu/icu4j/out/cldr_util/lib/utilities.jar:$CLASSPATH
ENV CLDR_DIR $HOME/cldr

RUN ant -f $HOME/cldr/tools/java/build.xml jar

RUN cd $HOME/icu/tools/cldr/cldr-to-icu/lib && \
    mvn install:install-file \
       -DgroupId=org.unicode.cldr \
       -DartifactId=cldr-api \
       -Dversion=0.1-SNAPSHOT \
       -Dpackaging=jar \
       -DgeneratePom=true \
       -DlocalRepositoryPath=. \
       -Dfile=$HOME/cldr/tools/java/cldr.jar && \
    mvn install:install-file \
       -DgroupId=com.ibm.icu \
       -DartifactId=icu-utilities \
       -Dversion=0.1-SNAPSHOT \
       -Dpackaging=jar \
       -DgeneratePom=true \
       -DlocalRepositoryPath=. \
       -Dfile=$HOME/icu/icu4j/out/cldr_util/lib/utilities.jar && \
    cd $HOME/icu/tools/cldr/cldr-to-icu && \
    mvn dependency:purge-local-repository -DsnapshotsOnly=true

ENV CLDR_CLASSES $HOME/cldr/tools/java/classes

# RUN ant -f $HOME/icu/tools/cldr/cldr-to-icu/build-icu-data.xml \
#         -DcldrDir=$HOME/cldr-staging/production \
#         -DoutDir=$HOME/cldr-production-data \
#         -DincludePseudoLocales=true
# 
# # Overwrite icu4c's data with freshly-built production data
# RUN rsync -a $HOME/cldr-production-data/ $HOME/icu/icu4c/source/data
# 
# RUN ICU_DATA_BUILDTOOL_OPTS=--include_uni_core_data $HOME/icu/icu4c/source/runConfigureICU Linux
