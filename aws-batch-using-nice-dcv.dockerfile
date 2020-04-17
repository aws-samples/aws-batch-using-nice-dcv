FROM amazonlinux:latest

# Prepare systemd for container execution
ENV container docker

# Install tools
RUN yum -y install tar sudo less vim lsof firewalld net-tools pciutils \
                   file wget kmod xz-utils ca-certificates binutils kbd \
                   python3-pip jq

# Install awscli and configure region only
# Note: required to run aws ssm command
RUN pip3 install awscli 2>/dev/null
RUN mkdir $HOME/.aws
RUN echo "[default]" > $HOME/.aws/config
RUN echo "region = eu-west-1" >> $HOME/.aws/config
RUN chmod 600 $HOME/.aws/config

# Install X server and GNOME desktop
RUN yum -y install glx-utils mesa-dri-drivers xorg-x11-server-Xorg \
                   xorg-x11-utils xorg-x11-xauth xorg-x11-xinit xvattr \
                   xorg*fonts* xterm libXvMC mesa-libxatracker freeglut \
                   libgomp

RUN yum -y install gnome-desktop3 gnome-terminal gnome-system-log \
                   gnome-system-monitor nautilus evince gnome-color-manager \
                   gnome-font-viewer gnome-shell gnome-calculator gedit gdm \
                   metacity gnome-session gnome-classic-session \
                   gnome-session-xsession gnu-free-fonts-common \
                   gnu-free-mono-fonts gnu-free-sans-fonts \
                   gnu-free-serif-fonts desktop-backgrounds-gnome

# Add test user accounts (sample)
RUN adduser user001 -u 1001 -G wheel
RUN adduser user002 -u 1002 -G wheel
RUN echo "user001:$(aws secretsmanager get-secret-value --secret-id \
              Run_DCV_in_Batch --query SecretString  --output text | \
              jq -r .user001)" | chpasswd
RUN echo "user002:$(aws secretsmanager get-secret-value --secret-id \
              Run_DCV_in_Batch --query SecretString  --output text | \
              jq -r .user002)" | chpasswd

# Install NvidiaDriver
RUN wget http://us.download.nvidia.com/tesla/418.87/NVIDIA-Linux-x86_64-418.87.00.run \
    -O /tmp/NVIDIA-installer.run
RUN bash /tmp/NVIDIA-installer.run --accept-license \
                              --no-runlevel-check \
                              --no-questions \
                              --no-backup \
                              --ui=none \
                              --no-kernel-module \
                              --no-nouveau-check \
                              --install-libglvnd \
                              --no-nvidia-modprobe \
                              --no-kernel-module-source && \
                              rm -f /tmp/NVIDIA-installer.run

RUN nvidia-xconfig --use-display-device="None"  --preserve-busid

# Install DCV server
RUN rpm --import https://s3-eu-west-1.amazonaws.com/nice-dcv-publish/NICE-GPG-KEY

RUN curl https://d1uj6qtbmh3dt5.cloudfront.net/2019.1/Servers/nice-dcv-2019.1-7644-el7.tgz \
    --output nice-dcv-2019.1-7644-el7.tgz
RUN tar zxvf nice-dcv-2019.1-7644-el7.tgz
RUN yum -y install \
    nice-dcv-2019.1-7644-el7/nice-dcv-server-2019.1.7644-1.el7.x86_64.rpm \
    nice-dcv-2019.1-7644-el7/nice-xdcv-2019.1.226-1.el7.x86_64.rpm \
    nice-dcv-2019.1-7644-el7/nice-dcv-gl-2019.1.544-1.el7.x86_64.rpm \
    nice-dcv-2019.1-7644-el7/nice-dcv-gltest-2019.1.220-1.el7.x86_64.rpm

# Define the dcvserver.service
RUN echo "[Unit]" > /usr/lib/systemd/system/dcvserver.service
RUN echo "Description=NICE DCV server daemon" >> /usr/lib/systemd/system/dcvserver.service
RUN echo >> /usr/lib/systemd/system/dcvserver.service
RUN echo "[Service]" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "PermissionsStartOnly=true" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "ExecStartPre=-/sbin/modprobe eveusb" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "ExecStart=/usr/bin/dcvserver -d --service" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "Restart=always" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "BusName=com.nicesoftware.DcvServer" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "User=dcv" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "Group=dcv" >> /usr/lib/systemd/system/dcvserver.service
RUN echo >> /usr/lib/systemd/system/dcvserver.service
RUN echo "[Install]" >> /usr/lib/systemd/system/dcvserver.service
RUN echo "WantedBy=multi-user.target" >> /usr/lib/systemd/system/dcvserver.service

# Define the service to automatically start the dcv sessions for test users
RUN echo "[Unit]" > /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "Description=NICE DCV tests sessions creation" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "After=graphical.target" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "[Service]" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "PermissionsStartOnly=true" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo 'ExecStart=/bin/bash --login -c "/bin/dcv create-session --owner user001 --user user001 user001session; /bin/dcv create-session --owner user002 --user user002 user002session"' >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "Restart=no" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "User=root" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "Group=root" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "[Install]" >> /usr/lib/systemd/system/dcvcreatesessions.service
RUN echo "WantedBy=graphical.target" >> /usr/lib/systemd/system/dcvcreatesessions.service

# Enable graphical.target
RUN systemctl set-default graphical.target

# Open required port on firewall and audit, start DCV server
RUN echo "firewall-cmd --zone=public --permanent --add-port=8443/tcp" >> "/etc/rc.local"
RUN echo "firewall-cmd --reload" >> "/etc/rc.local"
RUN chmod +x "/etc/rc.local"

# Disable audit, configure Xorg, start DCV server
RUN echo '#!/bin/bash' > /tmp/run_script.sh
RUN echo "systemctl disable auditd.service" >> /tmp/run_script.sh
RUN echo '/bin/nvidia-xconfig --enable-all-gpus  --use-display-device="None"  --preserve-busid' >> /tmp/run_script.sh
RUN echo "systemctl enable dcvserver"  >> /tmp/run_script.sh
RUN echo "systemctl start dcvserver"  >> /tmp/run_script.sh
RUN echo "systemctl enable dcvcreatesessions" >> /tmp/run_script.sh
RUN echo "exec /usr/sbin/init 5" >> /tmp/run_script.sh
RUN chmod a+rx /tmp/run_script.sh

EXPOSE 8443

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/tmp/run_script.sh"]