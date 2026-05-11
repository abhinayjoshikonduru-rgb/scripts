#!/bin/bash

echo "===================================================="
echo " DevOps Interactive Installation Script"
echo " Java17 + Java21 + Jenkins + Docker + SonarQube + Tomcat"
echo "===================================================="

# ------------------------------------------------
# Variables
# ------------------------------------------------

SONAR_VERSION="10.7.0.96327"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_DIR="/opt/sonarqube-${SONAR_VERSION}"
SONAR_LINK="/opt/sonarqube"

TOMCAT_VERSION="9.0.102"
TOMCAT_FILE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/${TOMCAT_FILE}"
TOMCAT_HOME="/opt/tomcat"

JAVA17_HOME="/usr/lib/jvm/java-17-amazon-corretto.x86_64"
JAVA21_HOME="/usr/lib/jvm/java-21-amazon-corretto.x86_64"

INSTALL_ALL="no"

# ------------------------------------------------
# Get Public IP
# ------------------------------------------------

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="<EC2-PUBLIC-IP>"
fi

# ------------------------------------------------
# Helper Functions
# ------------------------------------------------

ask_yes_no() {

    read -p "$1 yes/no: " choice

    case "$choice" in
        yes|y|YES|Y)
            return 0
            ;;
        no|n|NO|N)
            return 1
            ;;
        *)
            echo "Invalid input. Considering as no."
            return 1
            ;;
    esac
}

ask_install() {

    if [ "$INSTALL_ALL" == "yes" ]; then
        return 0
    fi

    ask_yes_no "Do you want to install $1?"
    return $?
}

# ------------------------------------------------
# Install All Option
# ------------------------------------------------

if ask_yes_no "Do you want to install all tools?"; then

    INSTALL_ALL="yes"

    echo "You selected install all tools."

else

    INSTALL_ALL="no"

    echo "You selected custom installation."

fi

# ------------------------------------------------
# System Details
# ------------------------------------------------

echo ""
echo "============= SYSTEM DETAILS ============="

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "CPU:"
nproc

echo ""
echo "=========================================="

# ------------------------------------------------
# Increase /tmp Size
# ------------------------------------------------

mount -o remount,size=2G /tmp 2>/dev/null

# ------------------------------------------------
# Required Packages
# ------------------------------------------------

echo ""
echo "Installing required packages..."

yum install -y \
wget \
curl \
git \
unzip \
tar \
lsof \
net-tools \
fontconfig \
ca-certificates

update-ca-trust

# ------------------------------------------------
# Java Installation
# ------------------------------------------------

if ask_install "Java 17 and Java 21"; then

    echo ""
    echo "Installing Java 17 and Java 21 JDK..."

    yum install -y \
    java-17-amazon-corretto-devel \
    java-21-amazon-corretto-devel

    echo ""
    echo "Installed Java Directories:"
    ls -lrt /usr/lib/jvm/

    echo ""
    echo "Java 17 Version:"
    ${JAVA17_HOME}/bin/java -version

    echo ""
    echo "Java 21 Version:"
    ${JAVA21_HOME}/bin/java -version

else

    echo "Skipping Java installation..."

fi

# ------------------------------------------------
# Maven Installation
# ------------------------------------------------

if ask_install "Maven"; then

    echo ""
    echo "Installing Maven..."

    yum install maven -y

    export JAVA_HOME=${JAVA17_HOME}
    export PATH=$JAVA_HOME/bin:$PATH

    echo ""
    echo "Maven Version:"
    mvn -version

else

    echo "Skipping Maven installation..."

fi

# ------------------------------------------------
# Docker Installation
# ------------------------------------------------

if ask_install "Docker"; then

    echo ""
    echo "Installing Docker..."

    yum install docker -y

    systemctl enable docker
    systemctl restart docker

    sleep 5

    echo ""
    docker --version

else

    echo "Skipping Docker installation..."

fi

# ------------------------------------------------
# Jenkins Installation
# ------------------------------------------------

if ask_install "Jenkins"; then

    echo ""
    echo "Installing Jenkins..."

    systemctl stop jenkins 2>/dev/null

    yum remove jenkins -y

    rm -rf /var/lib/jenkins
    rm -rf /etc/yum.repos.d/jenkins.repo

    wget --no-check-certificate \
    -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

    yum install jenkins -y

    echo ""
    echo "Configuring Jenkins with Java 21..."

    sed -i '/^JENKINS_JAVA_CMD=/d' /etc/sysconfig/jenkins

    echo "JENKINS_JAVA_CMD=${JAVA21_HOME}/bin/java" >> /etc/sysconfig/jenkins

    systemctl daemon-reload

    systemctl enable jenkins
    systemctl restart jenkins

    echo ""
    echo "Waiting for Jenkins startup..."

    sleep 40

else

    echo "Skipping Jenkins installation..."

fi

# ------------------------------------------------
# SonarQube Installation
# ------------------------------------------------

if ask_install "SonarQube"; then

    echo ""
    echo "Installing SonarQube..."

    sysctl -w vm.max_map_count=262144
    sysctl -w fs.file-max=65536

    grep -q "vm.max_map_count=262144" /etc/sysctl.conf || \
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    grep -q "fs.file-max=65536" /etc/sysctl.conf || \
    echo "fs.file-max=65536" >> /etc/sysctl.conf

    systemctl stop sonarqube 2>/dev/null

    rm -rf /opt/sonarqube*
    rm -f /etc/systemd/system/sonarqube.service

    if ! id sonar &>/dev/null; then

        useradd sonar

        echo "sonar:sonar" | chpasswd

    fi

    cd /opt || exit

    wget --no-check-certificate \
    https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}

    unzip -q ${SONAR_ZIP}

    ln -s ${SONAR_DIR} ${SONAR_LINK}

    chown -R sonar:sonar ${SONAR_DIR}
    chown -h sonar:sonar ${SONAR_LINK}

    cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking

User=sonar
Group=sonar

Environment=JAVA_HOME=${JAVA17_HOME}
Environment=PATH=${JAVA17_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

ExecStart=${SONAR_LINK}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_LINK}/bin/linux-x86-64/sonar.sh stop

Restart=always

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable sonarqube
    systemctl restart sonarqube

    echo ""
    echo "Waiting for SonarQube startup..."

    sleep 50

else

    echo "Skipping SonarQube installation..."

fi

# ------------------------------------------------
# Tomcat Installation
# ------------------------------------------------

if ask_install "Tomcat"; then

    echo ""
    echo "Installing Tomcat..."

    rm -rf ${TOMCAT_HOME}
    rm -f /opt/${TOMCAT_FILE}

    cd /opt || exit

    wget --no-check-certificate ${TOMCAT_URL}

    tar -xvzf ${TOMCAT_FILE}

    mv apache-tomcat-${TOMCAT_VERSION} tomcat

    chmod -R 755 ${TOMCAT_HOME}

    chmod +x ${TOMCAT_HOME}/bin/*.sh

    # ------------------------------------------------
    # Configure Tomcat Users
    # ------------------------------------------------

    cat > ${TOMCAT_HOME}/conf/tomcat-users.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>

<tomcat-users>

<role rolename="manager-gui"/>
<role rolename="manager-script"/>
<role rolename="manager-jmx"/>
<role rolename="manager-status"/>

<user username="admin"
      password="admin"
      roles="manager-gui,manager-script,manager-jmx,manager-status"/>

</tomcat-users>
EOF

    # ------------------------------------------------
    # Remove Tomcat Manager Restriction
    # ------------------------------------------------

    cat > ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml <<EOF
<Context antiResourceLocking="false" privileged="true">

<!--
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
allow="127\\.\d+\\.\d+\\.\d+|::1|0:0:0:0:0:0:0:1" />
-->

<Manager sessionAttributeValueClassNameFilter="java\\.lang\\.(?:Boolean|Integer|Long|Number|String)|org\\.apache\\.catalina\\.filters\\.CsrfPreventionFilter\\$LruCache(?:\\$1)?|java\\.util\\.(?:Linked)?HashMap"/>

</Context>
EOF

    # ------------------------------------------------
    # Change Tomcat Port
    # ------------------------------------------------

    sed -i 's/port="8080"/port="9090"/g' \
    ${TOMCAT_HOME}/conf/server.xml

    # ------------------------------------------------
    # Configure Java 17 for Tomcat
    # ------------------------------------------------

    cat > ${TOMCAT_HOME}/bin/setenv.sh <<EOF
export JAVA_HOME=${JAVA17_HOME}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

    chmod +x ${TOMCAT_HOME}/bin/setenv.sh

    # ------------------------------------------------
    # Kill Existing Process
    # ------------------------------------------------

    pkill -f tomcat

    sleep 5

    PORT_9090_PID=$(lsof -ti:9090)

    if [ ! -z "$PORT_9090_PID" ]; then

        kill -9 $PORT_9090_PID

    fi

    # ------------------------------------------------
    # Start Tomcat
    # ------------------------------------------------

    echo ""
    echo "Starting Tomcat..."

    export JAVA_HOME=${JAVA17_HOME}
    export PATH=$JAVA_HOME/bin:$PATH

    echo "JAVA_HOME=$JAVA_HOME"

    ${TOMCAT_HOME}/bin/startup.sh

    sleep 15

else

    echo "Skipping Tomcat installation..."

fi

# ------------------------------------------------
# Final Status
# ------------------------------------------------

echo ""
echo "============= FINAL STATUS ============="

echo ""
echo "EC2 Public IP: ${PUBLIC_IP}"

# ------------------------------------------------
# Java Status
# ------------------------------------------------

echo ""

if [ -d "${JAVA17_HOME}" ]; then

    echo "Java 17 installed successfully"

else

    echo "Java 17 not installed"

fi

if [ -d "${JAVA21_HOME}" ]; then

    echo "Java 21 installed successfully"

else

    echo "Java 21 not installed"

fi

# ------------------------------------------------
# Maven Status
# ------------------------------------------------

echo ""

if command -v mvn >/dev/null 2>&1; then

    export JAVA_HOME=${JAVA17_HOME}
    export PATH=$JAVA_HOME/bin:$PATH

    echo "Maven installed successfully"

    mvn -version | head -1

else

    echo "Maven not installed"

fi

# ------------------------------------------------
# Docker Status
# ------------------------------------------------

echo ""

if systemctl is-active --quiet docker; then

    echo "Docker started successfully"

    docker --version

else

    echo "Docker failed to start"

fi

# ------------------------------------------------
# Jenkins Status
# ------------------------------------------------

echo ""

if systemctl is-active --quiet jenkins; then

    echo "Jenkins started successfully"

    echo "Jenkins URL: http://${PUBLIC_IP}:8080"

    echo "Jenkins password location:"
    echo "/var/lib/jenkins/secrets/initialAdminPassword"

    echo "Jenkins Java: Java 21"

else

    echo "Jenkins failed to start"

    journalctl -u jenkins -n 30 --no-pager

fi

# ------------------------------------------------
# SonarQube Status
# ------------------------------------------------

echo ""

if systemctl is-active --quiet sonarqube; then

    echo "SonarQube started successfully"

    echo "SonarQube URL: http://${PUBLIC_IP}:9000"

    echo "SonarQube username: admin"

    echo "SonarQube password: admin"

    echo "SonarQube Java: Java 17"

else

    echo "SonarQube failed to start"

    echo ""
    echo "SonarQube Logs:"

    tail -50 ${SONAR_LINK}/logs/sonar.log 2>/dev/null

fi

# ------------------------------------------------
# Tomcat Status
# ------------------------------------------------

echo ""

if lsof -i:9090 >/dev/null 2>&1; then

    echo "Tomcat started successfully"

    echo "Tomcat URL: http://${PUBLIC_IP}:9090"

    echo "Tomcat Manager URL:"
    echo "http://${PUBLIC_IP}:9090/manager/html"

    echo "Tomcat Username: admin"

    echo "Tomcat Password: admin"

    echo "Tomcat Java: Java 17"

else

    echo "Tomcat failed to start"

    echo ""

    if [ -f "${TOMCAT_HOME}/logs/catalina.out" ]; then

        echo "Tomcat Logs:"
        tail -100 ${TOMCAT_HOME}/logs/catalina.out

    else

        echo "Tomcat log file not found"

    fi

fi

# ------------------------------------------------
# Port Status
# ------------------------------------------------

echo ""
echo "============= PORT STATUS ============="

ss -tulnp | grep -E '8080|9000|9090'

# ------------------------------------------------
# Resource Summary
# ------------------------------------------------

echo ""
echo "============= SYSTEM RESOURCE SUMMARY ============="

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "CPU Count:"
nproc

echo ""
echo "==================================================="
