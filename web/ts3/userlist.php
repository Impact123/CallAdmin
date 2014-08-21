<?php
/**
 * -----------------------------------------------------
 * File        ts3call.php
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

header("Content-type: text/xml; charset=utf-8"); 


// Errors destroy the xmlvalidity
//error_reporting(0);


require_once("include/app.config.php");
require_once("../include/calladmin_helpers.php");
require_once("include/TeamSpeak3/TeamSpeak3.php");


$helpers = new CallAdmin_Helpers();
$alreadyAdded = Array();


// Key set and no key given or key is wrong
if (!isset($_GET['key']) || !$helpers->keyToServerKeys($access_keys, $_GET['key']))
{
	$helpers->printXmlError2("APP_AUTH_FAILURE", "Given access key doesn't exist", "CallAdmin_Ts3");
}



$ts3 = new TeamSpeak3();
$xml = new SimpleXMLElement("<CallAdmin_Ts3/>");

try
{
	$ts3_VirtualServer = TeamSpeak3::factory("serverquery://". $user . ":" . $password . "@" . $host . ":" . $queryport . "/?server_port=" . $port);
	$usersChild = $xml->addChild("userList");
	
	$count = 0;
	$uid  = "";
	$name = "";
	foreach ($ts3_VirtualServer->clientList() as $ts3_Client)
	{
		$uid  = $helpers->_xmlentities((string)$ts3_Client['client_unique_identifier']);
		$name = $helpers->_xmlentities((string)$ts3_Client['client_nickname']);
		
		if ($uid == "ServerQuery")
		{
			continue;
		}
		
		// If already added, skip this uid
		if (in_array($uid, $alreadyAdded))
		{
			continue;
		}
		
		$child = $usersChild->addChild("singleUser");

		$child->addChild("name", $name);
		$child->addChild("uid", $uid);
		
		// Add to already added list 
		array_push($alreadyAdded, $uid);
	}
}
catch(TeamSpeak3_Adapter_ServerQuery_Exception $e)
{
	// Nope
	$helpers->printXmlError($e->getMessage(), "CallAdmin_Ts3");
}

$xml->addChild("success", "true");
echo $xml->asXML();
// End of file: ts3call.php
