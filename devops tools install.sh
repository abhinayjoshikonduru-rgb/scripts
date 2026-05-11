#!/bin/bash

echo "===================================================="
echo " DevOps Tools Interactive Installation Script"
echo " Java + Git + Maven + Jenkins + Docker + SonarQube"
echo " + Apache HTTPD + Apache Tomcat"
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

# Apache Tomcat version compatible with JDK 17 (Tomcat 10.1.x supports Java 11+/17+)
TOMCAT_VERSION="10.1.39"
TOMCAT_DIR="apache-tomcat-${TOMCAT_VERSION}"
TOMCAT_TAR="${TOMCAT_DIR}.tar.gz"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/${TOMCAT_TAR}"
TOMCAT_INSTALL_DIR="/opt/${TOMCAT_DIR}"
TOMCAT_LINK="/opt/tomcat"

JAVA_STATUS="Skipped"
GIT_STATUS="Skipped"
MAVEN_STATUS="Skipped"
JENKINS_INSTALL_STATUS="Skipped"
JENKINS_START_STATUS="Skipped"
DOCKER_INSTALL_STATUS="Skipped"
DOCKER_START_STATUS="Skipped"
SONAR_INSTALL_STATUS="Skipped"
SONAR_START_STATUS="Skipped"
HTTPD_INSTALL_STATUS="Skipped"
HTTPD_START_STATUS="Skipped"
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
# Java 17 Installation
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
    echo "Skipping Java 17 installation..."
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
yum install wget unzip fontconfig curl net-tools lsof -y
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

    echo "Installing Jenkins Java 17 supported version..."

    cd /opt || exit

    wget ${JENKINS_URL}

    if [ -f "/opt/${JENKINS_RPM}" ]; then

        rpm -ivh ${JENKINS_RPM}

        if [ $? -eq 0 ]; then

            JENKINS_INSTALL_STATUS="Jenkins installed successfully - Version: $(rpm -qa | grep jenkins | cut -d'-' -f2)"
            echo "$JENKINS_INSTALL_STATUS"

            echo "Checking port 8080..."

            PORT_8080_PID=$(lsof -ti:8080)

            if [ ! -z "$PORT_8080_PID" ]; then
                echo "Port 8080 already in use. Killing process $PORT_8080_PID"
                kill -9 $PORT_8080_PID
            else
                echo "Port 8080 is free"
            fi

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

                echo "Jenkins service status:"
                systemctl status jenkins --no-pager

                echo "Jenkins logs:"
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

    echo "Stopping old Docker..."
    systemctl stop docker 2>/dev/null
    systemctl disable docker 2>/dev/null

    echo "Removing old Docker..."
    yum remove docker -y

    rm -rf /var/lib/docker

    echo "Installing Docker..."
    yum install docker -y

    if [ $? -eq 0 ]; then

        DOCKER_INSTALL_STATUS="Docker installed successfully - Version: $(docker --version | awk '{print $3}' | sed 's/,//')"
        echo "$DOCKER_INSTALL_STATUS"

        systemctl daemon-reload
        systemctl enable docker
        systemctl start docker

        sleep 5

        if systemctl is-active --quiet docker; then
            DOCKER_START_STATUS="Docker started successfully"
            echo "$DOCKER_START_STATUS"
        else
            DOCKER_START_STATUS="Docker failed to start"
            echo "$DOCKER_START_STATUS"

            systemctl status docker --no-pager
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

    echo "Applying SonarQube system settings..."

    sysctl -w vm.max_map_count=262144
    sysctl -w fs.file-max=65536

    grep -q "vm.max_map_count=262144" /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    grep -q "fs.file-max=65536" /etc/sysctl.conf || echo "fs.file-max=65536" >> /etc/sysctl.conf

    echo "Stopping old SonarQube if running..."

    if systemctl list-unit-files | grep -q sonarqube.service; then
        systemctl stop sonarqube 2>/dev/null
        systemctl disable sonarqube 2>/dev/null
    fi

    if [ -f "${SONAR_LINK}/bin/linux-x86-64/sonar.sh" ]; then
        su - sonar -c "${SONAR_LINK}/bin/linux-x86-64/sonar.sh stop" 2>/dev/null
        sleep 10
    fi

    echo "Checking old SonarQube processes..."

    SONAR_PIDS=$(ps -ef | grep -i sonarqube | grep -v grep | awk '{print $2}')

    if [ ! -z "$SONAR_PIDS" ]; then
        echo "Killing old SonarQube processes: $SONAR_PIDS"
        kill -9 $SONAR_PIDS
    else
        echo "No old SonarQube process found"
    fi

    echo "Checking port 9000..."

    PORT_9000_PID=$(lsof -ti:9000)

    if [ ! -z "$PORT_9000_PID" ]; then
        echo "Port 9000 already in use. Killing process $PORT_9000_PID"
        kill -9 $PORT_9000_PID
    else
        echo "Port 9000 is free"
    fi

    echo "Removing old SonarQube files..."

    rm -rf /opt/sonarqube*
    rm -f /etc/systemd/system/sonarqube.service

    echo "Creating sonar user..."

    if id sonar &>/dev/null; then
        echo "sonar user already exists"
    else
        useradd sonar
        echo "sonar:sonar" | chpasswd
        echo "sonar user created successfully"
    fi

    echo "Installing SonarQube..."

    cd /opt || exit

    wget https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}

    if [ -f "/opt/${SONAR_ZIP}" ]; then

        unzip -q ${SONAR_ZIP}

        ln -s ${SONAR_DIR} ${SONAR_LINK}

        chown -R sonar:sonar ${SONAR_DIR}
        chown -h sonar:sonar ${SONAR_LINK}

        if [ -d "$SONAR_DIR" ]; then
            SONAR_INSTALL_STATUS="SonarQube installed successfully - Version: ${SONAR_VERSION}"
            echo "$SONAR_INSTALL_STATUS"
        else
            SONAR_INSTALL_STATUS="SonarQube installation failed"
            echo "$SONAR_INSTALL_STATUS"
        fi

        echo "Creating SonarQube systemd service..."

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
LimitNOFILE=65536
LimitNPROC=4096
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload

        echo "Enabling SonarQube service..."
        systemctl enable sonarqube

        echo "Starting SonarQube service..."
        systemctl start sonarqube

        echo "Waiting for SonarQube to start..."

        SONAR_STARTED="no"

        for i in {1..24}
        do
            sleep 10

            if curl -s "http://localhost:9000" | grep -qi "sonar"; then
                SONAR_STARTED="yes"
                break
            fi

            if lsof -i:9000 >/dev/null 2>&1; then
                SONAR_STARTED="yes"
                break
            fi

            echo "Still waiting for SonarQube... $((i*10)) seconds"
        done

        if [ "$SONAR_STARTED" == "yes" ]; then
            SONAR_START_STATUS="SonarQube started successfully"
            echo "$SONAR_START_STATUS"
        else
            SONAR_START_STATUS="SonarQube failed to start"
            echo "$SONAR_START_STATUS"

            echo "SonarQube service status:"
            systemctl status sonarqube --no-pager

            echo "SonarQube logs:"
            echo "---------------- sonar.log ----------------"
            tail -50 ${SONAR_LINK}/logs/sonar.log 2>/dev/null

            echo "---------------- web.log ----------------"
            tail -50 ${SONAR_LINK}/logs/web.log 2>/dev/null

            echo "---------------- es.log ----------------"
            tail -50 ${SONAR_LINK}/logs/es.log 2>/dev/null
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
# Apache HTTPD Installation
# ------------------------------------------------

if ask_install "Apache HTTPD"; then

    echo "Stopping old Apache HTTPD if running..."
    systemctl stop httpd 2>/dev/null
    systemctl disable httpd 2>/dev/null

    echo "Removing old Apache HTTPD..."
    yum remove httpd -y

    echo "Installing Apache HTTPD..."
    yum install httpd -y

    if [ $? -eq 0 ]; then

        HTTPD_INSTALL_STATUS="Apache HTTPD installed successfully - Version: $(httpd -version 2>&1 | head -1 | awk '{print $3}')"
        echo "$HTTPD_INSTALL_STATUS"

        systemctl daemon-reload
        systemctl enable httpd
        systemctl start httpd

        sleep 5

        if systemctl is-active --quiet httpd; then
            HTTPD_START_STATUS="Apache HTTPD started successfully"
            echo "$HTTPD_START_STATUS"
        else
            HTTPD_START_STATUS="Apache HTTPD failed to start"
            echo "$HTTPD_START_STATUS"

            echo "Apache HTTPD service status:"
            systemctl status httpd --no-pager

            echo "Apache HTTPD logs:"
            tail -50 /var/log/httpd/error_log 2>/dev/null
        fi

    else
        HTTPD_INSTALL_STATUS="Apache HTTPD installation failed"
        echo "$HTTPD_INSTALL_STATUS"
    fi

else
    echo "Skipping Apache HTTPD installation..."
fi

echo "-------------------------------------------"

# ------------------------------------------------
# Apache Tomcat Installation
# Tomcat 10.1.x - Compatible with JDK 17 (Java 11+)
# Installed at /opt/apache-tomcat-<version> with symlink /opt/tomcat
# ------------------------------------------------

if ask_install "Apache Tomcat ${TOMCAT_VERSION} (JDK 17 compatible)"; then

    echo "Stopping old Tomcat if running..."

    if [ -f "${TOMCAT_LINK}/bin/shutdown.sh" ]; then
        sh ${TOMCAT_LINK}/bin/shutdown.sh 2>/dev/null
        sleep 5
    fi

    echo "Checking port 9090..."

    PORT_9090_PID=$(lsof -ti:9090)

    if [ ! -z "$PORT_9090_PID" ]; then
        echo "Port 9090 already in use. Killing process $PORT_9090_PID"
        kill -9 $PORT_9090_PID
    else
        echo "Port 9090 is free"
    fi

    echo "Removing old Tomcat files..."
    rm -rf /opt/apache-tomcat-*
    rm -rf ${TOMCAT_LINK}
    rm -f /opt/${TOMCAT_TAR}

    echo "Creating tomcat user..."

    if id tomcat &>/dev/null; then
        echo "tomcat user already exists"
    else
        useradd -r -m -U -d ${TOMCAT_LINK} -s /bin/false tomcat
        echo "tomcat user created successfully"
    fi

    echo "Downloading Apache Tomcat ${TOMCAT_VERSION}..."

    cd /opt || exit

    wget ${TOMCAT_URL}

    if [ -f "/opt/${TOMCAT_TAR}" ]; then

        echo "Extracting Tomcat..."
        tar -xzf ${TOMCAT_TAR}

        # Create symlink /opt/tomcat -> /opt/apache-tomcat-<version>
        ln -s ${TOMCAT_INSTALL_DIR} ${TOMCAT_LINK}

        echo "Tomcat installed at: ${TOMCAT_INSTALL_DIR}"
        echo "Symlink created   : ${TOMCAT_LINK} -> ${TOMCAT_INSTALL_DIR}"

        # -----------------------------------------------------------
        # Configure tomcat-users.xml
        # Update username=admin, password=admin, role=manager-gui
        # -----------------------------------------------------------

        echo "Configuring Tomcat users (admin/admin with manager-gui role)..."

        cat > ${TOMCAT_LINK}/conf/tomcat-users.xml <<'TOMCATUSERS'
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">

  <role rolename="manager-gui"/>
  <user username="admin" password="admin" roles="manager-gui"/>

</tomcat-users>
TOMCATUSERS

        echo "tomcat-users.xml updated with admin/admin and manager-gui role."

        # -----------------------------------------------------------
        # Comment line 21 in Manager app context.xml
        # Line 21 contains the RemoteAddrValve that restricts access
        # to localhost only. Commenting it out allows remote access.
        # -----------------------------------------------------------

        MANAGER_CONTEXT="${TOMCAT_LINK}/webapps/manager/META-INF/context.xml"

        if [ -f "$MANAGER_CONTEXT" ]; then

            echo "Commenting out line 21 in manager context.xml (RemoteAddrValve restriction)..."

            # Create a Python script to comment out exactly line 21
            python3 - <<PYEOF
with open("${MANAGER_CONTEXT}", "r") as f:
    lines = f.readlines()

# Comment out line 21 (index 20, 0-based)
if len(lines) >= 21:
    line = lines[20]
    # Only comment if not already commented
    stripped = line.strip()
    if not stripped.startswith("<!--"):
        lines[20] = "<!--" + line.rstrip() + "-->\n"
        print(f"Line 21 commented out: {lines[20].strip()}")
    else:
        print("Line 21 already commented out.")
else:
    print(f"Warning: file has only {len(lines)} lines, line 21 not found.")

with open("${MANAGER_CONTEXT}", "w") as f:
    f.writelines(lines)

print("manager/META-INF/context.xml updated successfully.")
PYEOF

        else
            echo "Warning: Manager context.xml not found at $MANAGER_CONTEXT"
            echo "It may be created on first Tomcat start. Skipping this step."
        fi

        # -----------------------------------------------------------
        # Update server.xml — change connector port to 9090
        # -----------------------------------------------------------

        SERVER_XML="${TOMCAT_LINK}/conf/server.xml"

        echo "Updating Tomcat HTTP connector port to 9090 in server.xml..."

        # Replace the default HTTP/1.1 connector port 8080 with 9090
        sed -i 's/port="8080"/port="9090"/' ${SERVER_XML}

        if grep -q 'port="9090"' ${SERVER_XML}; then
            echo "server.xml updated: HTTP connector port set to 9090."
        else
            echo "Warning: Could not confirm port change in server.xml. Please verify manually."
        fi

        # -----------------------------------------------------------
        # Set ownership and permissions
        # -----------------------------------------------------------

        chown -R tomcat:tomcat ${TOMCAT_INSTALL_DIR}
        chown -h tomcat:tomcat ${TOMCAT_LINK}
        chmod +x ${TOMCAT_LINK}/bin/*.sh

        # -----------------------------------------------------------
        # Start Tomcat
        # -----------------------------------------------------------

        echo "Starting Apache Tomcat..."
        su - tomcat -s /bin/bash -c "${TOMCAT_LINK}/bin/startup.sh" 2>/dev/null || \
            sh ${TOMCAT_LINK}/bin/startup.sh

        echo "Waiting for Tomcat to start on port 9090..."

        TOMCAT_STARTED="no"

        for i in {1..12}
        do
            sleep 5

            if lsof -i:9090 >/dev/null 2>&1; then
                TOMCAT_STARTED="yes"
                break
            fi

            if curl -s "http://localhost:9090" | grep -qi "tomcat\|apache"; then
                TOMCAT_STARTED="yes"
                break
            fi

            echo "Still waiting for Tomcat... $((i*5)) seconds"
        done

        if [ "$TOMCAT_STARTED" == "yes" ]; then
            TOMCAT_INSTALL_STATUS="Apache Tomcat ${TOMCAT_VERSION} installed successfully at ${TOMCAT_INSTALL_DIR}"
            TOMCAT_START_STATUS="Tomcat started successfully on port 9090"
            echo "$TOMCAT_INSTALL_STATUS"
            echo "$TOMCAT_START_STATUS"
        else
            TOMCAT_INSTALL_STATUS="Apache Tomcat ${TOMCAT_VERSION} installed at ${TOMCAT_INSTALL_DIR}"
            TOMCAT_START_STATUS="Tomcat failed to start (check logs)"
            echo "$TOMCAT_START_STATUS"

            echo "Tomcat logs (catalina.out):"
            tail -50 ${TOMCAT_LINK}/logs/catalina.out 2>/dev/null
        fi

    else
        TOMCAT_INSTALL_STATUS="Tomcat download failed"
        echo "$TOMCAT_INSTALL_STATUS"
    fi

else
    echo "Skipping Apache Tomcat installation..."
fi

echo "-------------------------------------------"
echo "Installation Completed"
echo "-------------------------------------------"

echo ""
echo "============= FINAL STATUS ============="

echo "EC2 Public IP: ${PUBLIC_IP}"

echo "$JAVA_STATUS"
echo "$GIT_STATUS"
echo "$MAVEN_STATUS"

echo "$JENKINS_INSTALL_STATUS"
echo "$JENKINS_START_STATUS"

if [[ "$JENKINS_START_STATUS" == "Jenkins started successfully" ]]; then
    echo "Jenkins URL: http://${PUBLIC_IP}:8080"
    echo "Jenkins password location: /var/lib/jenkins/secrets/initialAdminPassword"
fi

echo "$DOCKER_INSTALL_STATUS"
echo "$DOCKER_START_STATUS"

echo "$SONAR_INSTALL_STATUS"
echo "$SONAR_START_STATUS"

if [[ "$SONAR_START_STATUS" == "SonarQube started successfully" ]]; then
    echo "SonarQube URL: http://${PUBLIC_IP}:9000"
    echo "SonarQube username: admin"
    echo "SonarQube password: admin"
    echo "Linux sonar user: sonar"
    echo "Linux sonar user password: sonar"
fi

echo "$HTTPD_INSTALL_STATUS"
echo "$HTTPD_START_STATUS"

if [[ "$HTTPD_START_STATUS" == "Apache HTTPD started successfully" ]]; then
    echo "Apache HTTPD URL: http://${PUBLIC_IP}:80"
fi

echo "$TOMCAT_INSTALL_STATUS"
echo "$TOMCAT_START_STATUS"

if [[ "$TOMCAT_START_STATUS" == *"successfully"* ]]; then
    echo "Tomcat URL         : http://${PUBLIC_IP}:9090"
    echo "Tomcat Manager URL : http://${PUBLIC_IP}:9090/manager/html"
    echo "Tomcat username    : admin"
    echo "Tomcat password    : admin"
    echo "Tomcat install dir : ${TOMCAT_INSTALL_DIR}"
    echo "Tomcat symlink     : ${TOMCAT_LINK} -> ${TOMCAT_INSTALL_DIR}"
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

echo "==================================================="
