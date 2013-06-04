# Database updates

This directory contains sql files needed to update the database scheme which is used by calladmin.  
Please view the headers of the specific file you use to updrade your scheme as it may contain useful information about the update process.  

## Important informations
Database upgrades must be done in a specific order, in most cases you cannot directly upgrade from (for example) version 0.1.1 to 0.1.3.  
Please be sure that you change all occurences of `YourTableName` to the tablename you currently use.  