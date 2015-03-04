/** Include guard */
#if defined _calladmin_stocks_included
	#endinput
#endif
#define _calladmin_stocks_included




stock bool:IsClientValid(id)
{
	if (id > 0 && id <= MaxClients && IsClientInGame(id))
	{
		return true;
	}
	
	return false;
}