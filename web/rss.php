<?php
/**
 * -----------------------------------------------------
 * File        rss.php
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
require_once('include/FeedWriter/Feed.php');
require_once('include/FeedWriter/RSS2.php');
require_once('include/FeedWriter/Item.php');
require_once('autoload.php');


$helpers = new CallAdmin_Helpers();
$rss     = new FeedWriter\RSS2();


// Key set and no key given or key is wrong
if (!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError2("APP_AUTH_FAILURE", "Given access key doens't exist", "CallAdmin_Rss");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if ($dbi->connect_errno != 0)
{
	$detailError = sprintf("Errorcode '%d': %s", $dbi->connect_errno, $dbi->connect_error);
	$helpers->printXmlError2("DB_CONNECT_FAILURE", $detailError, "CallAdmin_Rss");
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



// Updated serverKey Access list
$uniqueArray = $helpers->keysToArray($access_keys);

if ($uniqueArray)
{
	$deleteresult = $dbi->query("TRUNCATE `" .$table. "_Access`");

	// delete failed
	if ($deleteresult === FALSE)
	{
		$detailError = sprintf("Errorcode '%d': %s", $dbi->errno, $dbi->error);
		
		$dbi->close();
		$helpers->printXmlError2("DB_DELETE_FAILURE", $detailError, "CallAdmin_Rss");
	}
	
	// Start with zero
	$current = 0; 
	
	foreach ($uniqueArray as $serverKey)
	{
		$bit = (1 << $current);
		
		$insertresult = $dbi->query("INSERT IGNORE INTO `" .$table. "_Access`
							(serverKey, accessBit)
						VALUES
							('$serverKey', $bit)");

		// Insert failed
		if ($insertresult === FALSE)
		{
			$detailError = sprintf("Errorcode '%d': %s", $dbi->errno, $dbi->error);
			
			$dbi->close();
			$helpers->printXmlError2("DB_UPDATE_FAILURE", $detailError, "CallAdmin_Rss");
		}
		
		if ($current + 1 >= 64)
		{
			$dbi->close();
			$helpers->printXmlError("DB_MAX_ACCESS_REACHED", "CallAdmin_Rss");
		}
		
		// Update current
		$current++;
	}
}


// Safety
$from = $data_from;
$from_query = "reportedAt > $from";
if (isset($_GET['from']) && preg_match("/^[0-9]{1,11}+$/", $_GET['from']))
{
	$from = $dbi->escape_string($_GET['from']);
	
	
	$from_type = "unixtime";
	$from_query = "reportedAt > $from";
	
	// We use the global mysqltime in all tables and columns, the client however can have an different time
	// Thus most times it's better to range the last results in seconds (max 120 seconds ago, etc) thus this option is introduced
	if (isset($_GET['from_type']) && preg_match("/^[a-zA-Z]{8}+$/", $_GET['from_type']))
	{
		if (strcasecmp($_GET['from_type'], "unixtime") === 0)
		{
			$from_query = "reportedAt > $from";
		}
		else if (strcasecmp($_GET['from_type'], "interval") === 0)
		{
			$from_query = "TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(reportedAt), NOW()) <= $from";
		}
	}
	
	// Just to be sure ;)
	$from_type = $dbi->escape_string($from_type);
}


// Safety
if (isset($_GET['handled']) && preg_match("/^[0-9]{1,11}+$/", $_GET['handled']))
{
	$from = $dbi->escape_string($_GET['handled']);

	$from_query .= " OR callHandled = 1 AND TIMESTAMPDIFF(SECOND, FROM_UNIXTIME(reportedAt), NOW()) <= $from";
}



// Safety
$limit = $data_limit;
if (isset($_GET['limit']) && preg_match("/^[0-9]{1,2}+$/", $_GET['limit']))
{
	if ($_GET['limit'] > 0 && $_GET['limit'] <= $data_limit)
	{
		$limit = $dbi->escape_string($_GET['limit']);
	}
}


// Safety
$sort = strtoupper("desc");
if (isset($_GET['sort']) && preg_match("/^[a-zA-Z]{3,4}+$/", $_GET['sort']))
{
	if (strcasecmp($_GET['sort'], "desc") === 0 || strcasecmp($_GET['sort'], "asc") === 0)
	{
		$sort = strtoupper($dbi->escape_string($_GET['sort']));
	}
}


// Server Key clause
$server_key_clause = 'serverKey IN (' .$helpers->keyToServerKeys($access_keys, $_GET['key']). ') OR LENGTH(serverKey) < 1';


$fetchresult = $dbi->query("SELECT 
							callID, CONCAT(serverIP, ':', serverPort) as fullIP, serverName, targetName, targetID, targetReason, clientName, clientID, reportedAt, callHandled
						FROM 
							`$table`
						WHERE
							($from_query) AND $server_key_clause
						ORDER BY
							reportedAt $sort
						LIMIT 0, $limit");


// Retrieval failed
if ($fetchresult === FALSE)
{
	$detailError = sprintf("Errorcode '%d': %s", $dbi->errno, $dbi->error);
	
	$dbi->close();
	$helpers->printXmlError("DB_RETRIEVE_FAILURE", $detailError, "CallAdmin_Rss");
}


// Save this tracker if key is set, key was given, we have an valid remote address and the client sends an store (save him as available)
if (isset($_SERVER['REMOTE_ADDR']) && isset($_GET['store']))
{
	$trackerIP = $dbi->escape_string($helpers->AnonymizeIP($_SERVER['REMOTE_ADDR']));
	$trackerID = "";


	// Steamid was submitted, this must have come from the client
	if (isset($_GET['steamid']) && $helpers->IsValidSteamID($_GET['steamid']))
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
	if ($insertresult === FALSE)
	{
		$detailError = sprintf("Errorcode '%d': %s", $dbi->errno, $dbi->error);
		
		$dbi->close();
		$helpers->printXmlError("DB_UPDATE_FAILURE", $detailError, "CallAdmin_Rss");
	}
}


$dbi->close();


$rss->setTitle("CallAdmin RSS Feed");
$rss->setLink("https://github.com/Impact123/CallAdmin");
$rss->setSelfLink(sprintf("%s://%s%s", (!empty($_SERVER['HTTPS']) ? "https" : "http"), $_SERVER['HTTP_HOST'], $_SERVER['REQUEST_URI']));
$rss->setImage("CallAdmin RSS Feed", "https://github.com/Impact123/CallAdmin", "https://dordnung.de/calladmin/img/calladmin.png");
$rss->setDescription("CallAdmin RSS Feed");

while (($row = $fetchresult->fetch_assoc()))
{
	$child = $rss->createNewItem();

	$callID = htmlentities($row['callID']);
	$fullIP = htmlentities($row['fullIP']);
	$serverName = htmlentities($row['serverName']);
	$targetName = htmlentities($row['targetName']);
	$targetID = htmlentities($row['targetID']);
	$targetReason = htmlentities($row['targetReason']);
	$clientName = htmlentities($row['clientName']);
	$clientID = htmlentities($row['clientID']);
	$reportedAt = htmlentities($row['reportedAt']);
	
	$clientLink = "INVALID";
	if ($helpers->IsValidSteamID($clientID))
	{
		if ($helpers->GetAuthIDType($clientID) == AuthIDType::AuthString_SteamID2)
		{
			$clientID = $helpers->SteamID2ToSteamId($clientID);
		}
		
		$clientLink = sprintf("<a href=\"http://steamcommunity.com/profiles/%s\">%s</a>", $helpers->SteamIDToComm($clientID), $clientName);
	}
	
	$targetLink = "INVALID";
	if ($helpers->IsValidSteamID($targetID))
	{
		if ($helpers->GetAuthIDType($targetID) == AuthIDType::AuthString_SteamID2)
		{
			$targetID = $helpers->SteamID2ToSteamId($targetID);
		}
		
		$targetLink = sprintf("<a href=\"http://steamcommunity.com/profiles/%s\">%s</a>", $helpers->SteamIDToComm($targetID), $targetName);
	}
	
	$child->setTitle(sprintf("New report on: %s (%s)", $fullIP, $serverName));
	$child->setLink(sprintf("steam://connect/%s", $fullIP));
	$child->setDate($reportedAt);
	$child->setDescription(sprintf("New report on server: %s (%s)<br />Reporter: %s (%s)<br />Target: %s (%s)<br />Reason: %s<br />Join server: <a href=\"steam://connect/%s\">Click here to join</a>",
					$serverName, $fullIP, $clientName, $clientLink, $targetName, $targetLink, $targetReason, $fullIP));
	$child->setId(md5($callID));
	
	$rss->addItem($child);
}

$rss->printFeed();
// End of file: rss.php