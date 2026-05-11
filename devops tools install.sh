#!/bin/bash

echo "===================================================="
echo " DevOps Tools Interactive Installation Script"
echo " Java + Git + Maven + Jenkins + Docker + SonarQube + Tomcat"
echo "===================================================="

# ------------------------------------------------
# Variables
# ------------------------------------------------

SONAR_VERSION="10.7.0.96327"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_DIR="/opt/sonarqube-${SONAR_VERSION}"
SONAR_LINK="/opt/sonarqube"

JENKINS_RPM="jenkins-2.479.3-1.1.noarch.rpm"
JENKINS_URL="https://archives.jenkins.io/redhat-stable/${JENKINS_RPM}"

TOMCAT_VERSION="9.0.102"
TOMCAT_FILE="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/${TOMCAT_FILE}"
TOMCAT_HOME="/opt/tomcat"

JAVA_STATUS="Skipped"
GIT_STATUS="Skipped"
MAVEN_STATUS="Skipped"

JENKINS_INSTALL_STATUS="Skipped"
JENKINS_START_STATUS="Skipped"

DOCKER_INSTALL_STATUS="Skipped"
DOCKER_START_STATUS="Skipped"

SONAR_INSTALL_STATUS="Skipped"
SONAR_START_STATUS="Skipped"

TOMCAT_INSTALL_STATUS="Skipped"
TOMCAT_START_STATUS="Skipped"

INSTALL_ALL="no"

# ------------------------------------------------
# Get EC2 Public IP using IMDSv2
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

echo "-------------------------------------------"

# ------------------------------------------------
# System Pre-check
# ------------------------------------------------

echo "System Pre-check"
echo "-------------------------------------------"

echo "Memory:"
free -h

echo "-------------------------------------------"

echo "Disk:"
df -h

echo "-------------------------------------------"

echo "CPU Count:"
nproc

echo "-------------------------------------------"

# ------------------------------------------------
# Increase /tmp Size
# ------------------------------------------------

echo "Increasing /tmp size..."

mount -o remount,size=2G /tmp 2>/dev/null

echo "-------------------------------------------"

# ------------------------------------------------
# Java Installation
# ------------------------------------------------

if ask_install "Java 17"; then

    echo "Installing Java 17..."

    yum install java-17-amazon-corretto -y

    if [ $? -eq 0 ]; then

        JAVA_STATUS="Java installed successfully - Version: $(java -version 2>&1 | head -1 | awk -F '\"' '{print $2}')"

        echo "$JAVA_STATUS"

    else

        JAVA_STATUS="Java installation failed"

        echo "$JAVA_STATUS"

    fi

else

    echo "Skipping Java installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# Git Installation
# ------------------------------------------------

if ask_install "Git"; then

    echo "Installing Git..."

    yum install git -y

    if [ $? -eq 0 ]; then

        GIT_STATUS="Git installed successfully - Version: $(git --version | awk '{print $3}')"

        echo "$GIT_STATUS"

    else

        GIT_STATUS="Git installation failed"

        echo "$GIT_STATUS"

    fi

else

    echo "Skipping Git installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# Maven Installation
# ------------------------------------------------

if ask_install "Maven"; then

    echo "Installing Maven..."

    yum install maven -y

    if [ $? -eq 0 ]; then

        MAVEN_STATUS="Maven installed successfully - Version: $(mvn -version | head -1 | awk '{print $3}')"

        echo "$MAVEN_STATUS"

    else

        MAVEN_STATUS="Maven installation failed"

        echo "$MAVEN_STATUS"

    fi

else

    echo "Skipping Maven installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# Required Packages
# ------------------------------------------------

echo "Installing required packages..."

yum install wget unzip tar curl net-tools lsof fontconfig -y

echo "-------------------------------------------"

# ------------------------------------------------
# Jenkins Installation
# ------------------------------------------------

if ask_install "Jenkins"; then

    echo "Stopping old Jenkins..."

    systemctl stop jenkins 2>/dev/null
    systemctl disable jenkins 2>/dev/null

    echo "Removing old Jenkins..."

    yum remove jenkins -y

    rm -rf /var/lib/jenkins
    rm -rf /etc/sysconfig/jenkins
    rm -rf /usr/lib/systemd/system/jenkins.service
    rm -f /opt/${JENKINS_RPM}

    echo "Installing Jenkins..."

    cd /opt || exit

    wget --no-check-certificate ${JENKINS_URL}

    if [ -f "/opt/${JENKINS_RPM}" ]; then

        rpm -ivh ${JENKINS_RPM}

        if [ $? -eq 0 ]; then

            JENKINS_INSTALL_STATUS="Jenkins installed successfully"

            echo "$JENKINS_INSTALL_STATUS"

            systemctl daemon-reload
            systemctl enable jenkins
            systemctl start jenkins

            sleep 20

            if systemctl is-active --quiet jenkins; then

                JENKINS_START_STATUS="Jenkins started successfully"

                echo "$JENKINS_START_STATUS"

            else

                JENKINS_START_STATUS="Jenkins failed to start"

                echo "$JENKINS_START_STATUS"

                journalctl -u jenkins -n 50 --no-pager

            fi

        else

            JENKINS_INSTALL_STATUS="Jenkins installation failed"

            echo "$JENKINS_INSTALL_STATUS"

        fi

    else

        JENKINS_INSTALL_STATUS="Jenkins RPM download failed"

        echo "$JENKINS_INSTALL_STATUS"

    fi

else

    echo "Skipping Jenkins installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# Docker Installation
# ------------------------------------------------

if ask_install "Docker"; then

    echo "Installing Docker..."

    yum install docker -y

    if [ $? -eq 0 ]; then

        DOCKER_INSTALL_STATUS="Docker installed successfully - Version: $(docker --version | awk '{print $3}' | sed 's/,//')"

        echo "$DOCKER_INSTALL_STATUS"

        systemctl enable docker
        systemctl start docker

        sleep 5

        if systemctl is-active --quiet docker; then

            DOCKER_START_STATUS="Docker started successfully"

            echo "$DOCKER_START_STATUS"

        else

            DOCKER_START_STATUS="Docker failed to start"

            echo "$DOCKER_START_STATUS"

        fi

    else

        DOCKER_INSTALL_STATUS="Docker installation failed"

        echo "$DOCKER_INSTALL_STATUS"

    fi

else

    echo "Skipping Docker installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# SonarQube Installation
# ------------------------------------------------

if ask_install "SonarQube"; then

    echo "Installing SonarQube..."

    sysctl -w vm.max_map_count=262144
    sysctl -w fs.file-max=65536

    grep -q "vm.max_map_count=262144" /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    grep -q "fs.file-max=65536" /etc/sysctl.conf || echo "fs.file-max=65536" >> /etc/sysctl.conf

    systemctl stop sonarqube 2>/dev/null
    systemctl disable sonarqube 2>/dev/null

    rm -rf /opt/sonarqube*
    rm -f /etc/systemd/system/sonarqube.service

    if ! id sonar &>/dev/null; then
        useradd sonar
        echo "sonar:sonar" | chpasswd
    fi

    cd /opt || exit

    wget --no-check-certificate https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}

    if [ -f "/opt/${SONAR_ZIP}" ]; then

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
ExecStart=${SONAR_LINK}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_LINK}/bin/linux-x86-64/sonar.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        systemctl enable sonarqube
        systemctl start sonarqube

        sleep 30

        if systemctl is-active --quiet sonarqube; then

            SONAR_INSTALL_STATUS="SonarQube installed successfully - Version: ${SONAR_VERSION}"
            SONAR_START_STATUS="SonarQube started successfully"

            echo "$SONAR_INSTALL_STATUS"
            echo "$SONAR_START_STATUS"

        else

            SONAR_START_STATUS="SonarQube failed to start"

            echo "$SONAR_START_STATUS"

        fi

    else

        SONAR_INSTALL_STATUS="SonarQube download failed"

        echo "$SONAR_INSTALL_STATUS"

    fi

else

    echo "Skipping SonarQube installation..."

fi

echo "-------------------------------------------"

# ------------------------------------------------
# Apache Tomcat Installation
# ------------------------------------------------

if ask_install "Apache Tomcat"; then

    echo "Installing Apache Tomcat..."

    systemctl stop tomcat 2>/dev/null

    rm -rf ${TOMCAT_HOME}
    rm -f /opt/${TOMCAT_FILE}

    cd /opt || exit

    wget --no-check-certificate ${TOMCAT_URL}

    if [ -f "/opt/${TOMCAT_FILE}" ]; then

        tar -xvzf ${TOMCAT_FILE}

        mv apache-tomcat-${TOMCAT_VERSION} tomcat

        chmod +x ${TOMCAT_HOME}/bin/*.sh

        echo "Tomcat extracted successfully"

        # ------------------------------------------------
        # Update tomcat-users.xml
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

        echo "tomcat-users.xml updated"

        # ------------------------------------------------
        # Comment RemoteAddrValve in context.xml
        # ------------------------------------------------

        sed -i '21s/^/<!-- /' ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml

        sed -i '22s/$/ -->/' ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml

        echo "context.xml updated"

        # ------------------------------------------------
        # Change Tomcat Port
        # ------------------------------------------------

        sed -i 's/port="8080"/port="9090"/g' ${TOMCAT_HOME}/conf/server.xml

        echo "Tomcat port changed to 9090"

        # ------------------------------------------------
        # Start Tomcat
        # ------------------------------------------------

        ${TOMCAT_HOME}/bin/startup.sh

        sleep 10

        if lsof -i:9090 >/dev/null 2>&1; then

            TOMCAT_INSTALL_STATUS="Tomcat installed successfully - Version: ${TOMCAT_VERSION}"

            TOMCAT_START_STATUS="Tomcat started successfully"

            echo "$TOMCAT_INSTALL_STATUS"

            echo "$TOMCAT_START_STATUS"

        else

            TOMCAT_START_STATUS="Tomcat failed to start"

            echo "$TOMCAT_START_STATUS"

            tail -50 ${TOMCAT_HOME}/logs/catalina.out

        fi

    else

        TOMCAT_INSTALL_STATUS="Tomcat download failed"

        echo "$TOMCAT_INSTALL_STATUS"

    fi

else

    echo "Skipping Tomcat installation..."

fi

echo "-------------------------------------------"
echo "Installation Completed"
echo "-------------------------------------------"

echo ""
echo "============= FINAL STATUS ============="

echo "EC2 Public IP: ${PUBLIC_IP}"

echo ""
echo "$JAVA_STATUS"
echo "$GIT_STATUS"
echo "$MAVEN_STATUS"

echo ""
echo "$JENKINS_INSTALL_STATUS"
echo "$JENKINS_START_STATUS"

if [[ "$JENKINS_START_STATUS" == "Jenkins started successfully" ]]; then

    echo "Jenkins URL: http://${PUBLIC_IP}:8080"

    echo "Jenkins password location: /var/lib/jenkins/secrets/initialAdminPassword"

fi

echo ""
echo "$DOCKER_INSTALL_STATUS"
echo "$DOCKER_START_STATUS"

echo ""
echo "$SONAR_INSTALL_STATUS"
echo "$SONAR_START_STATUS"

if [[ "$SONAR_START_STATUS" == "SonarQube started successfully" ]]; then

    echo "SonarQube URL: http://${PUBLIC_IP}:9000"

    echo "SonarQube username: admin"

    echo "SonarQube password: admin"

fi

echo ""
echo "$TOMCAT_INSTALL_STATUS"
echo "$TOMCAT_START_STATUS"

if [[ "$TOMCAT_START_STATUS" == "Tomcat started successfully" ]]; then

    echo "Tomcat URL: http://${PUBLIC_IP}:9090"

    echo "Tomcat Manager URL: http://${PUBLIC_IP}:9090/manager/html"

    echo "Tomcat Username: admin"

    echo "Tomcat Password: admin"

    echo "Tomcat Installed Path: /opt/tomcat"

fi

echo ""
echo "============= SYSTEM RESOURCE SUMMARY ============="

echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h

echo ""
echo "CPU Count:"
nproc

echo "===================================================="
