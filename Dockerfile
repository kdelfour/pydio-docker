# ------------------------------------------------------------------------------
# Based on a work at https://github.com/docker/docker.
# ------------------------------------------------------------------------------
# Pull base image.
FROM kdelfour/supervisor-docker
MAINTAINER Kevin Delfour <kevin@delfour.eu>

# ------------------------------------------------------------------------------
# Install Base
RUN apt-get update
RUN apt-get install -yq wget unzip nginx fontconfig-config fonts-dejavu-core \
    php5-fpm php5-common php5-json php5-cli php5-common php5-mysql\
    php5-gd php5-json php5-mcrypt php5-readline psmisc ssl-cert \
    ufw php-pear libgd-tools libmcrypt-dev mcrypt mysql-server mysql-client

# ------------------------------------------------------------------------------
# Configure mysql
RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
RUN service mysql start && \
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS pydio;" && \
    mysql -uroot -e "CREATE USER 'pydio'@'localhost' IDENTIFIED BY 'pydio';" && \
    mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'pydio'@'localhost' WITH GRANT OPTION;" && \
    mysql -uroot -e "FLUSH PRIVILEGES;"
    
# ------------------------------------------------------------------------------
# Configure php-fpm
RUN sed -i -e "s/output_buffering\s*=\s*4096/output_buffering = Off/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1G/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1G/g" /etc/php5/fpm/php.ini
RUN php5enmod mcrypt

# ------------------------------------------------------------------------------
# Configure nginx
RUN mkdir /var/www
RUN chown www-data:www-data /var/www
RUN rm /etc/nginx/sites-enabled/*
RUN rm /etc/nginx/sites-available/*
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
ADD conf/pydio /etc/nginx/sites-enabled/
RUN mkdir /etc/nginx/ssl
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj '/CN=localhost/O=My Company Name LTD./C=US'

# ------------------------------------------------------------------------------
# Configure services
RUN update-rc.d nginx defaults
RUN update-rc.d php5-fpm defaults
RUN update-rc.d mysql defaults

# ------------------------------------------------------------------------------
# Install Pydio
ENV PYDIO_VERSION 6.4.1
WORKDIR /var/www
RUN wget http://downloads.sourceforge.net/project/ajaxplorer/pydio/stable-channel/${PYDIO_VERSION}/pydio-core-${PYDIO_VERSION}.zip
RUN unzip pydio-core-${PYDIO_VERSION}.zip
RUN mv pydio-core-${PYDIO_VERSION} pydio-core
RUN chown -R www-data:www-data /var/www/pydio-core
RUN chmod -R 770 /var/www/pydio-core
RUN chmod 777  /var/www/pydio-core/data/files/
RUN chmod 777  /var/www/pydio-core/data/personal/

WORKDIR /
RUN ln -s /var/www/pydio-core/data pydio-data 
# ------------------------------------------------------------------------------
# Expose ports.
EXPOSE 80
EXPOSE 443

# ------------------------------------------------------------------------------
# Expose volumes
VOLUME /pydio-data/files
VOLUME /pydio-data/personal

# ------------------------------------------------------------------------------
# Add supervisord conf
ADD conf/startup.conf /etc/supervisor/conf.d/

# Start supervisor, define default command.
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
