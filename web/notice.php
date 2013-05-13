<?php

/**
 * -----------------------------------------------------
 * File        notice.php
 * Authors     Impact, David <popoklopsi> Ordnung
 * License     GPLv3
 * Web         http://gugyclan.eu, http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013 Impact, David <popoklopsi> Ordnung
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
$methods = array('notice', 'trackers');


$method = 'notice';
if(isset($_GET['method']))
{
	if(in_array($_GET['method'], $methods))
	{
		$method = $_GET['method'];
	}
}

header("Content-type: text/xml; charset=utf-8"); 


// Errors destroy the xmlvalidity
//error_reporting(0);


require_once('include/app.config.php');
require_once('autoload.php');


$helpers = new CallAdmin_Helpers();


// Key set and no key given or key is wrong
if(!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError("APP_AUTH_FAILURE", "CallAdmin_Notice");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if($dbi->connect_errno != 0)
{
	$helpers->printXmlError("DB_CONNECT_FAILURE", "CallAdmin_Notice");
}


// Set utf-8 encodings
$dbi->set_charset("utf8");



// Updated serverKey Access list
$uniqueArray = $helpers->keysToArray($access_keys);

if($uniqueArray)
{
	$deleteresult = $dbi->query("TRUNCATE `" .$table. "_Access`");

	// delete failed
	if($deleteresult === FALSE)
	{
		$dbi->close();
		$helpers->printXmlError("DB_DELETE_FAILURE", "CallAdmin_Notice");
	}
	
	// Start with zero
	$current = 0; 
	
	foreach($uniqueArray as $serverKey)
	{
		$bit = (1 << $current);
		
		$insertresult = $dbi->query("INSERT IGNORE INTO `" .$table. "_Access`
							(serverKey, accessBit)
						VALUES
							('$serverKey', $bit)");

		// Insert failed
		if($insertresult === FALSE)
		{
			$dbi->close();
			$helpers->printXmlError("DB_UPDATE_FAILURE", "CallAdmin_Notice");
		}
		
		if($current + 1 >= 64)
		{
			$dbi->close();
			$helpers->printXmlError("DB_MAX_ACCESS_REACHED", "CallAdmin_Notice");
		}
		
		// Update current
		$current++;
	}
}


// Safety
$from = $data_from;
$from_query = "reportedAt > $from";
if(isset($_GET['from']) && preg_match("/^[0-9]{1,11}+$/", $_GET['from']))
{
	$from = $dbi->escape_string($_GET['from']);
	
	
	$from_type = "unixtime";
	$from_query = "reportedAt > $from";
	
	// We use the global mysqltime in all tables and columns, the client however can have an different time
	// Thus most times it's better to range the last results in seconds (max 120 seconds ago, etc) thus this option is introduced
	if(isset($_GET['from_type']) && preg_match("/^[a-zA-Z]{8}+$/", $_GET['from_type']))
	{
		if(strcasecmp($_GET['from_type'], "unixtime") === 0)
		{
			$from_query = "reportedAt > $from";
		}
		else if(strcasecmp($_GET['from_type'], "interval") === 0)
		{
			$from_query = "TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(reportedAt), NOW()) <= $from";
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


// Server Key clause
$server_key_clause = 'serverKey IN (' .$helpers->keyToServerKeys($access_keys, $_GET['key']). ') OR LENGTH(serverKey) < 1';


$fetchresult = $dbi->query("SELECT 
							callID, serverIP, serverPort, CONCAT(serverIP, ':', serverPort) as fullIP, serverName, targetName, targetID, targetReason, clientName, clientID, reportedAt, callHandled
						FROM 
							`$table`
						WHERE
							callHandled != 1 AND $from_query AND $server_key_clause
						ORDER BY
							reportedAt $sort
						LIMIT 0, $limit");

// Retrieval failed
if($fetchresult === FALSE)
{
	$dbi->close();
	$helpers->printXmlError("DB_RETRIEVE_FAILURE", "CallAdmin_Notice");
}


// Save this tracker if key is set, key was given, we have an valid remote address and the client sends an store (save him as available)
if(isset($_SERVER['REMOTE_ADDR']) && isset($_GET['store']))
{
	$trackerIP = $dbi->escape_string($helpers->AnonymizeIP($_SERVER['REMOTE_ADDR']));
	$trackerID = "";


	// Steamid was submitted, this must have come from the client
	if(isset($_GET['steamid']) && $helpers->IsValidSteamID($_GET['steamid']))
	{
		$trackerID = $dbi->escape_string($_GET['steamid']);
	}
	
	
	// Access query
	$access_query = '(SELECT SUM(`accessBit`) FROM `' .$table. '_Access` WHERE serverKey IN (' .$helpers->keyToServerKeys($access_keys, $_GET['key']). '))';


	$insertresult = $dbi->query("INSERT IGNORE INTO `" .$table. "_Trackers`
						(trackerIP, trackerID, lastView, accessID)
					VALUES
						('$trackerIP', '$trackerID', UNIX_TIMESTAMP(), $access_query)
					ON DUPLICATE KEY
						UPDATE lastView = UNIX_TIMESTAMP(), trackerID = '$trackerID', accessID = $access_query");

	// Insert failed
	if($insertresult === FALSE)
	{
		$dbi->close();
		$helpers->printXmlError("DB_UPDATE_FAILURE", "CallAdmin_Notice");
	}
}


$dbi->close();


$xml = new SimpleXMLElement("<CallAdmin/>");

$counter = 0;
while(($row = $fetchresult->fetch_assoc()))
{
	$child = $xml->addChild("singleReport");

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
	
	$counter++;
}
$child = $xml->addChild("foundRows", $counter);

echo $xml->asXML();
// End of file: notice.php