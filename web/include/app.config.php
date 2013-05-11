<?php
/*
 *---------------------------------------------------------------
 * ACCESS SETTINGS
 *---------------------------------------------------------------
*/


/*
Define for each key the server keys to assign to.
Just use like this:

$access_keys = array
(
	'KEY1' => array
	(
		'CSS_Server',
		'TF2_Server',
	),
	
	'KEY2' => array
	(
		'CSGO_Server_1',
	),
	
	'KEY3' => array
	(
		'CSGO_Server_2',
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
 * DATA SETTINGS
 *---------------------------------------------------------------
*/

// Upper limit of entries we can fetch from the database
$data_limit = 50;

// By default we only fetch the entries of the last hour, set to 0 to disable
$data_from  = (time() - 3600);




/*
 *---------------------------------------------------------------
 * DATABASE SETTINGS
 *---------------------------------------------------------------
*/
$host              = '';
$username          = '';
$password          = '';
$database          = '';
$table             = 'CallAdmin';
$dbport            = '3306';
// End of file