/*
	This file is used to update an existing installtion of CallAdmin to a newer one
	
	Important informations
	------------
	Database upgrades must be done in a specific order, in most cases you cannot directly upgrade from (for example) version 0.1.1 to 0.1.3.  
	Please be sure that you change all occurences of `YourTableName` to the tablename you currently use.  
	
	
	What has changed?
	-----------------
	 - The targetReason column is now bigger, which allowing longer reasons
	 - The column serverKey was added, which allows the use of a more complex permission system
	 
	
	For which version is this file?
	-------------------------------	
	This file should be used to update the database scheme from version `0.1.2` to `0.1.3`
*/

ALTER TABLE `YourTableName`
	ALTER `targetReason` DROP DEFAULT;
ALTER TABLE `YourTableName`
	ADD COLUMN `serverKey` VARCHAR(32) NOT NULL AFTER `serverName`,
	CHANGE COLUMN `targetReason` `targetReason` VARCHAR(128) NOT NULL AFTER `targetID`,
	ADD INDEX `serverKey` (`serverKey`);
