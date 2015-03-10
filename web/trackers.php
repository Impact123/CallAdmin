<?php
/**
 * -----------------------------------------------------
 * File        trackers.php
 * Authors     Impact, Popoklopsi
 * License     GPLv3
 * Web         http://gugyclan.eu, http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013 Impact, Popoklopsi
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
if(!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError("APP_AUTH_FAILURE", "CallAdmin_Trackers");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if($dbi->connect_errno != 0)
{
	$helpers->printXmlError("DB_CONNECT_FAILURE", "CallAdmin_Trackers");
}


// Set utf-8 encodings
$dbi->set_charset("utf8");



// Escape server keys
foreach($access_keys as $key => $value)
{
	if(is_array($value))
	{
		foreach($value as $serverKey)
		{
			$access_keys[$key][$serverKey] = $dbi->escape_string($serverKey);
		}
	}
}


// Safety
$from = $data_from;
$from_query = "lastView > $from";
if(isset($_GET['from']) && preg_match("/^[0-9]{1,11}+$/", $_GET['from']))
{
	$from = $dbi->escape_string($_GET['from']);
	
	
	$from_type = "unixtime";
	$from_query = "lastView > $from";
	
	// We use the global mysqltime in all tables and columns, the client however can have an different time
	// Thus most times it's better to range the last results in seconds (max 120 seconds ago, etc) thus this option is introduced
	if(isset($_GET['from_type']) && preg_match("/^[a-zA-Z]{8}+$/", $_GET['from_type']))
	{
		if(strcasecmp($_GET['from_type'], "unixtime") === 0)
		{
			$from_query = "lastView > $from";
		}
		else if(strcasecmp($_GET['from_type'], "interval") === 0)
		{
			$from_query = "TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(lastView), NOW()) <= $from";
		}
	}

	// Just to be sure ;)
	$from_type = $dbi->escape_string($from_type);
}



// Safety
$limit = $data_limit;
if(isset($_GET['limit']) && preg_match("/^[0-9]{1,2}+$/", $_GET['limit']))
{
	if($_GET['limit'] > 0 && $_GET['limit'] <= $data_limit)
	{
		$limit = $dbi->escape_string($_GET['limit']);
	}
}



// Safety
$sort = strtoupper("desc");
if(isset($_GET['sort']) && preg_match("/^[a-zA-Z]{3,4}+$/", $_GET['sort']))
{
	if(strcasecmp($_GET['sort'], "desc") === 0 || strcasecmp($_GET['sort'], "asc") === 0)
	{
		$sort = strtoupper($dbi->escape_string($_GET['sort']));
	}
}


// Access query
$access_query = '`accessID` & (SELECT SUM(`accessBit`) FROM `' .$table. '_Access` WHERE serverKey IN (' .$helpers->keyToServerKeys($access_keys, $_GET['key']). '))';


$fetchresult = $dbi->query("SELECT 
							trackerIP, trackerID, lastView, TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(lastView), NOW()) AS lastViewDiff
						FROM 
							`" .$table ."_Trackers`
						WHERE
							$from_query AND $access_query
						ORDER BY
							lastView $sort
						LIMIT 0, $limit");

// Retrieval failed
if($fetchresult === FALSE)
{
	$dbi->close();
	$helpers->printXmlError("DB_RETRIEVE_FAILURE", "CallAdmin_Trackers");
}

$dbi->close();


$xml = new SimpleXMLElement("<CallAdmin_Trackers/>");

while(($row = $fetchresult->fetch_assoc()))
{
	$child = $xml->addChild("singleTracker");

	foreach($row as $key => $value)
	{
		$key   = $helpers->_xmlentities($key);
		$value = $helpers->_xmlentities($value);


		// This shouldn't happen, but is used for the client
		if(strlen($value) < 1)
		{
			$value = "NULL";
		}

		$child->addChild($key, $value);
	}
}

echo $xml->asXML();
// End of file: trackers.php