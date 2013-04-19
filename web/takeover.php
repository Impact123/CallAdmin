<?php
/**
 * -----------------------------------------------------
 * File        takeover.php
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


require_once('include/app.config.php');
require_once('autoload.php');


$helpers = new CallAdmin_Helpers();



// Key set and no key given or key is wrong
if((!empty($access_key) && !isset($_GET['key']) ) || $_GET['key'] !== $access_key)
{
	$helpers->printXmlError("APP_AUTH_FAILURE", "CallAdmin_Takeover");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if($dbi->connect_errno != 0)
{
	$helpers->printXmlError("DB_CONNECT_FAILURE", "CallAdmin_Takeover");
}


// Set utf-8 encodings
$dbi->set_charset("utf8");


// Safety
if(isset($_GET['callid']) && preg_match("/^[0-9]{1,11}+$/", $_GET['callid']))
{
	$callID = $dbi->escape_string($_GET['callid']);
	
	$insertresult = $dbi->query("UPDATE
									$table
								SET callHandled = 1
							WHERE
								callID = $callID");

	// Insert failed, we should check if the update was successfull somehow (affected_rows ist reliable here)
	if($insertresult === FALSE)
	{
		$dbi->close();
		$helpers->printXmlError("DB_UPDATE_FAILURE", "CallAdmin_Takeover");
	}
}
else
{
	$helpers->printXmlError("APP_INPUT_FAILURE", "CallAdmin_Takeover");
}

$dbi->close();

$xml = new SimpleXMLElement("<CallAdmin_Trackers/>");
$xml->addChild("success", "true");
echo $xml->asXML();
// End of file: takeover.php