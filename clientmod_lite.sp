
public Plugin:myinfo =
{
	name = "ClientMod - Lite",
	author = "Danyas",
	version = __DATE__ ... " " ... __TIME__
};

#define TAGS "cm,lite"

enum CMAuthType {
	CM_Auth_Unknown = 0,
	CM_Auth_Original,
	CM_Auth_ClientMod,
	CM_Auth_ClientMod_Outdated,
};

new Handle: g_OnClientAuth = INVALID_HANDLE;
new String:_client_version[MAXPLAYERS][8];
new CMAuthType:g_eCMAuth[MAXPLAYERS] = {CM_Auth_Unknown, ...};

public OnPluginStart()
{
	RegConsoleCmd("cm", Cmd_CMInfoMenu);
	RegConsoleCmd("clientmod", Cmd_CMInfoMenu);
	CreateConVar("clientmod_version", "1.0.0", "ClientMod API version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("sv_tags", TAGS,  "ClientMod Tags", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("se_scoreboard", "2", "1 - скрыть показ денег. 2 - Деньги видят только тиммейты. 3 - mp_forcecamera правила для бомбы, щипцов и денег.", FCVAR_REPLICATED, true, 0.0, true, 3.0);
	CreateConVar("se_crosshair_sniper", "0", "Принудительно отключить прицел на снайперках.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String: error[], err_max)
{
	CreateNative("CM_GetClientModVersion", Native_GetClientModVersion);
	CreateNative("CM_GetClientModAuth", Native_GetClientModAuth);
	g_OnClientAuth = CreateGlobalForward("CM_OnClientAuth", ET_Ignore, Param_Cell, Param_Cell);
	
	RegPluginLibrary("clientmod");
	return APLRes_Success;
}

public OnClientConnected(client)
{
	if (client < 1 || IsFakeClient(client) || IsClientInKickQueue(client))
	{
		return;
	}
	
	new bool:bClientModUser = (GetClientInfo(client, "_client_version", _client_version[client], sizeof(_client_version[])) &&
		strlen(_client_version[client]) > 2 && StringToInt(_client_version[client][0]) > 0);
		
	decl String: _client_new[8];
	new bool:bClientModNew = bClientModUser && (GetClientInfo(client, "~clientmod", _client_new, sizeof(_client_new)) &&
		strlen(_client_new) == 3 && _client_new[0] == '2' && _client_new[1] == '.'&& _client_new[2] == '0');
	

	g_eCMAuth[client] = bClientModNew ? CM_Auth_ClientMod : (bClientModUser ? CM_Auth_ClientMod_Outdated : CM_Auth_Original);
	Call_OnClientAuth(client, g_eCMAuth[client]);
}

public OnClientDisconnect(client)
{
	g_eCMAuth[client] = CM_Auth_Unknown;
}


public Action:Cmd_CMInfoMenu(client, args)
{
	if(client > 0)
	{
		new Handle:menu = CreateMenu(MenuHandler_PlayersList);

		decl String:buffer[80];
		
		for (new i = 1; i <= MaxClients; i++) 
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && g_eCMAuth[i] > CM_Auth_Unknown)
			{
				if (g_eCMAuth[i] == CM_Auth_ClientMod)
				{
					FormatEx(buffer, 80, "CMv%s | %N", _client_version[i], i);
				}
				else
				{
					FormatEx(buffer, 80, "OLD | %N", i);
				}
				
				AddMenuItem(menu, "", buffer, ITEMDRAW_DISABLED); 
			}
		}

		SetMenuTitle(menu, "OLD - Старый клиент | CM - Новый клиент"); 

		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}


public MenuHandler_PlayersList(Handle:menu, MenuAction:action, param1, param2) if(action == MenuAction_End) CloseHandle(menu);


Call_OnClientAuth(client, CMAuthType:type)
{
	Call_StartForward(g_OnClientAuth);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_Finish();
}


public Native_GetClientModVersion(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(_client_version) || !IsClientConnected(client) || IsFakeClient(client) || g_eCMAuth[client] < CM_Auth_ClientMod)
	{
		return 0;
	}
	return SetNativeString(2, _client_version[client], GetNativeCell(3)) == SP_ERROR_NONE;
}

public Native_GetClientModAuth(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(g_eCMAuth) || !IsClientConnected(client) || IsFakeClient(client))
	{
		return 0;
	}
	return int:g_eCMAuth[client];
}
