<?php
header("Content-type: text/xml");


// Errors destroy the xmlvalidity
error_reporting(0);


require_once('app.config.php');



// Key set and no key given or key is wrong
if( ( !empty($access_key) && !isset($_GET['key']) ) || $_GET['key'] !== $access_key )
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
	$from = $dbi->escape_string($_GET['from']);
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



$fetchresult = $dbi->query("SELECT 
							serverIP, serverPort, CONCAT(serverIP, ':', serverPort) as fullIP, serverName, targetName, targetID, targetReason, clientName, clientID, reportedAt
						FROM 
							$table
						WHERE
							reportedAt > $from
						ORDER BY
							reportedAt $sort
						LIMIT 0, $limit");

// Retrieval failed
if($fetchresult === FALSE)
{
	$dbi->close();
	printXmlError("DB_RETRIEVE_FAILURE");
}


// Save this tracker if key is set, key was given, we have an valid remote address and the client sends an store (save him as available)
if( ( !empty($access_key) && isset($_GET['key']) ) && isset($_SERVER['REMOTE_ADDR']) && isset($_GET['store']))
{
	$trackerIP = $dbi->escape_string($_SERVER['REMOTE_ADDR']);
	
	$insertresult = $dbi->query("INSERT IGNORE INTO CallAdmin_Trackers
						(trackerIP, lastView)
					VALUES
						('$trackerIP', UNIX_TIMESTAMP())
					ON DUPLICATE KEY
						UPDATE lastView = UNIX_TIMESTAMP()");
	
	// Insert failed
	if($insertresult === FALSE)
	{
		$dbi->close();
		printXmlError("DB_UPDATE_FAILURE");
	}
}


$dbi->close();
					

$xml = new SimpleXMLElement("<CallAdmin/>");

while(($row = $fetchresult->fetch_assoc()))
{
	$child = $xml->addChild("singleReport");
	
	foreach($row as $key => $value)
	{
		$key   = _xmlentities($key);
		$value = _xmlentities($value);
		
		
		// This shouldn't happen, but is used for the client
		if(strlen($value) < 1)
		{
			$value = "NULL";
		}
		
		$child->addChild($key, $value);
	}
}

echo $xml->asXML();
	
	

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