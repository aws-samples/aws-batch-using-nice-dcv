FROM amazonlinux:latest

# Prepare systemd for container execution
ENV container docker

# Install tools
RUN yum -y install tar sudo less vim lsof firewalld net-tools pciutils \
                   file wget kmod xz-utils ca-certificates binutils kbd \
                   python3-pip bind-utils

# Install awscli and configure region only
# Note: required to run aws ssm command
RUN pip3 install awscli 2>/dev/null && \
    mkdir $HOME/.aws && \
    echo "[default]" > $HOME/.aws/config && \
    echo "region = eu-west-1" >> $HOME/.aws/config && \
    chmod 600 $HOME/.aws/config

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

# Add test user accounts (sample)
RUN adduser user001 -u 1001 && \
    echo "user001:$(aws secretsmanager get-secret-value --secret-id \
              Run_DCV_in_Batch --query SecretString  --output text | \
              jq -r .user001)" | chpasswd

# Install Nvidia Driver, configure Xorg, install NICE DCV server
RUN wget http://us.download.nvidia.com/tesla/418.87/NVIDIA-Linux-x86_64-418.87.00.run -O /tmp/NVIDIA-installer.run && \
    bash /tmp/NVIDIA-installer.run --accept-license \
                              --no-runlevel-check \
                              --no-questions \
                              --no-backup \
                              --ui=none \
                              --no-kernel-module \
                              --no-nouveau-check \
                              --install-libglvnd \
                              --no-nvidia-modprobe \
                              --no-kernel-module-source && rm -f /tmp/NVIDIA-installer.run && \
    nvidia-xconfig --preserve-busid && \
    rpm --import https://s3-eu-west-1.amazonaws.com/nice-dcv-publish/NICE-GPG-KEY && \
    curl https://d1uj6qtbmh3dt5.cloudfront.net/2020.0/Servers/nice-dcv-2020.0-8428-el7.tgz \
    --output nice-dcv-2020.0-8428-el7.tgz && tar zxvf nice-dcv-2020.0-8428-el7.tgz && \
    yum -y install \
    nice-dcv-2020.0-8428-el7/nice-dcv-gl-2020.0.759-1.el7.i686.rpm \
    nice-dcv-2020.0-8428-el7/nice-dcv-gltest-2020.0.229-1.el7.x86_64.rpm \
    nice-dcv-2020.0-8428-el7/nice-dcv-gl-2020.0.759-1.el7.x86_64.rpm \
    nice-dcv-2020.0-8428-el7/nice-dcv-server-2020.0.8428-1.el7.x86_64.rpm \
    nice-dcv-2020.0-8428-el7/nice-xdcv-2020.0.296-1.el7.x86_64.rpm

# Define the dcvserver.service and enable graphical target
RUN echo "[Unit]" > /usr/lib/systemd/system/dcvserver.service && \
    echo "Description=NICE DCV server daemon" >> /usr/lib/systemd/system/dcvserver.service && \
    echo >> /usr/lib/systemd/system/dcvserver.service && \
    echo "[Service]" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "PermissionsStartOnly=true" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "ExecStartPre=-/sbin/modprobe eveusb" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "ExecStart=/usr/bin/dcvserver -d --service" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "Restart=always" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "BusName=com.nicesoftware.DcvServer" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "User=dcv" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "Group=dcv" >> /usr/lib/systemd/system/dcvserver.service && \
    echo >> /usr/lib/systemd/system/dcvserver.service && \
    echo "[Install]" >> /usr/lib/systemd/system/dcvserver.service && \
    echo "WantedBy=multi-user.target" >> /usr/lib/systemd/system/dcvserver.service && \
    systemctl set-default graphical.target

# Open required port on firewall, start a DCV session for user
RUN echo "firewall-cmd --zone=public --permanent --add-port=8443/tcp" >> "/etc/rc.local" && \
    echo "firewall-cmd --reload" >> "/etc/rc.local" && \
    echo "/bin/dcv create-session --owner user001 --user user001 user001session" >> /etc/rc.local && \
    chmod +x "/etc/rc.local"

# Disable audit, configure Xorg, start DCV server
RUN echo '#!/bin/bash' > /tmp/run_script.sh && \
    echo "systemctl enable dcvserver"  >> /tmp/run_script.sh && \
    echo "exec /usr/sbin/init" >> /tmp/run_script.sh && \
    chmod a+rx /tmp/run_script.sh

EXPOSE 8443
CMD ["/tmp/run_script.sh"]
