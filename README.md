# kong-packages
Commands to install the repos are

On Red Hat based systems:

rpm -ivh https://kong-packages.s3.amazonaws.com/amzn/noarch/kong-repo-1-0.1.noarch.rpm

yum -y install kong

To manually add the yum repo, create kong-repo.repo in /etc/yum.repos.d/ and add the following content:

[kong-repo]
name=name=Extra Packages from Kong RPM Repository - 
baseurl=https://kong-packages.s3.amazonaws.com/amzn/noarch/
enabled=1
gpgcheck=0

On Debian based systems:

echo "deb http://kong-packages.s3.amazonaws.com/ trusty main" >> /etc/apt/sources.list

and then run 

apt-get update && apt-get -y install kong
