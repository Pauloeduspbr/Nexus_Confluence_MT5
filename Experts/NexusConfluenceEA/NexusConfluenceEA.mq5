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
#property copyright "Nexus Confluence EA v4.40"
#property version   "4.40"

//--- Incluir módulos SIMPLIFICADOS
#include <Trade\Trade.mqh>
#include "..\..\Include\NexusConfluenceEA\Parametros.mqh"
#include "..\..\Include\NexusConfluenceEA\Estrategias.mqh"
#include "..\..\Include\NexusConfluenceEA\RiskManagement.mqh"

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
   
   // 🔥 v4.40 CORREÇÃO CRÍTICA: Definir timeframes multi-TF ANTES de inicializar indicadores
   ENUM_TIMEFRAMES tfM1, tfM2, tfM3;
   int numNiveisMacro;
   DefineMultiTimeframes(_Period, tfM1, tfM2, tfM3, numNiveisMacro);
   
   PrintFormat("🎯 Timeframes Multi-TF Definidos:");
   PrintFormat("   MACRO-1: %s", EnumToString(tfM1));
   PrintFormat("   MACRO-2: %s", EnumToString(tfM2));
   if(numNiveisMacro == 3)
      PrintFormat("   MACRO-3: %s", EnumToString(tfM3));
   PrintFormat("   Níveis: %d", numNiveisMacro);
   
   // Inicializar indicadores
   if(!InitializeIndicators(_Symbol))
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
   // ETAPA 0: ATUALIZAR BUFFER CACHE (1x por candle novo)
   // ═══════════════════════════════════════════════════════════════
   
   // 🔥 v4.40 CORREÇÃO CRÍTICA #2: Atualizar cache ANTES de analisar indicadores
   if(!UpdateBufferCache())
   {
      // Se cache falhar, não analisar (evitar trades com dados incorretos)
      PrintFormat("🔴 CRÍTICO: Buffer cache inválido - pulando análise neste candle");
      return;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 1: VALIDAÇÕES BÁSICAS
   // ═══════════════════════════════════════════════════════════════
   
   // 🔥 DEBUG v4.40.4: Contador de ticks processados
   static int tickCount = 0;
   tickCount++;
   if(tickCount % 1000 == 0)
   {
      PrintFormat("🔍 [DEBUG] OnTick() processou %d ticks", tickCount);
   }
   
   // 1.1 Validar dia da semana
   static int dayRejectCount = 0;
   if(!IsValidTradingDay())
   {
      dayRejectCount++;
      if(dayRejectCount % 1000 == 0)
      {
         PrintFormat("⚠️ [DEBUG] Dia inválido rejeitado %d vezes", dayRejectCount);
      }
      return;
   }
   
   // 1.2 Validar horário
   static int hourRejectCount = 0;
   if(!IsValidTradingHour())
   {
      hourRejectCount++;
      if(hourRejectCount % 1000 == 0)
      {
         PrintFormat("⚠️ [DEBUG] Horário inválido rejeitado %d vezes", hourRejectCount);
      }
      return;
   }
   
   // 1.3 Verificar se já tem posição aberta
   static int positionRejectCount = 0;
   if(HasOpenPosition())
   {
      positionRejectCount++;
      if(positionRejectCount % 100 == 0)
      {
         PrintFormat("⚠️ [DEBUG] Posição aberta detectada %d vezes (aguardando fechamento)", positionRejectCount);
      }
      return;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 2: ANÁLISE DE SETUP
   // ═══════════════════════════════════════════════════════════════
   
   // 🔥 DEBUG v4.40.3: Log a cada 100 candles para ver se chega aqui
   static int analysisCount = 0;
   analysisCount++;
   if(analysisCount % 100 == 0)
   {
      PrintFormat("🔍 [DEBUG] Análise de setup rodando - %d análises realizadas", analysisCount);
   }
   
   // Classificar ativo
   ASSET_CLASS assetClass = ClassifyAsset(_Symbol);
   
   // Analisar alinhamento multi-timeframe
   MultiTFResult mtf = AnalyzeMultiTimeframeAlignment();
   
   if(!mtf.isValid)
   {
      // 🔥 DEBUG v4.40.3: Log DETALHADO do motivo da rejeição
      static int rejectCount = 0;
      rejectCount++;
      if(rejectCount % 100 == 0)
      {
         PrintFormat("⚠️ [DEBUG] Multi-TF rejeitado %d vezes - verificar AnalyzeMultiTimeframeAlignment()", rejectCount);
      }
      return;
   }
   
   // Calcular pontuação do setup
   SetupScore score = CalculateSetupScore(_Symbol, assetClass, mtf.direction, mtf.m30Aligned);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 3: EXECUTAR ORDEM (se setup válido)
   // ═══════════════════════════════════════════════════════════════
   
   // 🔥 DEBUG v4.40.3: Log da pontuação antes de verificar
   static int scoreCalcCount = 0;
   scoreCalcCount++;
   if(scoreCalcCount % 100 == 0)
   {
      PrintFormat("🔍 [DEBUG] Score calculado #%d - Class: %d, Points: %d/%d", 
                  scoreCalcCount, score.classification, score.totalPoints, score.requiredPoints);
   }
   
   // Verificar se setup é válido (PREMIUM ou GOOD)
   if(score.classification != SETUP_PREMIUM && score.classification != SETUP_GOOD)
   {
      // 🔥 DEBUG v4.40.3: Log rejeições por classificação
      static int classRejectCount = 0;
      classRejectCount++;
      if(classRejectCount % 50 == 0)
      {
         PrintFormat("⚠️ [DEBUG] Setup rejeitado %d vezes - Last classification: %d", 
                     classRejectCount, score.classification);
      }
      return; // Setup rejeitado
   }
   
   // 🎯 DEBUG v4.40.3: LOG CRÍTICO - SETUP APROVADO!
   PrintFormat("\n🎯🎯🎯 [CRITICAL] SETUP APROVADO! VAI EXECUTAR TRADE AGORA! 🎯🎯🎯");
   
   // Determinar direção
   bool isBuy = (mtf.direction == TRADE_DIRECTION_BUY);
   
   PrintFormat("\n%s SETUP %s DETECTADO:",
      isBuy ? "🔵" : "🔴",
      (score.classification == SETUP_PREMIUM ? "PREMIUM" : "GOOD"));
   PrintFormat("   Pontos: %d/%d", score.totalPoints, score.requiredPoints);
   
   // Executar ordem
   string comment = StringFormat("Nexus_%s_%s", 
      isBuy ? "BUY" : "SELL",
      (score.classification == SETUP_PREMIUM ? "PREMIUM" : "GOOD"));
   
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
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
         
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      
      if(posSymbol == _Symbol && magic == EA_MAGIC_NUMBER)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Classifica o ativo atual                                        |
//+------------------------------------------------------------------+
ASSET_CLASS ClassifyAsset(const string symbol)
{
   string sym = symbol;
   StringToUpper(sym);

   // Metais
   if(sym == "XAUUSD" || sym == "XAGUSD" || StringFind(sym,"XAU") == 0 || StringFind(sym,"XAG") == 0)
      return ASSET_CLASS_METALS;

   // B3 Brasil
   if(StringFind(sym,"WIN") == 0 || StringFind(sym,"IND") == 0)
      return ASSET_CLASS_INDEX_B3;
   if(StringFind(sym,"WDO") == 0 || StringFind(sym,"DOL") == 0)
      return ASSET_CLASS_CURRENCY_B3;

   // Índices US
   if(StringFind(sym,"US500") == 0 || StringFind(sym,"NAS100") == 0 || StringFind(sym,"US30") == 0)
      return ASSET_CLASS_INDEX_US;

   // Índices Europa
   if(StringFind(sym,"GER") == 0 || StringFind(sym,"UK") == 0 || StringFind(sym,"FRA") == 0)
      return ASSET_CLASS_INDEX_EU;

   // Crypto
   if(StringFind(sym,"BTC") == 0 || StringFind(sym,"ETH") == 0)
      return ASSET_CLASS_CRYPTO;

   // Forex
   if(StringLen(sym) >= 6)
   {
      if(StringFind(sym,"USD") >= 0)
      {
         if(sym == "EURUSD" || sym == "GBPUSD" || sym == "USDJPY" ||
            sym == "AUDUSD" || sym == "NZDUSD" || sym == "USDCHF" || sym == "USDCAD")
            return ASSET_CLASS_FOREX_MAJOR;

         if(StringFind(sym,"BRL") >= 0 || StringFind(sym,"MXN") >= 0 || StringFind(sym,"ZAR") >= 0)
            return ASSET_CLASS_FOREX_EXOTIC;

         return ASSET_CLASS_FOREX_MINOR;
      }
      else
      {
         return ASSET_CLASS_FOREX_MINOR;
      }
   }

   return ASSET_CLASS_UNKNOWN;
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