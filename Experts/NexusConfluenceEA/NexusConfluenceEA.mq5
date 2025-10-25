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
   
   // 🔥 v4.40.5: LOG SIMPLIFICADO - apenas primeira rejeição de cada tipo
   static bool firstTickLogged = false;
   static bool dayRejectLogged = false;
   static bool hourRejectLogged = false;
   static bool positionWaitLogged = false;
   
   if(!firstTickLogged)
   {
      PrintFormat("\n� [v4.40.5] EA INICIANDO ANÁLISE DE VALIDAÇÕES...\n");
      firstTickLogged = true;
   }
   
   // 1.1 Validar dia da semana
   if(!IsValidTradingDay())
   {
      if(!dayRejectLogged)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         PrintFormat("⛔ [BLOQUEIO] Dia da semana inválido! DayOfWeek=%d (%s)", 
                     dt.day_of_week, 
                     dt.day_of_week == 0 ? "Domingo" :
                     dt.day_of_week == 1 ? "Segunda" :
                     dt.day_of_week == 2 ? "Terça" :
                     dt.day_of_week == 3 ? "Quarta" :
                     dt.day_of_week == 4 ? "Quinta" :
                     dt.day_of_week == 5 ? "Sexta" : "Sábado");
         PrintFormat("   CONFIGURAÇÃO: Mon=%s, Tue=%s, Wed=%s, Thu=%s, Fri=%s, Sat=%s, Sun=%s",
                     TradeOnMonday ? "ON" : "OFF",
                     TradeOnTuesday ? "ON" : "OFF",
                     TradeOnWednesday ? "ON" : "OFF",
                     TradeOnThursday ? "ON" : "OFF",
                     TradeOnFriday ? "ON" : "OFF",
                     TradeOnSaturday ? "ON" : "OFF",
                     TradeOnSunday ? "ON" : "OFF");
         dayRejectLogged = true;
      }
      return;
   }
   
   // 1.2 Validar horário
   if(!IsValidTradingHour())
   {
      if(!hourRejectLogged)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         PrintFormat("⛔ [BLOQUEIO] Horário inválido! HoraAtual=%02d:%02d", dt.hour, dt.min);
         PrintFormat("   CONFIGURAÇÃO: UseCustomHours=%s, Start=%02d:%02d, End=%02d:%02d",
                     UseCustomTradingHours ? "YES" : "NO",
                     CustomStartHour, CustomStartMinute,
                     CustomEndHour, CustomEndMinute);
         hourRejectLogged = true;
      }
      return;
   }
   
   // 1.3 Verificar se já tem posição aberta
   if(HasOpenPosition())
   {
      if(!positionWaitLogged)
      {
         PrintFormat("⏳ [AGUARDANDO] Posição já aberta - aguardando fechamento...");
         positionWaitLogged = true;
      }
      return;
   }
   
   // ✅ PASSOU TODAS AS VALIDAÇÕES BÁSICAS!
   static bool validationsPassedLogged = false;
   if(!validationsPassedLogged)
   {
      PrintFormat("\n✅ [SUCESSO] PASSOU TODAS AS VALIDAÇÕES BÁSICAS!");
      PrintFormat("   ✓ Dia da semana: OK");
      PrintFormat("   ✓ Horário: OK");
      PrintFormat("   ✓ Sem posições abertas: OK");
      PrintFormat("\n🔍 Iniciando análise de setup Multi-TF...\n");
      validationsPassedLogged = true;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 2: ANÁLISE DE SETUP
   // ═══════════════════════════════════════════════════════════════
   
   // Classificar ativo
   ASSET_CLASS assetClass = ClassifyAsset(_Symbol);
   
   // Analisar alinhamento multi-timeframe
   MultiTFResult mtf = AnalyzeMultiTimeframeAlignment();
   
   if(!mtf.isValid)
   {
      // 🔥 v4.40.5: Log APENAS primeira rejeição
      static bool mtfRejectLogged = false;
      if(!mtfRejectLogged)
      {
         PrintFormat("\n⛔ [BLOQUEIO] Multi-TF NÃO ALINHADO!");
         PrintFormat("   Verificar função AnalyzeMultiTimeframeAlignment()");
         PrintFormat("   (Esse log aparece apenas 1 vez)\n");
         mtfRejectLogged = true;
      }
      return;
   }
   
   // ✅ Multi-TF PASSOU!
   static bool mtfPassedLogged = false;
   if(!mtfPassedLogged)
   {
      PrintFormat("\n✅ [SUCESSO] Multi-TF ALINHADO!");
      PrintFormat("   Direction: %s\n", mtf.direction == TRADE_DIRECTION_BUY ? "BUY" : "SELL");
      mtfPassedLogged = true;
   }
   
   // Calcular pontuação do setup
   SetupScore score = CalculateSetupScore(_Symbol, assetClass, mtf.direction, mtf.m30Aligned);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 3: EXECUTAR ORDEM (se setup válido)
   // ═══════════════════════════════════════════════════════════════
   
   // Verificar se setup é válido (PREMIUM ou GOOD) - ✅ v4.40.1: LÓGICA APRIMORADA
   bool setupApproved = false;
   string rejectReason = "";
   
   // 1. Verificar classificação base
   if(score.classification == SETUP_REJECT)
   {
      setupApproved = false;
      rejectReason = "Setup REJEITADO por pontuação insuficiente";
   }
   else if(score.classification == SETUP_GOOD && !AllowGoodSetups)
   {
      setupApproved = false;
      rejectReason = "Setup GOOD rejeitado (AllowGoodSetups=false, apenas PREMIUM permitido)";
   }
   else
   {
      // Setup PREMIUM ou GOOD (se permitido)
      setupApproved = true;
      
      // 2. Verificar UseStrictFilters (exige TODOS filtros alinhados)
      if(UseStrictFilters && score.totalPoints < score.requiredPoints)
      {
         setupApproved = false;
         rejectReason = StringFormat("UseStrictFilters=true exige %d/%d pontos (obteve %d/%d)", 
                                    score.requiredPoints, score.requiredPoints, 
                                    score.totalPoints, score.requiredPoints);
      }
      
      // 3. Verificar MinConfluenceScore (score percentual)
      if(setupApproved)
      {
         int scorePercent = (int)((double)score.totalPoints / score.requiredPoints * 100.0);
         if(scorePercent < MinConfluenceScore)
         {
            setupApproved = false;
            rejectReason = StringFormat("Score confluência %d%% < mínimo %d%%", scorePercent, MinConfluenceScore);
         }
      }
   }
   
   if(!setupApproved)
   {
      // � v4.40.5: Log APENAS primeira rejeição
      static bool scoreRejectLogged = false;
      if(!scoreRejectLogged)
      {
         PrintFormat("\n⛔ [BLOQUEIO] %s", rejectReason);
         PrintFormat("   Classification: %s", 
                    (score.classification == SETUP_PREMIUM) ? "PREMIUM" :
                    (score.classification == SETUP_GOOD) ? "GOOD" : "REJECT");
         PrintFormat("   Points: %d/%d (%.0f%%)", score.totalPoints, score.requiredPoints, 
                    (double)score.totalPoints / score.requiredPoints * 100.0);
         PrintFormat("   AllowGoodSetups: %s | UseStrictFilters: %s | MinConfluenceScore: %d%%", 
                    AllowGoodSetups ? "true" : "false",
                    UseStrictFilters ? "true" : "false",
                    MinConfluenceScore);
         PrintFormat("   (Esse log aparece apenas 1 vez)\n");
         scoreRejectLogged = true;
      }
      return; // Setup rejeitado
   }
   
   // 🎯🎯🎯 SETUP APROVADO! VAI EXECUTAR TRADE! 🎯🎯🎯
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