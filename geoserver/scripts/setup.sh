#!/usr/bin/env bash
# Download geoserver extensions and other resources

function create_dir() {
DATA_PATH=$1

if [[ ! -d ${DATA_PATH} ]];
then
    echo "Creating" ${DATA_PATH}  "directory"
    mkdir -p ${DATA_PATH}
else
    echo ${DATA_PATH} "exists - skipping creation"
fi
}

resources_dir="/tmp/resources"
create_dir ${FOOTPRINTS_DATA_DIR}
create_dir ${resources_dir}
pushd ${resources_dir}




#Policy

if [[ ! -f /tmp/resources/jce_policy.zip ]]; then \
    wget --progress=bar:force:noscroll -c --no-check-certificate --no-cookies --header \
    "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip -O /tmp/resources/jce_policy.zip
fi;

work_dir=`pwd`

create_dir ${work_dir}/plugins

pushd ${work_dir}/plugins
#Extensions

array=(geoserver-$GS_VERSION-vectortiles-plugin.zip geoserver-$GS_VERSION-css-plugin.zip \
geoserver-$GS_VERSION-csw-plugin.zip geoserver-$GS_VERSION-wps-plugin.zip geoserver-$GS_VERSION-printing-plugin.zip \
geoserver-$GS_VERSION-libjpeg-turbo-plugin.zip geoserver-$GS_VERSION-control-flow-plugin.zip \
geoserver-$GS_VERSION-pyramid-plugin.zip geoserver-$GS_VERSION-gdal-plugin.zip \
geoserver-$GS_VERSION-sldservice-plugin.zip  \
geoserver-$GS_VERSION-importer-plugin.zip geoserver-$GS_VERSION-charts-plugin.zip)
for i in "${array[@]}"
do
    url="https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/${i}/download"
    if curl --output /dev/null --silent --head --fail "${url}"; then
      echo "URL exists: ${url}"
      wget --progress=bar:force:noscroll -c --no-check-certificate ${url} -O /tmp/resources/plugins/${i}
    else
      echo "URL does not exist: ${url}"
    fi;
done

create_dir gdal
pushd gdal

wget --progress=bar:force:noscroll -c --no-check-certificate \
http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/gdal-data.zip
popd
wget --progress=bar:force:noscroll -c --no-check-certificate \
http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/linux/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz

popd

# Install libjpeg-turbo for that specific geoserver GS_VERSION
if [[ ! -f /tmp/resources/libjpeg-turbo-official_1.5.3_amd64.deb ]]; then \
    wget --progress=bar:force:noscroll -c --no-check-certificate \
    https://sourceforge.net/projects/libjpeg-turbo/files/1.5.3/libjpeg-turbo-official_1.5.3_amd64.deb \
    -P /tmp/resources;\
    fi; \
    cd /tmp/resources/ && \
    dpkg -i libjpeg-turbo-official_1.5.3_amd64.deb

# If a matching Oracle JDK tar.gz exists in /tmp/resources, move it to /var/cache/oracle-jdk8-installer
# where oracle-java8-installer will detect it
if ls /tmp/resources/*jdk-*-linux-x64.tar.gz > /dev/null 2>&1; then \
      mkdir /var/cache/oracle-jdk8-installer && \
      mv /tmp/resources/*jdk-*-linux-x64.tar.gz /var/cache/oracle-jdk8-installer/; \
    fi;

# Build geogig and other community modules

if  [[ "$COMMUNITY_MODULES" == true ]]; then
    array=( geoserver-${GS_VERSION:0:4}-SNAPSHOT-mbtiles-plugin.zip \
    geoserver-${GS_VERSION:0:4}-SNAPSHOT-mbstyle-plugin.zip \
    geoserver-${GS_VERSION:0:4}-SNAPSHOT-s3-geotiff-plugin.zip geoserver-${GS_VERSION:0:4}-SNAPSHOT-gwc-s3-plugin.zip)
    for i in "${array[@]}"
    do
	    wget --progress=bar:force:noscroll -c --no-check-certificate \
	    https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/${i} \
	    -O /tmp/resources/plugins/${i}
    done

else
    echo "Building community modules will be disabled"
fi;

pushd /tmp/

 if [[ ! -f /tmp/resources/jai-1_1_3-lib-linux-amd64.tar.gz ]]; then \
    wget --progress=bar:force:noscroll -c --no-check-certificate \
    http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64.tar.gz \
    -P /tmp/resources;\
    fi; \
    if [[ ! -f /tmp/resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ]]; then \
    wget --progress=bar:force:noscroll -c --no-check-certificate \
    http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64.tar.gz \
    -P /tmp/resources;\
    fi; \
    mv ./resources/jai-1_1_3-lib-linux-amd64.tar.gz ./ && \
    mv ./resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ./ && \
    gunzip -c jai-1_1_3-lib-linux-amd64.tar.gz | tar xf - && \
    gunzip -c jai_imageio-1_1-lib-linux-amd64.tar.gz | tar xf - && \
    mv /tmp/jai-1_1_3/lib/*.jar ${JAVA_HOME}/jre/lib/ext/ && \
    mv /tmp/jai-1_1_3/lib/*.so ${JAVA_HOME}/jre/lib/amd64/ && \
    mv /tmp/jai_imageio-1_1/lib/*.jar ${JAVA_HOME}/jre/lib/ext/ && \
    mv /tmp/jai_imageio-1_1/lib/*.so ${JAVA_HOME}/jre/lib/amd64/ && \
    rm /tmp/jai-1_1_3-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai-1_1_3 && \
    rm /tmp/jai_imageio-1_1-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai_imageio-1_1

pushd ${CATALINA_HOME}

# A little logic that will fetch the geoserver war zip file if it
# is not available locally in the resources dir
if [[ ! -f /tmp/resources/geoserver-${GS_VERSION}.zip ]]; then \
    if [[ "${WAR_URL}" == *\.zip ]]
    then
        destination=/tmp/resources/geoserver-${GS_VERSION}.zip
        wget --progress=bar:force:noscroll -c --no-check-certificate ${WAR_URL} -O ${destination};
        unzip /tmp/resources/geoserver-${GS_VERSION}.zip -d /tmp/geoserver
    else
        destination=/tmp/geoserver/geoserver.war
        mkdir -p /tmp/geoserver/ && \
        wget --progress=bar:force:noscroll -c --no-check-certificate ${WAR_URL} -O ${destination};
    fi;\
    fi; \
    unzip /tmp/geoserver/geoserver.war -d ${CATALINA_HOME}/webapps/geoserver \
    && cp -r ${CATALINA_HOME}/webapps/geoserver/data/user_projections ${GEOSERVER_DATA_DIR} \
    && cp -r ${CATALINA_HOME}/webapps/geoserver/data/security ${GEOSERVER_DATA_DIR} \
    && cp -r ${CATALINA_HOME}/webapps/geoserver/data/security ${CATALINA_HOME} \
    && rm -rf ${CATALINA_HOME}/webapps/geoserver/data \
    && rm -rf /tmp/geoserver

# Install any plugin zip files in resources/plugins
if ls /tmp/resources/plugins/*.zip > /dev/null 2>&1; then \
      for p in /tmp/resources/plugins/*.zip; do \
        unzip $p -d /tmp/gs_plugin \
        && mv /tmp/gs_plugin/*.jar ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/ \
        && rm -rf /tmp/gs_plugin; \
      done; \
    fi; \
    if ls /tmp/resources/plugins/*gdal*.tar.gz > /dev/null 2>&1; then \
    mkdir /usr/local/gdal_data && mkdir /usr/local/gdal_native_libs; \
    unzip /tmp/resources/plugins/gdal/gdal-data.zip -d /usr/local/gdal_data && \
    mv /usr/local/gdal_data/gdal-data/* /usr/local/gdal_data && rm -rf /usr/local/gdal_data/gdal-data && \
    tar xzf /tmp/resources/plugins/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz -C /usr/local/gdal_native_libs; \
    fi;
# Install Marlin render
if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-sun-java2d.jar ]]; then \
  wget --progress=bar:force:noscroll -c --no-check-certificate \
  https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_2/marlin-0.9.4.2-Unsafe-sun-java2d.jar \
  -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-sun-java2d.jar;
fi

if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin.jar ]]; then \
  wget --progress=bar:force:noscroll -c --no-check-certificate \
  https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_2/marlin-0.9.4.2-Unsafe.jar \
  -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin.jar;
fi

if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/sqljdbc.jar ]]; then \
  wget --progress=bar:force:noscroll -c --no-check-certificate \
  https://clojars.org/repo/com/microsoft/sqlserver/sqljdbc4/4.0/sqljdbc4-4.0.jar \
  -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/sqljdbc.jar;
fi

if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar ]]; then \
  wget --progress=bar:force:noscroll -c --no-check-certificate \
  https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/9.4.21.v20190926/jetty-servlets-9.4.21.v20190926.jar \
  -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar;
fi

if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-util.jar ]]; then \
  wget --progress=bar:force:noscroll -c --no-check-certificate \
  https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/9.4.21.v20190926/jetty-util-9.4.21.v20190926.jar \
  -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-util.jar;
fi

cp -a /tmp/geo-server-plugin/ ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/;

# Overlay files and directories in resources/overlays if they exist
rm -f /tmp/resources/overlays/README.txt && \
    if ls /tmp/resources/overlays/* > /dev/null 2>&1; then \
      cp -rf /tmp/resources/overlays/* /; \
    fi;

# install Font files in resources/fonts if they exist
if ls /tmp/resources/fonts/*.ttf > /dev/null 2>&1; then \
      cp -rf /tmp/resources/fonts/*.ttf /usr/share/fonts/truetype/; \
	fi;

# Remove Tomcat manager, docs, and examples
rm -rf ${CATALINA_HOME}/webapps/ROOT && \
rm -rf ${CATALINA_HOME}/webapps/docs && \
rm -rf ${CATALINA_HOME}/webapps/examples && \
rm -rf ${CATALINA_HOME}/webapps/host-manager && \
rm -rf ${CATALINA_HOME}/webapps/manager;

# Delete resources after installation
rm -rf /tmp/resources
rm -rf /tmp/geo-server-plugin
