<?php
header("Content-type: text/xml");


// Errors destroy the xmlvalidity
error_reporting(0);


require_once('app.config.php');



// Access management
if(!empty($access_key) && ( !isset($_GET['key']) || $_GET['key'] !== $access_key ) )
{
	printXmlError("AUTHENTICATION_FAILURE");
}



$dbi = new mysqli($host, $username, $password, $database, $dbport);


// Oh noes, we couldn't connect
if($dbi->connect_errno != 0)
{
	printXmlError("DB_FAILURE");
}



// Safety
$from = $data_from;
if(isset($_GET['from']) && preg_match("/^[0-9]{1,11}+$/", $_GET['from']))
{
	$from = $_GET['from'];
}



// Safety
$limit = $data_limit;
if(isset($_GET['limit']) && preg_match("/^[0-9]{1,2}+$/", $_GET['limit']))
{
	if($_GET['limit'] > 0 && $_GET['limit'] <= $data_limit)
	{
		$limit = $_GET['limit'];
	}
}


$result = $dbi->query("SELECT 
							serverID, serverName, targetName, targetID, targetReason, clientName, clientID, reportedAt
						FROM 
							$table
						WHERE
							reportedAt > $from
						ORDER BY
							reportedAt DESC
						LIMIT 0, $limit");
$dbi->close();


// Retrieval failed
if($result === FALSE)
{
	printXmlError("DB_RETRIEVE_FAILURE");
}
					

$xml = new SimpleXMLElement("<CallAdmin/>");

while(($row = $result->fetch_assoc()))
{
	$child = $xml->addChild("singleReport");
	
	foreach($row as $key => $value)
	{
		$key   = _xmlentities($key);
		$value = _xmlentities($value);
		
		
		// This shouldn't happen, but is used for the tool
		if(strlen($value) < 1)
		{
			$value = "NULL";
		}
		
		$child->addChild($key, $value);
	}
}

echo($xml->asXML());
	
	

function _xmlentities($input) 
{
	return str_replace(array("&", "<", ">", "\"", "'"), array("&amp;", "&lt;", "&gt;", "&quot;", "&apos;"), $input);
}


function printXmlError($error)
{
	if(!headers_sent())
	{
		header("Content-type: text/xml"); 
	}

	$xml = new SimpleXMLElement("<CallAdmin/>");
	
	$xml->addChild("error", $error);
	echo $xml->asXML();
	exit;
}
?>