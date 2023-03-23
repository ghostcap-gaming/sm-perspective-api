#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>

#define BASE_URL "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze"

ConVar convar_Enabled;
ConVar convar_APIKey;

char g_Attributes[6][32] = {"TOXICITY", "SEVERE_TOXICITY", "IDENTITY_ATTACK", "INSULT", "PROFANITY", "THREAT"};

GlobalForward g_Forward_OnCommentAnalyzed;

public Plugin myinfo = {
	name = "[ANY] Perspective API", 
	author = "GhostCap", 
	description = "Easy function call for the perspective API.", 
	version = "1.0.0", 
	url = "https://www.ghostcap.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("perspective-api");
	g_Forward_OnCommentAnalyzed = new GlobalForward("OnCommentAnalyzed", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_Float);
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("sm_perspective_api_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_perspective_api_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_APIKey = CreateConVar("sm_perspective_api_key", "apikey", "Input your API key from Google here.", FCVAR_PROTECTED);
	AutoExecConfig();
}

public void OnConfigsExecuted() {
	char sAPIKey[128];
	convar_APIKey.GetString(sAPIKey, sizeof(sAPIKey));

	if (strlen(sAPIKey) == 0) {
		SetFailState("Plugin requires a valid API key set in order to function.");
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
	if (!convar_Enabled.BoolValue || IsFakeClient(client)) {
		return;
	}

	char sComment[255];
	strcopy(sComment, sizeof(sComment), sArgs);
	TrimString(sComment);

	if (strlen(sComment) < 2 || IsStringNumeric(sComment)) {
		return;
	}

	JSONObject analyze_request = new JSONObject();

	JSONObject comment = new JSONObject();
	comment.SetString("text", sComment);
	analyze_request.Set("comment", comment);

	JSONObject requestedAttributes = new JSONObject();
	for (int i = 0; i < sizeof(g_Attributes); i++) {
		requestedAttributes.Set(g_Attributes[i], new JSONObject());
	}
	analyze_request.Set("requestedAttributes", requestedAttributes);

	char sAPIKey[128];
	convar_APIKey.GetString(sAPIKey, sizeof(sAPIKey));

	if (strlen(sAPIKey) == 0) {
		delete analyze_request;
		ThrowError("Error while parsing %N's comment: No API key specified.", client);
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sComment);

	HTTPRequest request = new HTTPRequest(BASE_URL);
	request.SetHeader("Content-Type", "application/json");
	request.AppendQueryParam("key", sAPIKey);
	request.Post(analyze_request, OnParseComment, pack);

	delete comment;
	delete requestedAttributes;
	delete analyze_request;
}

public void OnParseComment(HTTPResponse response, DataPack pack, const char[] error) {
	pack.Reset();
	int userid = pack.ReadCell();
	char comment[255];
	pack.ReadString(comment, sizeof(comment));
	delete pack;

	int client;
	if ((client = GetClientOfUserId(userid)) == 0) {
		return;
	}

	JSONObject analyze_request = view_as<JSONObject>(response.Data);

	if (response.Status != HTTPStatus_OK) {

		if (response.Status == HTTPStatus_BadRequest) {
			return;
		}

		char message[1024];
		analyze_request.GetString("message", message, sizeof(message));
		delete analyze_request;
		ThrowError("Error while parsing %N's comment: %s\n - Error: %s - Response Code: [%i]\n - Message: %s", client, comment, error, response.Status, message);
	}

	JSONObject attributeScores = view_as<JSONObject>(analyze_request.Get("attributeScores"));

	JSONObject attribute;
	JSONObject summaryScore;

	char type[256];
	float value;

	for (int i = 0; i < sizeof(g_Attributes); i++) {
		//PrintToServer("%i: %s", i, g_Attributes[i]);
		attribute = view_as<JSONObject>(attributeScores.Get(g_Attributes[i]));

		if (attribute == null) {
			continue;
		}

		summaryScore = view_as<JSONObject>(attribute.Get("summaryScore"));

		if (summaryScore == null) {
			continue;
		}

		summaryScore.GetString("type", type, sizeof(type));
		value = summaryScore.GetFloat("value");

		Call_StartForward(g_Forward_OnCommentAnalyzed);
		Call_PushCell(client);
		Call_PushString(comment);
		Call_PushString(g_Attributes[i]);
		Call_PushString(type);
		Call_PushFloat(value);
		Call_Finish();

		delete summaryScore;
		delete attribute;
	}

	delete attributeScores;
	delete analyze_request;
}

public void OnCommentAnalyzed(int client, const char[] comment, const char[] attribute, const char[] type, float value) {
	//LogMessage("Comment Analyzed:\n - Name: %N\n - Comment: %s\n - Attribute: %s\n - Type: %s\n - Value: %.2f", client, comment, attribute, type, value);
}

bool IsStringNumeric(const char[] str) {
	int x = 0, dotsFound = 0, numbersFound = 0;

	if (str[x] == '+' || str[x] == '-') {
		x++;
	}

	while (str[x] != '\0') {
		if (IsCharNumeric(str[x])) {
			numbersFound++;
		} else if (str[x] == '.') {
			dotsFound++;

			if (dotsFound > 1) {
				return false;
			}
		} else {
			return false;
		}
		x++;
	}

	return numbersFound > 0;
}