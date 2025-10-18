//+------------------------------------------------------------------+
//| Nexus Confluence EA v4.1 - Sistema Universal Multi-Timeframe     |
//| Baseado no Sistema de Trading Profissional v4.0                  |
//|                                                                  |
//| Descrição: Expert Advisor completo que implementa sistema        |
//| multi-ativo com gestão de risco baseada em estrutura             |
//| NOVO v4.1: Suporte a múltiplos timeframes (M1, M5, M15, M30,    |
//|            H1, H4) com parâmetros independentes                  |
//|                                                                  |
//| Autor: GitHub Copilot                                            |
//| Data: Outubro 2025                                               |
//| Versão: 4.1 - Multi-Timeframe Universal                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ARQUIVO: NexusConfluenceEA.mq5                                   |
//| PROPÓSITO: Execução automatizada do Sistema Nexus Confluence     |
//| DEPENDÊNCIAS: Include/NexusConfluenceEA/*.mqh                    |
//|               Indicators/NexusConfluenceEA/*.mq5                 |
//| VERSÃO: 4.1                                                      |
//+------------------------------------------------------------------+
#property strict

//--- Incluir módulos do EA (ORDEM IMPORTANTE!)
#include <Trade\Trade.mqh>
#include "..\..\Include\NexusConfluenceEA\Parametros.mqh"
#include "..\..\Include\NexusConfluenceEA\Estrategias.mqh"
#include "..\..\Include\NexusConfluenceEA\RiskManagement.mqh"

//--- NOTA: Todos os inputs, enums e structs estão agora em Parametros.mqh
//--- NOTA: Todas as funções de estratégia estão agora em Estrategias.mqh
//--- NOTA: Gestão de risco, SL, TP, Trailing em RiskManagement.mqh


//--- NOTA: Todos os inputs, enums e structs estão agora em Parametros.mqh
//--- NOTA: Todas as funções de estratégia estão agora em Estrategias.mqh

//--- Variáveis globais do EA principal
CTrade g_trade;
double g_initialBalance = 0.0;
bool   g_tradingPaused  = false;
int    g_lastReportMonth = -1;
int    g_lastCleanupDay  = -1;

double g_pointValueCache = 0.0;
ASSET_CLASS g_currentAssetClass = ASSET_CLASS_UNKNOWN;

// Controle de novo candle para evitar análise redundante
datetime g_lastCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("   🎯 INICIANDO %s v%s", EA_NAME, EA_VERSION);
   PrintFormat("════════════════════════════════════════════════════════════════");

   // 1. Detectar timeframe operacional
   ENUM_TIMEFRAMES tfOper = Period();
   PrintFormat("📊 Timeframe Operacional: %s", EnumToString(tfOper));

   // 2. Validar se timeframe é suportado
   if(!IsSupportedTimeframe(tfOper))
     {
      PrintFormat("❌ ERRO: Timeframe %s não é suportado pelo sistema!", EnumToString(tfOper));
      PrintFormat("   Timeframes suportados: M1, M5, M15, M30, H1, H4");
      Alert("Nexus Confluence: Timeframe não suportado! Use M1, M5, M15, M30, H1 ou H4.");
      return INIT_FAILED;
     }

   // 3. Definir timeframes macro conforme TF operacional
   DefineMultiTimeframes(tfOper, g_tfMacro1, g_tfMacro2, g_tfMacro3, g_numNiveisMacro);
   
   PrintFormat("🎯 Sistema Multi-Timeframe definido:");
   PrintFormat("   MACRO-1: %s", EnumToString(g_tfMacro1));
   PrintFormat("   MACRO-2: %s", EnumToString(g_tfMacro2));
   if(g_numNiveisMacro == 3)
      PrintFormat("   MACRO-3: %s", EnumToString(g_tfMacro3));
   else
      PrintFormat("   MACRO-3: N/A (sistema de 2 níveis)");
   PrintFormat("   OPERACIONAL: %s", EnumToString(tfOper));

   // 4. Classificar ativo atual
   g_currentAssetClass = ClassifyAsset(_Symbol);
   PrintFormat("📈 Ativo %s classificado como: %s", _Symbol, AssetClassToString(g_currentAssetClass));

   if(g_currentAssetClass == ASSET_CLASS_UNKNOWN)
     {
      PrintFormat("❌ ERRO: Ativo %s não pôde ser classificado!", _Symbol);
      Alert("Nexus Confluence: Ativo desconhecido!");
      return INIT_FAILED;
     }

   // 5. Validar parâmetros de entrada
   if(!ValidateInputParameters())
     {
      PrintFormat("❌ ERRO: Parâmetros inválidos!");
      return INIT_PARAMETERS_INCORRECT;
     }

   // 6. Inicializar todos os indicadores
   if(!InitializeIndicators(_Symbol))
     {
      PrintFormat("❌ ERRO: Falha ao inicializar indicadores!");
      Alert("Nexus Confluence: Erro ao inicializar indicadores. Verifique os logs.");
      return INIT_FAILED;
     }

   // 7. Configurar trade object
   g_trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(MaxSlippagePoints);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetAsyncMode(false);

   // 8. Salvar saldo inicial
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   PrintFormat("💰 Saldo inicial: %.2f", g_initialBalance);

   // 9. Configurar timer (1 hora)
   EventSetTimer(3600);

   // 10. Exibir configuração final
   PrintConfiguration();

   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("   ✅ EA INICIALIZADO COM SUCESSO!");
   PrintFormat("════════════════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
  }


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("   🔴 FINALIZANDO %s v%s", EA_NAME, EA_VERSION);
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📋 Razão: %s", GetDeinitReasonText(reason));

   // Liberar todos os handles dos indicadores
   ReleaseIndicators();

   // Cancelar timer
   EventKillTimer();

   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("   ✅ EA FINALIZADO COM SUCESSO");
   PrintFormat("════════════════════════════════════════════════════════════════");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // ═══════════════════════════════════════════════════════════════
   // VERIFICAÇÃO CRÍTICA: Só executar em NOVO CANDLE
   // ═══════════════════════════════════════════════════════════════
   datetime currentCandleTime = iTime(_Symbol, Period(), 0);
   
   // Se ainda é o mesmo candle, NÃO processar (evita logs por segundo)
   if(currentCandleTime == g_lastCandleTime)
   {
      return; // Aguardar próximo candle
   }
   
   // Novo candle detectado! Atualizar timestamp
   g_lastCandleTime = currentCandleTime;
   
   PrintFormat("\n🕐 NOVO CANDLE %s: %s", 
               EnumToString(Period()), 
               TimeToString(currentCandleTime, TIME_DATE|TIME_MINUTES));
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // ETAPA 1: Validações básicas de segurança
   if(!ValidateBasicConditions())
      return;

   // ETAPA 2: Análise multi-timeframe OBRIGATÓRIA
   MultiTFResult mtf = AnalyzeMultiTimeframeAlignment();
   if(!mtf.isValid)
     {
      // MACRO-1 e MACRO-2 não alinhados ou indecisos
      return;
     }

   // ETAPA 3: Calcular pontuação dos filtros micro
   SetupScore score = CalculateSetupScore(_Symbol, g_currentAssetClass, mtf.direction, mtf.m30Aligned);

   // ETAPA 4: Validar classificação do setup
   if(score.classification == SETUP_REJECT)
     {
      // Não atingiu confluência mínima
      return;
     }

   // ETAPA 5: Validar condições de mercado (spread, ATR, etc)
   if(!ValidateMarketConditions(_Symbol, g_currentAssetClass))
      return;

   // ETAPA 6: Verificar se já não temos trades demais
   if(CountOpenTrades() >= MaxSimultaneousTrades)
      return;

   // ETAPA 7: Calcular risco e tamanho da posição
   RiskCalculation risk = CalculateRiskPosition(_Symbol, score, mtf.direction, g_currentAssetClass);
   if(!risk.isValid)
     {
      if(risk.errorMessage != "")
         PrintFormat("⚠️ Risco inválido: %s", risk.errorMessage);
      return;
     }

   // ETAPA 8: Executar trade
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("🎯 SETUP %s DETECTADO!", (score.classification == SETUP_PREMIUM) ? "PREMIUM" : "GOOD");
   PrintFormat("   Símbolo: %s", _Symbol);
   PrintFormat("   Direção: %s", (mtf.direction == TRADE_DIRECTION_BUY) ? "COMPRA" : "VENDA");
   PrintFormat("   Pontuação: %d/%d", score.totalPoints, score.requiredPoints);
   PrintFormat("   Risco: %.2f%% (%.2f)", 
               (score.classification == SETUP_PREMIUM) ? MaxRiskPremium : AccountRiskPercent,
               risk.riskAmount);
   PrintFormat("════════════════════════════════════════════════════════════════");

   ExecuteTrade(_Symbol, mtf.direction, risk, score.classification);
  }


//+------------------------------------------------------------------+
//| Verifica se o timeframe é suportado                             |
//+------------------------------------------------------------------+
bool IsSupportedTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M1 || tf == PERIOD_M5 || tf == PERIOD_M15 ||
           tf == PERIOD_M30 || tf == PERIOD_H1 || tf == PERIOD_H4);
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
//| Converter classe de ativo para string                           |
//+------------------------------------------------------------------+
string AssetClassToString(ASSET_CLASS cls)
  {
   switch(cls)
     {
      case ASSET_CLASS_FOREX_MAJOR: return "Forex Major";
      case ASSET_CLASS_FOREX_MINOR: return "Forex Minor";
      case ASSET_CLASS_FOREX_EXOTIC: return "Forex Exotic";
      case ASSET_CLASS_CURRENCY_B3: return "WDO (Mini Dólar B3)";
      case ASSET_CLASS_INDEX_B3: return "WIN (Mini Índice B3)";
      case ASSET_CLASS_INDEX_US: return "Índice US";
      case ASSET_CLASS_INDEX_EU: return "Índice Europa";
      case ASSET_CLASS_METALS: return "Metais (Ouro/Prata)";
      case ASSET_CLASS_CRYPTO: return "Criptomoedas";
      default: return "Desconhecido";
     }
  }


//+------------------------------------------------------------------+
//| Validações básicas antes de cada tick                           |
//+------------------------------------------------------------------+
bool ValidateBasicConditions()
  {
   // 1. Verificar se trading está habilitado
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;

   // 2. Verificar conexão
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   // 3. Verificar se está em horário de trading
   if(!IsValidTradingTime())
      return false;

   // 4. Verificar drawdown máximo
   if(g_tradingPaused)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentDrawdown = (g_initialBalance - equity) / g_initialBalance * 100.0;
   if(currentDrawdown >= MaxDrawdownPercent)
     {
      g_tradingPaused = true;
      PrintFormat("❌ TRADING PAUSADO: Drawdown %.2f%% >= %.2f%%", currentDrawdown, MaxDrawdownPercent);
      Alert("Nexus Confluence: Drawdown máximo atingido! Trading pausado.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Verifica se está em horário de trading                          |
//+------------------------------------------------------------------+
bool IsValidTradingTime()
  {
   // Verificar dia da semana
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   switch(dt.day_of_week)
     {
      case 1: if(!TradeOnMonday) return false; break;
      case 2: if(!TradeOnTuesday) return false; break;
      case 3: if(!TradeOnWednesday) return false; break;
      case 4: if(!TradeOnThursday) return false; break;
      case 5: if(!TradeOnFriday) return false; break;
      case 6: if(!TradeOnSaturday) return false; break;
      case 0: if(!TradeOnSunday) return false; break;
     }

   // Se usar horários customizados
   if(UseCustomTradingHours)
     {
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes = CustomStartHour * 60 + CustomStartMinute;
      int endMinutes = CustomEndHour * 60 + CustomEndMinute;
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
     }

   // TODO: Implementar validação de horários por classe de ativo
   return true;
  }

//+------------------------------------------------------------------+
//| Valida condições de mercado (spread, ATR, etc)                  |
//+------------------------------------------------------------------+
bool ValidateMarketConditions(const string symbol, ASSET_CLASS assetClass)
  {
   // Verificar spread com multiplicador configurável
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double baseMaxSpread = GetMaxSpread(assetClass);
   double maxSpread = baseMaxSpread * MaxSpreadMultiplier; // Aplicar multiplicador

   if(spread > maxSpread)
     {
      PrintFormat("⚠️ Spread muito alto: %.5f > %.5f (base: %.5f x multiplicador: %.1f)", 
                  spread, maxSpread, baseMaxSpread, MaxSpreadMultiplier);
      return false;
     }
   
   PrintFormat("   ✅ Spread OK: %.5f <= %.5f", spread, maxSpread);

   // TODO: Validar ATR se ValidateATRRange = true

   return true;
  }

//+------------------------------------------------------------------+
//| Retorna spread máximo permitido por classe                      |
//+------------------------------------------------------------------+
double GetMaxSpread(ASSET_CLASS assetClass)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   switch(assetClass)
     {
      case ASSET_CLASS_FOREX_MAJOR: return 2.0 * point * 10;    // 2 pips
      case ASSET_CLASS_FOREX_MINOR: return 3.0 * point * 10;    // 3 pips
      case ASSET_CLASS_FOREX_EXOTIC: return 15.0 * point * 10;  // 15 pips
      case ASSET_CLASS_INDEX_B3: return 15.0 * point;           // 15 pontos
      case ASSET_CLASS_CURRENCY_B3: return 3.0 * point;         // 3 pontos
      case ASSET_CLASS_METALS: return 1.0 * point;              // $1
      default: return 5.0 * point * 10;
     }
  }

//+------------------------------------------------------------------+
//| Conta trades abertos do EA                                      |
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol)
        {
         if(PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
            count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Calcula risco e tamanho da posição                              |
//+------------------------------------------------------------------+
RiskCalculation CalculateRiskPosition(string symbol, const SetupScore &score, TRADE_DIRECTION direction, ASSET_CLASS assetClass)
  {
   // USAR NOVO MÓDULO DE GESTÃO DE RISCO
   RiskCalculation result = CalculatePositionSize(symbol, direction, score.classification);
   
   if(!result.isValid)
   {
      return result;
   }
   
   // Validar cálculo
   if(!ValidateRiskCalculation(result, symbol))
   {
      result.isValid = false;
      result.errorMessage = "Validação de risco falhou";
      return result;
   }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Executa trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, TRADE_DIRECTION direction, const RiskCalculation &risk, SETUP_CLASS classification)
  {
   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = risk.positionSize;
   request.type = (direction == TRADE_DIRECTION_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (direction == TRADE_DIRECTION_BUY) ?
                   SymbolInfoDouble(symbol, SYMBOL_ASK) :
                   SymbolInfoDouble(symbol, SYMBOL_BID);
   request.sl = risk.stopLoss;       // ✅ Usar SL calculado
   request.tp = risk.takeProfit1;    // ✅ Usar TP1 inicialmente
   request.deviation = MaxSlippagePoints;
   request.magic = EA_MAGIC_NUMBER;
   request.comment = StringFormat("Nexus_%s_%s",
                                   (direction == TRADE_DIRECTION_BUY) ? "BUY" : "SELL",
                                   (classification == SETUP_PREMIUM) ? "PREMIUM" : "GOOD");

   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📤 ENVIANDO ORDEM AO MERCADO");
   PrintFormat("   Tipo: %s", (direction == TRADE_DIRECTION_BUY) ? "BUY" : "SELL");
   PrintFormat("   Volume: %.2f lotes", request.volume);
   PrintFormat("   Preço: %.5f", request.price);
   PrintFormat("   Stop Loss: %.5f", request.sl);
   PrintFormat("   Take Profit: %.5f", request.tp);
   PrintFormat("════════════════════════════════════════════════════════════════");

   if(!OrderSend(request, result))
     {
      PrintFormat("❌ Erro ao abrir trade: %d - %s", result.retcode, result.comment);
      PrintFormat("   Detalhes do erro:");
      PrintFormat("   - Retcode: %d", result.retcode);
      PrintFormat("   - Deal: %I64u", result.deal);
      PrintFormat("   - Order: %I64u", result.order);
      PrintFormat("   - Volume: %.2f", result.volume);
      PrintFormat("   - Price: %.5f", result.price);
      PrintFormat("   - Bid: %.5f", result.bid);
      PrintFormat("   - Ask: %.5f", result.ask);
      return;
     }

   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("✅ TRADE ABERTO COM SUCESSO!");
   PrintFormat("   Ticket: %I64u", result.order);
   PrintFormat("   Deal: %I64u", result.deal);
   PrintFormat("   Volume: %.2f lotes", result.volume);
   PrintFormat("   Preço executado: %.5f", result.price);
   PrintFormat("   Classificação: %s", (classification == SETUP_PREMIUM) ? "🏆 PREMIUM" : "⭐ GOOD");
   PrintFormat("════════════════════════════════════════════════════════════════");

   if(SendAlerts)
     {
      SendNotification(StringFormat("Nexus: %s %s aberto em %.5f (Ticket: %I64u)",
                                     (direction == TRADE_DIRECTION_BUY) ? "COMPRA" : "VENDA",
                                     symbol,
                                     result.price,
                                     result.order));
     }
  }

//+------------------------------------------------------------------+
//| Validar parâmetros de entrada                                   |
//+------------------------------------------------------------------+
bool ValidateInputParameters()
  {
   if(AccountRiskPercent <= 0 || AccountRiskPercent > 10)
     {
      PrintFormat("❌ AccountRiskPercent inválido: %.2f (deve ser 0-10%%)", AccountRiskPercent);
      return false;
     }

   if(MaxRiskPremium <= 0 || MaxRiskPremium > 10)
     {
      PrintFormat("❌ MaxRiskPremium inválido: %.2f (deve ser 0-10%%)", MaxRiskPremium);
      return false;
     }

   if(MaxDrawdownPercent <= 0 || MaxDrawdownPercent > 50)
     {
      PrintFormat("❌ MaxDrawdownPercent inválido: %.2f (deve ser 0-50%%)", MaxDrawdownPercent);
      return false;
     }

   if(MaxSimultaneousTrades <= 0 || MaxSimultaneousTrades > 10)
     {
      PrintFormat("❌ MaxSimultaneousTrades inválido: %d (deve ser 1-10)", MaxSimultaneousTrades);
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Exibir configuração final                                       |
//+------------------------------------------------------------------+
void PrintConfiguration()
  {
   PrintFormat("📋 Configuração do EA:");
   PrintFormat("   Risco padrão: %.2f%%", AccountRiskPercent);
   PrintFormat("   Risco Premium: %.2f%%", MaxRiskPremium);
   PrintFormat("   Drawdown máximo: %.2f%%", MaxDrawdownPercent);
   PrintFormat("   Trades simultâneos: %d", MaxSimultaneousTrades);
   PrintFormat("   Lote fixo: %.2f (0 = auto)", FixedLotSize);
   PrintFormat("   Alertas: %s", SendAlerts ? "SIM" : "NÃO");
   PrintFormat("   TP parcial: %s", EnablePartialTP ? "SIM" : "NÃO");
   PrintFormat("   Trailing: %s", EnableTrailing ? "SIM" : "NÃO");
  }

//+------------------------------------------------------------------+
//| Retorna texto descritivo da razão de deinit                     |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
  {
   switch(reason)
     {
      case REASON_PROGRAM: return "EA foi parado manualmente";
      case REASON_REMOVE: return "EA foi removido do gráfico";
      case REASON_RECOMPILE: return "EA foi recompilado";
      case REASON_CHARTCHANGE: return "Símbolo ou período mudou";
      case REASON_CHARTCLOSE: return "Gráfico foi fechado";
      case REASON_PARAMETERS: return "Parâmetros foram alterados";
      case REASON_ACCOUNT: return "Conta foi alterada";
      case REASON_TEMPLATE: return "Template foi aplicado";
      case REASON_INITFAILED: return "OnInit() retornou erro";
      case REASON_CLOSE: return "Terminal foi fechado";
      default: return StringFormat("Razão desconhecida (%d)", reason);
     }
  }

//+------------------------------------------------------------------+
//| Limpeza de logs antigos (placeholder)                           |
//+------------------------------------------------------------------+
void CleanupOldLogs()
  {
   // TODO: Implementar limpeza de logs
  }

//+------------------------------------------------------------------+
//| Validação de integridade do sistema (placeholder)               |
//+------------------------------------------------------------------+
void ValidateSystemIntegrity()
  {
   // TODO: Implementar validações periódicas
  }

//+------------------------------------------------------------------+
