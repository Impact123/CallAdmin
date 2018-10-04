#!/bin/bash

find plugins -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/{} \;
find scripting -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/{} \;
find translations -type f -exec curl --ssl-reqd --ftp-create-dirs -T {} -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/{} \;
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin.txt -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_ts3.txt -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_mysql.txt -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_steam.txt -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/
curl --ssl-reqd --ftp-create-dirs -T gameserver/calladmin_usermanager.txt -u $FTP_USER:$FTP_PASSWORD ftp://plugins.gugyclan.eu/calladmin/