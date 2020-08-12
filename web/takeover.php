<?php
/**
 * -----------------------------------------------------
 * File        takeover.php
 * Authors     Impact, dordnung
 * License     GPLv3
 * Web         http://gugyclan.eu, https://dordnung.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013-2018 Impact, dordnung
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */
header("Content-type: text/xml; charset=utf-8"); 


// Errors destroy the xmlvalidity
//error_reporting(0);


require_once('include/app.config.php');
require_once('autoload.php');


$helpers = new CallAdmin_Helpers();



// Key set and no key given or key is wrong
if (!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError2("APP_AUTH_FAILURE", "Given access key doesn't exist", "CallAdmin_Takeover");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if ($dbi->connect_errno != 0)
{
	$detailError = sprintf("Errorcode '%d': %s", $dbi->connect_errno, $dbi->connect_error);
	$helpers->printXmlError2("DB_CONNECT_FAILURE", $detailError, "CallAdmin_Takeover");
}


// Set utf-8 encodings
$dbi->set_charset("utf8mb4");



// Escape server keys
foreach ($access_keys as $key => $value)
{
	if (is_array($value))
	{
		foreach ($value as $serverKey)
		{
			$access_keys[$key][$serverKey] = $dbi->escape_string($serverKey);
		}
	}
}



// Server Key clause
$server_key_clause = 'serverKey IN (' .$helpers->keyToServerKeys($access_keys, $_GET['key']). ') OR LENGTH(serverKey) < 1';


// Safety
if (isset($_GET['callid']) && preg_match("/^[0-9]{1,11}+$/", $_GET['callid']))
{
	$callID = $dbi->escape_string($_GET['callid']);
	
	$insertresult = $dbi->query("UPDATE
									`$table`
								SET callHandled = 1
							WHERE
								callID = $callID AND $server_key_clause");

	// Insert failed, we should check if the update was successfull somehow (affected_rows ist reliable here)
	if ($insertresult === FALSE)
	{
		$detailError = sprintf("Errorcode '%d': %s", $dbi->errno, $dbi->error);
		
		$dbi->close();
		$helpers->printXmlError2("DB_UPDATE_FAILURE", $detailError, "CallAdmin_Takeover");
	}
}
else
{
	$helpers->printXmlError2("APP_INPUT_FAILURE", "Required meta data was missing or given in invalid format", "CallAdmin_Takeover");
}

$dbi->close();

$xml = new SimpleXMLElement("<CallAdmin_Trackers/>");
$xml->addChild("success", "true");
echo $xml->asXML();
// End of file: takeover.php