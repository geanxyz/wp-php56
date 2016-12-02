FROM rhscl/s2i-base-rhel7:1

# This image provides an Apache+PHP environment for running PHP
# applications.

EXPOSE 8080

ENV PHP_VERSION=5.6 \
    PATH=$PATH:/opt/rh/rh-php56/root/usr/bin

LABEL io.k8s.description="Platform for building and running PHP 5.6 applications" \
      io.k8s.display-name="Apache 2.4 with PHP 5.6" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,php,php56,rh-php56"

# Labels consumed by Red Hat build service
LABEL Name="rhscl/php-56-rhel7" \
      BZComponent="rh-php56-docker" \
      Version="5.6" \
      Release="14.3" \
      Architecture="x86_64"

# Install Apache httpd and PHP
#RUN yum-config-manager --enable rhel-server-rhscl-7-rpms && \
#    yum-config-manager --enable rhel-7-server-optional-rpms && \
RUN yum install -y yum-utils gettext hostname && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum-config-manager --enable rhel-7-server-optional-rpms && \
    yum-config-manager --enable rhel-7-server-ose-3.0-rpms && \
    yum install -y --setopt=tsflags=nodocs nss_wrapper && \
    yum install -y --setopt=tsflags=nodocs bind-utils && \
    yum repolist && \
    yum list |grep -i php && \
    INSTALL_PKGS="rh-php56 rh-php56-php rh-php56-php-mysqlnd rh-php56-php-pgsql rh-php56-php-bcmath \
                  rh-php56-php-gd rh-php56-php-intl rh-php56-php-ldap rh-php56-php-mbstring rh-php56-php-pdo \
                  rh-php56-php-pecl-memcache rh-php56-php-process rh-php56-php-soap rh-php56-php-opcache rh-php56-php-xml \
                  rh-php56-php-pecl-xdebug" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Each language image can have 'contrib' a directory with extra files needed to
# run and build the applications.
COPY ./contrib/ /opt/app-root

# In order to drop the root user, we have to make some directories world
# writeable as OpenShift default security model is to run the container under
# random UID.
RUN sed -i -f /opt/app-root/etc/httpdconf.sed /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    sed -i '/php_value session.save_path/d' /opt/rh/httpd24/root/etc/httpd/conf.d/rh-php56-php.conf && \
    head -n151 /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf | tail -n1 | grep "AllowOverride All" || exit && \
    echo "IncludeOptional /opt/app-root/etc/conf.d/*.conf" >> /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    mkdir /tmp/sessions && \
    chmod -R a+rwx /etc/opt/rh/rh-php56 && \
    chmod -R a+rwx /opt/rh/httpd24/root/var/run/httpd && \
    chmod -R a+rwx /tmp/sessions && \
    chown -R 1001:0 /opt/app-root /tmp/sessions

USER 1001

# Install Wordpress
RUN curl https://wordpress.org/latest.tar.gz -o /opt/app-root/src/latest.tar.gz && \
    cd /opt/app-root/src/ && tar xvf latest.tar.gz && rm latest.tar.gz && \
    mv /opt/app-root/src/wordpress /opt/app-root/html && \
    chmod -R a+rwx /opt/app-root/html && \
    chown -R 1001:0 /opt/app-root/html && \
    ls -l /opt/app-root/ && \
    ls -l /opt/app-rppt/html

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/run
