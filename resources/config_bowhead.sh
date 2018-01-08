#! /bin/bash

echo "-----------------------------------------------------------------"
echo "------ IN ALPINE CONTAINER, LETS GET SET UP...."
echo "-----------------------------------------------------------------"

#
# install and configure bowhead
# docker build -t bowhead docker/ && docker run --name=bowhead -p 127.0.0.1:8080:8080 bowhead
#
echo "-----------------------------------------------------------------"
echo "------ enabling trader extension for PHP7 ";
echo "-----------------------------------------------------------------"
echo "extension=trader.so" >> /etc/php/php.ini
echo "... TESTING for trader, your should see it below this line.";
php -i | grep rade
echo "...";
echo "-----------------------------------------------------------------"
echo "------ creating mysql group and starting mysql  ";
echo "-----------------------------------------------------------------"
addgroup mysql mysql
mysql_install_db --user=mysql > /dev/null
mysqld_safe &
echo "-----------------------------------------------------------------"
echo "------ mysql starting..  lets give it a second";
echo "-----------------------------------------------------------------"
sleep 5
mysqladmin -u root create bowhead
mysqladmin -u root password password
sleep 1

cd /var/www/
git clone https://github.com/joeldg/bowhead.git
cd bowhead

# Laravel needs these to be writable
chmod 777 storage/logs
chmod 777 bootstrap/cache
chmod -R 777 /var/www/bowhead/storage/

pip install python-env

echo "-----------------------------------------------------------------"
echo "------ mariadb specific change from localhost to 127.0.0.1"
echo "-----------------------------------------------------------------"
# seriously, how is this still an issue in 2018?
cp .env.example .env
cp .env.example .env
sed 's/localhost/127.0.0.1/g' .env > out
mv out .env

echo "-----------------------------------------------------------------"
echo "------ THIS COULD TAKE A LITTLE WHILE ..... please wait. --"
echo "-----------------------------------------------------------------"
composer update

ln -s /var/www/bowhead/public /var/www/html/bowhead

mkfifo quotes

echo "-----------------------------------------------------------------"
echo "------  CREATING THE DATABASE AND SEEDING INITIAL DATA"
echo "-----------------------------------------------------------------"
php artisan key:generate
php artisan migrate
php artisan db:seed

echo "-----------------------------------------------------------------"
echo "------  setting up crontab"
echo "-----------------------------------------------------------------"
echo "* * * * * `which php` `pwd`/artisan schedule:run >> /dev/null 2>&1" > /tmp/tmpcron
crontab '/tmp/tmpcron'
mysql -u root -ppassword -D bowhead < app/Scripts/DBdump.sql

#php artisan bowhead:example_usage
#/usr/bin/crontab /usr/src/crontab.tmp
#/usr/sbin/service cron start

pkill -HUP nginx
pkill -HUP php-fpm
rm -rf /var/cache/apk/*

ip=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+----- READ ME:                                                     -----+"
echo "+------------------------------------------------------------------------+"
echo "+----- Bowhead is now set up:                                       -----+"
echo "+----- USE: 'docker exec -it bowhead /bin/bash' to log into this    -----+"
echo "+-----      container                                               -----+"
echo "+-----                                                              -----+"
echo "+-----      SETUP LOCATED AT:  http://$ip:8080/setup                -----+"
echo "+-----                                                              -----+"
echo "+-----  use: 'php artisan bowhead:example_usage' for testing .env   -----+"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

sleep 5000

# fire up supervisord
/usr/bin/supervisord -c /etc/supervisor/conf.d/bowhead.conf
