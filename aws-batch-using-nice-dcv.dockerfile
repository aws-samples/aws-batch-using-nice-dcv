FROM amazonlinux:2 as dcv

# Prepare the container to run systemd inside
ENV container docker

ARG AWS_REGION=eu-west-1

# Install tools
RUN yum -y install tar sudo less vim lsof firewalld net-tools pciutils \
                   file wget kmod xz-utils ca-certificates binutils kbd \
                   python3-pip bind-utils jq bc

# Install awscli and configure region only
# Note: required to run aws ssm command
RUN pip3 install awscli 2>/dev/null \
 && mkdir $HOME/.aws \
 && echo "[default]" > $HOME/.aws/config \
 && echo "region =  ${AWS_REGION}" >> $HOME/.aws/config \
 && chmod 600 $HOME/.aws/config

# Install X server and GNOME desktop
RUN yum -y install glx-utils mesa-dri-drivers xorg-x11-server-Xorg \
                   xorg-x11-utils xorg-x11-xauth xorg-x11-xinit xvattr \
                   xorg*fonts* xterm libXvMC mesa-libxatracker freeglut \
                   gnome-desktop3 gnome-terminal gnome-system-log \
                   gnome-system-monitor nautilus evince gnome-color-manager \
                   gnome-font-viewer gnome-shell gnome-calculator gedit gdm \
                   metacity gnome-session gnome-classic-session \
                   gnome-session-xsession gnu-free-fonts-common \
                   gnu-free-mono-fonts gnu-free-sans-fonts \
                   gnu-free-serif-fonts desktop-backgrounds-gnome

# Install Nvidia Driver
RUN wget -q https://us.download.nvidia.com/tesla/535.129.03/NVIDIA-Linux-x86_64-535.129.03.run -O /tmp/NVIDIA-installer.run \
 && bash /tmp/NVIDIA-installer.run --accept-license \
                              --no-runlevel-check \
                              --no-questions \
                              --no-backup \
                              --ui=none \
                              --no-kernel-module \
                              --no-nouveau-check \
                              --install-libglvnd \
                              --no-nvidia-modprobe \
                              --no-kernel-module-source \
 && rm -f /tmp/NVIDIA-installer.run \
 && nvidia-xconfig --preserve-busid
# Configure Xorg, install NICE DCV server
RUN rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY \
 && mkdir -p /tmp/dcv-inst \
 && cd /tmp/dcv-inst \
 && wget -qO- https://d1uj6qtbmh3dt5.cloudfront.net/2023.1/Servers/nice-dcv-2023.1-16388-el7-x86_64.tgz |tar xfz - --strip-components=1 \
 && yum -y install \
    nice-dcv-server-2023.1.16388-1.el7.x86_64.rpm \
    nice-dcv-simple-external-authenticator-2023.1.228-1.el7.x86_64.rpm \
    nice-dcv-web-viewer-2023.1.16388-1.el7.x86_64.rpm \
    nice-xdcv-2023.1.565-1.el7.x86_64.rpm \
    nice-dcv-gl-2023.1.1047-1.el7.x86_64.rpm \
    nice-dcv-gltest-2023.1.325-1.el7.x86_64.rpm \
 && rm -rf /tmp/dcv-inst

# Define the dcvserver.service
COPY dcvserver.service /usr/lib/systemd/system/dcvserver.service

# Start DCV server and initialize level 5
COPY run_script.sh /usr/local/bin/

# Send Notification message DCV session ready
COPY send_dcvsessionready_notification.sh /usr/local/bin/

# Open required port on firewall, create test user, send notification, start DCV session for the user
COPY startup_script.sh /usr/local/bin

# Append the startup script to be executed at the end of initialization and fix permissions
RUN echo "/usr/local/bin/startup_script.sh" >> "/etc/rc.local" \
 && chmod +x "/etc/rc.local" "/usr/local/bin/run_script.sh" \
             "/usr/local/bin/send_dcvsessionready_notification.sh" \
             "/usr/local/bin/startup_script.sh"

EXPOSE 8443

CMD ["/usr/local/bin/run_script.sh"]

FROM dcv
# Install Paraview with requirements
RUN yum -y install libgomp \
 && wget -q -O ParaView-5.8.0-MPI-Linux-Python3.7-64bit.tar.gz "https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.8&type=binary&os=Linux&downloadFile=ParaView-5.8.0-MPI-Linux-Python3.7-64bit.tar.gz" \
 && mkdir -p /opt/paraview \
 && tar zxf  ParaView-5.8.0-MPI-Linux-Python3.7-64bit.tar.gz --directory /opt/paraview/ --strip 1 \
 && rm -f ParaView-5.8.0-MPI-Linux-Python3.7-64bit.tar.gz
