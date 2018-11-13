#!/bin/bash

FTP_URL="plugins.gugyclan.eu/calladmin/"

find plugins -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"{} \;
find scripting -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"{} \;
find translations -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"{} \;
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin.txt -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_ts3.txt -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_mysql.txt -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_steam.txt -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_usermanager.txt -u "$FTP_USER":"$FTP_PASSWORD" "ftp://${FTP_URL}"