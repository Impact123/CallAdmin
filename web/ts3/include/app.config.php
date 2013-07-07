<?php
/*
 *---------------------------------------------------------------
 * ACCESS SETTINGS
 *---------------------------------------------------------------
*/

/*
Define for each key the admins uid's which recieve a message
Just use like this:

$access_keys = array
(
	'KEY1' => array
	(
		'uid1',
		'uid2',
	),
	
	'KEY2' => array
	(
		'uid2',
	),
	
	'KEY3' => array
	(
		'uid3',
	)
);
*/

$access_keys = array
(
	'' => array
	(
		'',
	),
);




/*
 *---------------------------------------------------------------
 * CONNECTION SETTINGS
 *---------------------------------------------------------------
*/

// Hostname of the ts3 server
$host = "";

// Serveradmin user
$user = "serveradmin";


//  Serveradmin password
$password = "";


// Server port (default is 9987)
$port = 9987;


// Server query port (default is 10011)
$queryport = 10011;

// End of file