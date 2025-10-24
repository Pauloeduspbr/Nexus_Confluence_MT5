//+------------------------------------------------------------------+
//| Nexus Confluence EA v4.40 - VERSÃO SIMPLIFICADA                 |
//| 🔥 v4.40: SIMPLIFICAÇÃO RADICAL - APENAS O BÁSICO               |
//|                                                                  |
//| ✅ O QUE TEM:                                                    |
//|   - Filtro semanal (dias da semana)                             |
//|   - Horário início/fim                                          |
//|   - TP fixo (em pontos)                                          |
//|   - SL fixo (em pontos)                                          |
//|   - Lote fixo (Forex/B3 compatível)                            |
//|   - Análise de setup dos indicadores (mantida)                  |
//|                                                                  |
//| ❌ O QUE FOI REMOVIDO:                                           |
//|   - Gestão de risco automática                                  |
//|   - Cálculo ATR                                                  |
//|   - Breakeven                                                    |
//|   - Trailing Stop                                                |
//|   - TP parcial                                                   |
//|   - SL estrutural                                                |
//|   - Proteção drawdown complexa                                  |
//|   - Redução progressiva de risco                                |
//|                                                                  |
//| FUNCIONAMENTO:                                                   |
//|   1. Valida dia da semana                                       |
//|   2. Valida horário                                              |
//|   3. Analisa setup dos indicadores                              |
//|   4. Se setup válido: Abre ordem com SL/TP fixos               |
//|   5. FIM - sem gestão ativa de posições                         |
//+------------------------------------------------------------------+
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.40 - SIMPLIFICADO                                     |
//+------------------------------------------------------------------+
#property strict
#property copyright "Nexus Confluence EA v4.40"
#property version   "4.40"

//--- Incluir módulos SIMPLIFICADOS
#include <Trade\Trade.mqh>
#include "..\..\Include\NexusConfluenceEA\Parametros.mqh"
#include "..\..\Include\NexusConfluenceEA\Estrategias.mqh"
#include "..\..\Include\NexusConfluenceEA\RiskManagement_SIMPLE.mqh"

//--- Variáveis globais
datetime g_lastCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   PrintFormat("════════════════════════════════════════════════════════");
   PrintFormat("  🚀 %s v%s - SIMPLIFICADO", EA_NAME, EA_VERSION);
   PrintFormat("════════════════════════════════════════════════════════");
   PrintFormat("📌 Símbolo: %s", _Symbol);
   PrintFormat("📊 Timeframe: %s", EnumToString(_Period));
   PrintFormat("💰 Lote Fixo: %.2f", FixedLotSize);
   PrintFormat("⚠️  Stop Loss: %.0f pontos", SL_Points);
   PrintFormat("🎯 Take Profit: %.0f pontos", TP_Points);
   PrintFormat("🔐 Magic Number: %d", EA_MAGIC_NUMBER);
   PrintFormat("════════════════════════════════════════════════════════");
   
   // Validar inputs básicos
   if(FixedLotSize <= 0)
   {
      PrintFormat("❌ ERRO: Lote fixo deve ser maior que zero!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(SL_Points <= 0 || TP_Points <= 0)
   {
      PrintFormat("❌ ERRO: SL e TP devem ser maiores que zero!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Inicializar indicadores
   if(!InitializeIndicators())
   {
      PrintFormat("❌ ERRO: Falha ao inicializar indicadores!");
      return INIT_FAILED;
   }
   
   PrintFormat("✅ EA inicializado com sucesso!");
   PrintFormat("⏳ Aguardando setup válido...\n");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintFormat("\n════════════════════════════════════════════════════════");
   PrintFormat("  🛑 EA Finalizado - Motivo: %s", GetUninitReasonText(reason));
   PrintFormat("════════════════════════════════════════════════════════");
   
   // Liberar handles dos indicadores
   ReleaseIndicators();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verificar novo candle
   datetime currentCandleTime = iTime(_Symbol, _Period, 0);
   
   if(currentCandleTime == g_lastCandleTime)
      return; // Ainda no mesmo candle
   
   g_lastCandleTime = currentCandleTime;
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 1: VALIDAÇÕES BÁSICAS
   // ═══════════════════════════════════════════════════════════════
   
   // 1.1 Validar dia da semana
   if(!IsValidTradingDay())
   {
      return; // Dia não permitido para trading
   }
   
   // 1.2 Validar horário
   if(!IsValidTradingHour())
   {
      return; // Fora do horário permitido
   }
   
   // 1.3 Verificar se já tem posição aberta
   if(HasOpenPosition())
   {
      return; // Já tem posição aberta
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 2: ANÁLISE DE SETUP
   // ═══════════════════════════════════════════════════════════════
   
   // Analisar setup (usa funções de Estrategias.mqh)
   SetupScore buySetup, sellSetup;
   
   AnalyzeSetup(_Symbol, true, buySetup);   // Análise BUY
   AnalyzeSetup(_Symbol, false, sellSetup); // Análise SELL
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 3: EXECUTAR ORDEM (se setup válido)
   // ═══════════════════════════════════════════════════════════════
   
   bool setupFound = false;
   bool isBuy = false;
   
   // Verificar qual setup é válido
   if(buySetup.classification == SETUP_PREMIUM || buySetup.classification == SETUP_GOOD)
   {
      setupFound = true;
      isBuy = true;
      PrintFormat("\n🔵 SETUP BUY DETECTADO:");
      PrintFormat("   Classificação: %s", 
         (buySetup.classification == SETUP_PREMIUM ? "PREMIUM" : "GOOD"));
      PrintFormat("   Pontos: %d/%d", buySetup.totalPoints, buySetup.requiredPoints);
   }
   else if(sellSetup.classification == SETUP_PREMIUM || sellSetup.classification == SETUP_GOOD)
   {
      setupFound = true;
      isBuy = false;
      PrintFormat("\n🔴 SETUP SELL DETECTADO:");
      PrintFormat("   Classificação: %s", 
         (sellSetup.classification == SETUP_PREMIUM ? "PREMIUM" : "GOOD"));
      PrintFormat("   Pontos: %d/%d", sellSetup.totalPoints, sellSetup.requiredPoints);
   }
   
   // Executar ordem se setup válido
   if(setupFound)
   {
      string comment = StringFormat("Nexus_%s", 
         isBuy ? "BUY" : "SELL");
      
      bool success = ExecuteSimpleTrade(
         _Symbol,
         isBuy,
         FixedLotSize,
         SL_Points,
         TP_Points,
         EA_MAGIC_NUMBER,
         comment
      );
      
      if(success)
      {
         PrintFormat("✅ Ordem executada com sucesso!\n");
      }
      else
      {
         PrintFormat("❌ Falha ao executar ordem\n");
      }
   }
}

//+------------------------------------------------------------------+
//| Valida se é dia permitido para trading                          |
//+------------------------------------------------------------------+
bool IsValidTradingDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   switch(dt.day_of_week)
   {
      case 1: return TradeOnMonday;
      case 2: return TradeOnTuesday;
      case 3: return TradeOnWednesday;
      case 4: return TradeOnThursday;
      case 5: return TradeOnFriday;
      case 6: return TradeOnSaturday;
      case 0: return TradeOnSunday;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Valida se está no horário permitido                             |
//+------------------------------------------------------------------+
bool IsValidTradingHour()
{
   if(!UseCustomTradingHours)
      return true; // Sem restrição de horário
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = CustomStartHour * 60 + CustomStartMinute;
   int endMinutes = CustomEndHour * 60 + CustomEndMinute;
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| Verifica se já tem posição aberta                               |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
         {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Retorna texto do motivo de desinicialização                     |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "Expert removido do gráfico";
      case REASON_REMOVE:      return "Expert removido";
      case REASON_RECOMPILE:   return "Expert recompilado";
      case REASON_CHARTCHANGE: return "Símbolo ou timeframe alterado";
      case REASON_CHARTCLOSE:  return "Gráfico fechado";
      case REASON_PARAMETERS:  return "Parâmetros alterados";
      case REASON_ACCOUNT:     return "Conta alterada";
      case REASON_TEMPLATE:    return "Template aplicado";
      case REASON_INITFAILED:  return "Inicialização falhou";
      case REASON_CLOSE:       return "Terminal fechado";
      default:                 return "Motivo desconhecido";
   }
}
//+------------------------------------------------------------------+
