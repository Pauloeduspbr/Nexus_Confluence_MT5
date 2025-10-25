//+------------------------------------------------------------------+
#property copyright "Test"
#property version   "1.0"

ulong g_lastPositionTicket = 0;
double g_lastPositionOpenPrice = 0;
string g_lastPositionType = "";

void CheckClosedPositions(ulong &lastTicket, double &lastOpenPrice, string &lastType)
{
   if(lastTicket == 0) return;
   Print("Teste OK");
}

int OnInit() { return INIT_SUCCEEDED; }
void OnTick() { CheckClosedPositions(g_lastPositionTicket, g_lastPositionOpenPrice, g_lastPositionType); }
void OnDeinit(const int reason) {}
