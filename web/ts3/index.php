<?php
/**
 * -----------------------------------------------------
 * File        ts3call.php
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


require_once("include/app.config.php");
require_once("../include/calladmin_helpers.php");
require_once("include/TeamSpeak3/libraries/TeamSpeak3/TeamSpeak3.php");


$helpers = new CallAdmin_Helpers();


// Key set and no key given or key is wrong
if (!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError2("APP_AUTH_FAILURE", "Given access key doesn't exist", "CallAdmin_Ts3");
}


if (!isset($_GET['targetid']) 
		|| !isset($_GET['targetname'])
		|| !isset($_GET['targetreason'])
		|| !isset($_GET['clientid'])
		|| !isset($_GET['clientname'])
		|| !isset($_GET['servername'])
		|| !isset($_GET['serverip']))
{
	$helpers->printXmlError2("APP_INPUT_FAILURE", "Required meta data was missing or given in invalid format", "CallAdmin_Ts3");
}


//Variables
$targetID     = $_GET['targetid'];
$targetName   = $_GET['targetname'];
$targetReason = $_GET['targetreason'];
$clientID     = $_GET['clientid'];
$clientName   = $_GET['clientname'];
$serverName   = $_GET['servername'];
$serverIP     = $_GET['serverip'];


$targetCommBB = "Invalid";
if ($helpers->IsValidSteamID($targetID))
{
	$targetCommID = $helpers->SteamIDToComm($targetID);
	$targetCommBB = "[url=http://steamcommunity.com/profiles/" . $targetCommID . "]$targetID" . "[/url]";
}


$clientCommBB = "Invalid";
if ($helpers->IsValidSteamID($clientID))
{
	$clientCommID = $helpers->SteamIDToComm($clientID);
	$clientCommBB = "[url=http://steamcommunity.com/profiles/" . $clientCommID . "]$clientID" . "[/url]";
}

$connect = "[url=steam://connect/" . $serverIP . "]connect now[/url]";



require_once("include/TeamSpeak3/TeamSpeak3.php");
$ts3 = new TeamSpeak3();
$alreadyAdded = Array();
$inMutedChannel = Array();

try
{
	$ts3_VirtualServer = TeamSpeak3::factory("serverquery://". $user . ":" . $password . "@" . $host . ":" . $queryport . "/?server_port=" . $port);
	
	$uid  = "";
	//$name = "";
	
	if (isset($muted_channels) && is_array($muted_channels))
	{
		foreach ($ts3_VirtualServer->channelList() as $ts3_Channel)
		{
			$channelName = $ts3_Channel->__toString();
			
			if (!in_array($channelName, $muted_channels))
			{
				continue;
			}
			
			foreach ($ts3_Channel->clientList() as $client)
			{
				$clientUid = (string)$client['client_unique_identifier'];
				
				if (!in_array($clientUid, $inMutedChannel))
				{
					array_push($inMutedChannel, $clientUid);
				}
			}
		}
	}
	
	foreach ($ts3_VirtualServer->clientList() as $ts3_Client)
	{
		$uid = (string)$ts3_Client['client_unique_identifier'];
		//$name = (string)$ts3_Client['client_nickname'];
		
		
		// If already added, skip this uid
		if (in_array($uid, $alreadyAdded))
		{
			continue;
		}
		
		// If in muted channel, skip this uid
		if (in_array($uid, $inMutedChannel))
		{
			continue;
		}
		
		// Is listed as admin, go send him a message
		if (in_array($uid, $access_keys[$_GET['key']]))
		{
			// Add to already added list 
			array_push($alreadyAdded, $uid);
			
			$ts3_Client->message("----------------------------------------------------");
			$ts3_Client->message("[CallAdmin] New report on:   $serverName ($serverIP) $connect");
			$ts3_Client->message("[CallAdmin] Reporter:        $clientName ($clientCommBB)");
			$ts3_Client->message("[CallAdmin] Report reason:   $targetReason");
			$ts3_Client->message("[CallAdmin] Reported player: $targetName ($targetCommBB)");
			$ts3_Client->message("----------------------------------------------------");
		}
	}
}
catch(TeamSpeak3_Adapter_ServerQuery_Exception $e)
{
	// Nope
	$helpers->printXmlError($e->getMessage(), "CallAdmin_Ts3");
}

$xml = new SimpleXMLElement("<CallAdmin_Ts3/>");
$xml->addChild("success", "true");
echo $xml->asXML();
// End of file: ts3call.php
