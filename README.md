# kong-packages
Commands to install the repos are

On Red Hat based systems:
rpm -ivh https://kong-packages.s3.amazonaws.com/amzn/noarch/kong-repo-1-0.1.noarch.rpm

On Debian based systems:
echo "deb http://kong-packages.s3.amazonaws.com/ trusty main" >> /etc/apt/sources.list
and then run 
apt-get update
