<?php
/*
 *---------------------------------------------------------------
 * ACCESS SETTINGS
 *---------------------------------------------------------------
*/

// This key must be sent in order to view reports, leave empty to disable
$access_key = '';




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
$trackers_table    = 'CallAdmin_Trackers';
$dbport            = '3306';
// End of file