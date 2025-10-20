//+------------------------------------------------------------------+
//| Nexus Confluence EA v4.15 - Sistema Universal Multi-Timeframe    |
//| Baseado no Sistema de Trading Profissional v4.0                  |
//|                                                                  |
//| Descrição: Expert Advisor completo que implementa sistema        |
//| multi-ativo com gestão de risco baseada em estrutura             |
//| NOVO v4.1: Suporte a múltiplos timeframes (M1, M5, M15, M30,    |
//|            H1, H4) com parâmetros independentes                  |
//| NOVO v4.11: Correção crítica SL + Gestão de posições            |
//| NOVO v4.12: Supertrend obrigatório + Hierarquia otimizada       |
//| NOVO v4.13: Magic Number INPUT + Limpeza total indicadores      |
//| 🔥 v4.14: CORREÇÃO LÓGICA SUPERTREND (DBL_MAX)                 |
//| 🔥 v4.15: CORREÇÕES CRÍTICAS BACKTEST                          |
//|   - Risco reduzido: 0.5-1% (era 1.5-2%)                        |
//|   - Apenas setups PREMIUM (3/3 filtros)                         |
//|   - Proteção drawdown diário/semanal                            |
//|   - Breakeven apenas após TP1 fechado                           |
//|   - Trailing dinâmico 2.5x ATR                                 |
//|   - Horários Londres/NY overlap apenas                          |
//|                                                                  |
//| Autor: GitHub Copilot                                            |
//| Data: Outubro 2025                                               |
//| Versão: 4.15 - Correções Análise Crítica Backtest              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ARQUIVO: NexusConfluenceEA.mq5                                   |
//| PROPÓSITO: Execução automatizada do Sistema Nexus Confluence     |
//| DEPENDÊNCIAS: Include/NexusConfluenceEA/*.mqh                    |
//|               Indicators/NexusConfluenceEA/*.mq5                 |
//| VERSÃO: 4.13                                                     |
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
double g_initialBalance = 0.0;      // Balance inicial (apenas referência)

double g_pointValueCache = 0.0;
ASSET_CLASS g_currentAssetClass = ASSET_CLASS_UNKNOWN;

// Controle de novo candle para evitar análise redundante
datetime g_lastCandleTime = 0;

// 🔥 v4.15: Variáveis de controle de drawdown
double g_dailyStartBalance    = 0.0;      // Balance início do dia
double g_weeklyStartBalance   = 0.0;      // Balance início da semana
int    g_consecutiveLosses    = 0;        // Contador de perdas consecutivas
datetime g_lastTradeCloseTime = 0;        // Última vez que trade fechou
datetime g_pauseUntilTime     = 0;        // Pausado até (timestamp)
bool   g_dailyDrawdownHit     = false;    // Flag drawdown diário atingido
bool   g_weeklyDrawdownHit    = false;    // Flag drawdown semanal atingido

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
      PrintFormat("❌ DEBUG ETAPA 2: Multi-timeframe NÃO ALINHADO - MACRO-1 e MACRO-2 indecisos ou opostos");
      return;
     }
   PrintFormat("✅ DEBUG ETAPA 2: Multi-timeframe ALINHADO - Direção: %s", 
               (mtf.direction == TRADE_DIRECTION_BUY) ? "COMPRA" : "VENDA");

   // ETAPA 3: Calcular pontuação dos filtros micro
   SetupScore score = CalculateSetupScore(_Symbol, g_currentAssetClass, mtf.direction, mtf.m30Aligned);
   PrintFormat("📊 DEBUG ETAPA 3: Setup calculado - Pontos: %d/%d | Classificação: %s",
               score.totalPoints, score.requiredPoints,
               (score.classification == SETUP_PREMIUM) ? "PREMIUM" : 
               (score.classification == SETUP_GOOD) ? "GOOD" : "REJECT");

   // ETAPA 4: Validar classificação do setup
   if(score.classification == SETUP_REJECT)
     {
      // Não atingiu confluência mínima
      PrintFormat("❌ DEBUG ETAPA 4: Setup REJEITADO - Pontos insuficientes (%d/%d)", 
                  score.totalPoints, score.requiredPoints);
      return;
     }
   
   // 🔥 v4.15: FILTRO PREMIUM - Operar apenas setups PREMIUM (3/3 filtros)
   if(!AllowGoodSetups && score.classification != SETUP_PREMIUM)
     {
      PrintFormat("⚠️ DEBUG ETAPA 4: Setup GOOD rejeitado - Apenas PREMIUM permitido (AllowGoodSetups=false)");
      PrintFormat("   📊 Pontos: %d/%d | Para operar GOOD, altere AllowGoodSetups=true", 
                  score.totalPoints, score.requiredPoints);
      return;
     }
   
   PrintFormat("✅ DEBUG ETAPA 4: Setup APROVADO - %s", 
               (score.classification == SETUP_PREMIUM) ? "PREMIUM" : "GOOD");

   // ETAPA 5: Validar condições de mercado (spread, ATR, etc)
   if(!ValidateMarketConditions(_Symbol, g_currentAssetClass))
     {
      PrintFormat("❌ DEBUG ETAPA 5: Condições de mercado INVÁLIDAS - Spread ou ATR fora do range");
      return;
     }
   PrintFormat("✅ DEBUG ETAPA 5: Condições de mercado VÁLIDAS");

   // ETAPA 6: CONTROLE DE POSIÇÕES - Verificar modo configurado
   int openPositions = CountOpenTrades();
   PrintFormat("🔢 DEBUG ETAPA 6: Posições abertas: %d | Modo: %s | Limite: %d",
               openPositions, 
               (PositionControlMode == POSITION_MODE_SINGLE) ? "SINGLE" :
               (PositionControlMode == POSITION_MODE_MULTIPLE) ? "MULTIPLE" : "PROTECTED",
               MaxSimultaneousTrades);
   
   switch(PositionControlMode)
   {
      case POSITION_MODE_SINGLE:
         // ✅ Apenas 1 posição por vez
         if(openPositions > 0)
         {
            PrintFormat("❌ DEBUG ETAPA 6: Modo SINGLE bloqueou - %d posição(ões) aberta(s)", openPositions);
            PrintFormat("⏸️ Modo SINGLE: Já existe %d posição(ões) aberta(s), aguardando fechamento", openPositions);
            return;
         }
         break;
         
      case POSITION_MODE_MULTIPLE:
         // ✅ Múltiplas posições até limite máximo
         if(openPositions >= MaxSimultaneousTrades)
         {
            PrintFormat("❌ DEBUG ETAPA 6: Modo MULTIPLE bloqueou - Limite %d atingido", MaxSimultaneousTrades);
            PrintFormat("⏸️ Modo MULTIPLE: Limite de %d posições atingido", MaxSimultaneousTrades);
            return;
         }
         break;
         
      case POSITION_MODE_PROTECTED:
         // ✅ Múltiplas posições até limite configurado
         if(openPositions >= MaxSimultaneousTrades)
         {
            PrintFormat("❌ DEBUG ETAPA 6: Modo PROTECTED bloqueou - Limite %d atingido", MaxSimultaneousTrades);
            PrintFormat("⏸️ Modo PROTECTED: Limite de %d posições atingido", MaxSimultaneousTrades);
            return;
         }
         break;
   }
   PrintFormat("✅ DEBUG ETAPA 6: Controle de posições OK - Pode abrir nova posição");

   // ETAPA 7: Calcular risco e tamanho da posição
   RiskCalculation risk = CalculateRiskPosition(_Symbol, score, mtf.direction, g_currentAssetClass);
   if(!risk.isValid)
     {
      if(risk.errorMessage != "")
         PrintFormat("❌ DEBUG ETAPA 7: Risco INVÁLIDO - %s", risk.errorMessage);
      else
         PrintFormat("❌ DEBUG ETAPA 7: Risco INVÁLIDO - Sem mensagem de erro");
      return;
     }
   PrintFormat("✅ DEBUG ETAPA 7: Risco CALCULADO - Lote: %.2f | SL: %.5f | Risco: %.2f", 
               risk.positionSize, risk.stopLoss, risk.riskAmount);

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
   
   // ETAPA 9: GESTÃO DE TRADES EXISTENTES (v4.11)
   ManageExistingTrades();
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
   // 🔥 v4.15: NOVA VALIDAÇÃO - Proteção de Drawdown
   if(!ValidateDrawdownProtection())
     {
      PrintFormat("🛡️ VALIDAÇÃO FALHOU: Proteção de drawdown ativa");
      return false;
     }
   
   // 1. Verificar se trading está habilitado
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      PrintFormat("❌ VALIDAÇÃO FALHOU: Trading não permitido no terminal");
      return false;
     }

   // 2. Verificar conexão
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      PrintFormat("❌ VALIDAÇÃO FALHOU: Terminal desconectado");
      return false;
     }

   // 3. Verificar se está em horário de trading
   if(!IsValidTradingTime())
     {
      PrintFormat("⏰ VALIDAÇÃO FALHOU: Fora do horário de trading");
      return false;
     }

   PrintFormat("✅ Validações básicas OK");
   return true;
  }

//+------------------------------------------------------------------+
//| 🔥 v4.15: NOVA - Validar proteção de drawdown                   |
//+------------------------------------------------------------------+
bool ValidateDrawdownProtection()
  {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Verificar se está pausado por perdas consecutivas
   if(TimeCurrent() < g_pauseUntilTime)
     {
      PrintFormat("⏸️ EA PAUSADO até %s (perdas consecutivas: %d)", 
                  TimeToString(g_pauseUntilTime, TIME_DATE|TIME_MINUTES), 
                  g_consecutiveLosses);
      return false;
     }
   
   // Resetar contadores no início do dia (00:00)
   if(dt.hour == 0 && dt.min == 0)
     {
      MqlDateTime dtYesterday;
      TimeToStruct(TimeCurrent() - 86400, dtYesterday);
      
      if(g_dailyStartBalance == 0.0 || dt.day != dtYesterday.day)
        {
         g_dailyStartBalance = currentBalance;
         g_dailyDrawdownHit = false;
         PrintFormat("📅 Novo dia: Balance inicial = %.2f", g_dailyStartBalance);
        }
     }
   
   // Resetar contadores no início da semana (Segunda 00:00)
   if(dt.day_of_week == 1 && dt.hour == 0 && dt.min == 0)
     {
      MqlDateTime dtLastWeek;
      TimeToStruct(TimeCurrent() - 604800, dtLastWeek);
      
      if(g_weeklyStartBalance == 0.0 || dt.day != dtLastWeek.day)
        {
         g_weeklyStartBalance = currentBalance;
         g_weeklyDrawdownHit = false;
         g_consecutiveLosses = 0;
         PrintFormat("📅 Nova semana: Balance inicial = %.2f", g_weeklyStartBalance);
        }
     }
   
   // Inicializar se primeira execução
   if(g_dailyStartBalance == 0.0) g_dailyStartBalance = currentBalance;
   if(g_weeklyStartBalance == 0.0) g_weeklyStartBalance = currentBalance;
   
   // Calcular drawdowns
   double dailyDD = ((g_dailyStartBalance - currentBalance) / g_dailyStartBalance) * 100.0;
   double weeklyDD = ((g_weeklyStartBalance - currentBalance) / g_weeklyStartBalance) * 100.0;
   
   // Verificar drawdown diário
   if(dailyDD >= MaxDailyDrawdown)
     {
      if(!g_dailyDrawdownHit)
        {
         g_dailyDrawdownHit = true;
         string msg = StringFormat("🚨 DRAWDOWN DIÁRIO ATINGIDO: %.2f%% (limite: %.2f%%) - Trading PAUSADO até amanhã!",
                                   dailyDD, MaxDailyDrawdown);
         PrintFormat("%s", msg);
         if(SendAlerts) SendNotification(msg);
        }
      return false;
     }
   
   // Verificar drawdown semanal
   if(weeklyDD >= MaxWeeklyDrawdown)
     {
      if(!g_weeklyDrawdownHit)
        {
         g_weeklyDrawdownHit = true;
         string msg = StringFormat("🚨 DRAWDOWN SEMANAL ATINGIDO: %.2f%% (limite: %.2f%%) - Trading PAUSADO até segunda!",
                                   weeklyDD, MaxWeeklyDrawdown);
         PrintFormat("%s", msg);
         if(SendAlerts) SendNotification(msg);
        }
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
   
   PrintFormat("🕐 Verificando horário: %02d/%02d/%04d %02d:%02d (dia da semana: %d)", 
               dt.day, dt.mon, dt.year, dt.hour, dt.min, dt.day_of_week);

   switch(dt.day_of_week)
     {
      case 1: 
         if(!TradeOnMonday) 
           {
            PrintFormat("   ❌ Segunda-feira desabilitada");
            return false;
           }
         break;
      case 2: 
         if(!TradeOnTuesday) 
           {
            PrintFormat("   ❌ Terça-feira desabilitada");
            return false;
           }
         break;
      case 3: 
         if(!TradeOnWednesday) 
           {
            PrintFormat("   ❌ Quarta-feira desabilitada");
            return false;
           }
         break;
      case 4: 
         if(!TradeOnThursday) 
           {
            PrintFormat("   ❌ Quinta-feira desabilitada");
            return false;
           }
         break;
      case 5: 
         if(!TradeOnFriday) 
           {
            PrintFormat("   ❌ Sexta-feira desabilitada");
            return false;
           }
         break;
      case 6: 
         if(!TradeOnSaturday) 
           {
            PrintFormat("   ❌ Sábado desabilitado");
            return false;
           }
         break;
      case 0: 
         if(!TradeOnSunday) 
           {
            PrintFormat("   ❌ Domingo desabilitado");
            return false;
           }
         break;
     }
   
   PrintFormat("   ✅ Dia da semana OK");

   // Se usar horários customizados
   if(UseCustomTradingHours)
     {
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes = CustomStartHour * 60 + CustomStartMinute;
      int endMinutes = CustomEndHour * 60 + CustomEndMinute;
      
      PrintFormat("   🕐 Horário customizado ATIVO:");
      PrintFormat("      Início: %02d:%02d (%d min)", CustomStartHour, CustomStartMinute, startMinutes);
      PrintFormat("      Fim: %02d:%02d (%d min)", CustomEndHour, CustomEndMinute, endMinutes);
      PrintFormat("      Atual: %02d:%02d (%d min)", dt.hour, dt.min, currentMinutes);
      
      // ✅ CORREÇÃO CRÍTICA: Suportar horários que cruzam meia-noite
      bool isValid = false;
      
      if(endMinutes >= startMinutes)
        {
         // Caso normal: 09:00 - 17:00
         isValid = (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
        }
      else
        {
         // Caso especial: 22:00 - 21:00 (próximo dia)
         // Válido se: >= 22:00 OU <= 21:00
         isValid = (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
        }
      
      if(!isValid)
        {
         PrintFormat("   ❌ Fora do horário customizado");
         return false;
        }
      
      PrintFormat("   ✅ Dentro do horário customizado");
      return true;
     }

   PrintFormat("   ✅ Horário customizado desabilitado, qualquer horário OK");
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

   // ✅ CORREÇÃO CRÍTICA v4.3: Validar ATR (volatilidade)
   if(ValidateATRRange)
     {
      if(!ValidateATR(symbol, assetClass))
        {
         return false; // ATR fora do range ideal
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Valida ATR (Average True Range) por classe de ativo             |
//+------------------------------------------------------------------+
bool ValidateATR(const string symbol, ASSET_CLASS assetClass)
  {
   // Calcular ATR(14) no timeframe operacional
   int atrHandle = iATR(symbol, Period(), 14);
   if(atrHandle == INVALID_HANDLE)
     {
      PrintFormat("⚠️ Erro ao criar handle ATR");
      return true; // Se erro, permite (fail-safe)
     }
   
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) != 1)
     {
      PrintFormat("⚠️ Erro ao copiar buffer ATR");
      IndicatorRelease(atrHandle);
      return true; // Se erro, permite (fail-safe)
     }
   
   IndicatorRelease(atrHandle);
   
   double currentATR = atr[0];
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Definir ranges ideais por classe de ativo (em pips/pontos)
   double minATR = 0, maxATR = 0;
   
   switch(assetClass)
     {
      case ASSET_CLASS_FOREX_MAJOR:
         minATR = 10 * point * 10;   // 10 pips
         maxATR = 100 * point * 10;  // 100 pips
         break;
         
      case ASSET_CLASS_FOREX_MINOR:
         minATR = 15 * point * 10;   // 15 pips
         maxATR = 150 * point * 10;  // 150 pips
         break;
         
      case ASSET_CLASS_FOREX_EXOTIC:
         minATR = 30 * point * 10;   // 30 pips
         maxATR = 300 * point * 10;  // 300 pips
         break;
         
      case ASSET_CLASS_INDEX_B3:
         minATR = 200 * point;       // 200 pontos WIN
         maxATR = 2000 * point;      // 2000 pontos WIN
         break;
         
      case ASSET_CLASS_CURRENCY_B3:
         minATR = 10 * point;        // 10 pontos WDO
         maxATR = 100 * point;       // 100 pontos WDO
         break;
         
      case ASSET_CLASS_METALS:
         minATR = 2 * point;         // $2 ouro
         maxATR = 20 * point;        // $20 ouro
         break;
         
      case ASSET_CLASS_INDEX_US:
      case ASSET_CLASS_INDEX_EU:
         minATR = 10 * point;        // 10 pontos índice
         maxATR = 200 * point;       // 200 pontos índice
         break;
         
      default:
         return true; // Classe desconhecida, permite
     }
   
   // Validar se ATR está dentro do range
   if(currentATR < minATR)
     {
      PrintFormat("⚠️ ATR muito baixo: %.5f < %.5f (mercado morto)", currentATR, minATR);
      return false;
     }
   
   if(currentATR > maxATR)
     {
      PrintFormat("⚠️ ATR muito alto: %.5f > %.5f (volatilidade extrema)", currentATR, maxATR);
      return false;
     }
   
   PrintFormat("   ✅ ATR OK: %.5f (range: %.5f - %.5f)", currentATR, minATR, maxATR);
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
   // Validar riscos básicos
   if(AccountRiskPercent <= 0 || AccountRiskPercent > 10)
     {
      PrintFormat("❌ AccountRiskPercent inválido: %.2f (deve ser 0.1-10%%)", AccountRiskPercent);
      return false;
     }

   if(MaxRiskPremium <= 0 || MaxRiskPremium > 10)
     {
      PrintFormat("❌ MaxRiskPremium inválido: %.2f (deve ser 0.1-10%%)", MaxRiskPremium);
      return false;
     }

   // 🔥 REMOVIDO v4.9: Validação MaxDrawdownPercent (bloqueio desabilitado)

   if(MaxSimultaneousTrades <= 0 || MaxSimultaneousTrades > 10)
     {
      PrintFormat("❌ MaxSimultaneousTrades inválido: %d (deve ser 1-10)", MaxSimultaneousTrades);
      return false;
     }
   
   // ✅ VALIDAR NOVOS PARÂMETROS v4.4
   
   // Stop Loss
   if(SL_BufferPoints < 0 || SL_BufferPoints > 1000)
     {
      PrintFormat("❌ SL_BufferPoints inválido: %.1f (deve ser 0-1000)", SL_BufferPoints);
      return false;
     }
   
   if(SL_FallbackPercent < 0.1 || SL_FallbackPercent > 10)
     {
      PrintFormat("❌ SL_FallbackPercent inválido: %.2f (deve ser 0.1-10%%)", SL_FallbackPercent);
      return false;
     }
   
   if(SL_MinDistancePoints < 0 || SL_MinDistancePoints > 10000)
     {
      PrintFormat("❌ SL_MinDistancePoints inválido: %.1f (deve ser 0-10000)", SL_MinDistancePoints);
      return false;
     }
   
   if(SL_MaxDistancePoints < SL_MinDistancePoints || SL_MaxDistancePoints > 50000)
     {
      PrintFormat("❌ SL_MaxDistancePoints inválido: %.1f (deve ser >= SL_Min e <= 50000)", SL_MaxDistancePoints);
      PrintFormat("   SL_MinDistancePoints: %.1f", SL_MinDistancePoints);
      return false;
     }
   
   // Take Profit
   if(TP1_RR < 0.1 || TP1_RR > 20)
     {
      PrintFormat("❌ TP1_RR inválido: %.2f (deve ser 0.1-20)", TP1_RR);
      return false;
     }
   
   if(TP2_RR < TP1_RR || TP2_RR > 20)
     {
      PrintFormat("❌ TP2_RR inválido: %.2f (deve ser >= TP1_RR e <= 20)", TP2_RR);
      return false;
     }
   
   if(UseTP3)
     {
      if(TP3_RR < TP2_RR || TP3_RR > 20)
        {
         PrintFormat("❌ TP3_RR inválido: %.2f (deve ser >= TP2_RR e <= 20)", TP3_RR);
         return false;
        }
     }
   
   // Validar percentuais individuais (soma será validada na execução)
   if(EnablePartialTP)
     {
      if(TP1_ClosePercent < 0 || TP1_ClosePercent > 100)
        {
         PrintFormat("❌ TP1_ClosePercent inválido: %.1f%% (deve ser 0-100%%)", TP1_ClosePercent);
         return false;
        }
      
      if(TP2_ClosePercent < 0 || TP2_ClosePercent > 100)
        {
         PrintFormat("❌ TP2_ClosePercent inválido: %.1f%% (deve ser 0-100%%)", TP2_ClosePercent);
         return false;
        }
      
      if(UseTP3 && (TP3_ClosePercent < 0 || TP3_ClosePercent > 100))
        {
         PrintFormat("❌ TP3_ClosePercent inválido: %.1f%% (deve ser 0-100%%)", TP3_ClosePercent);
         return false;
        }
      
      // Avisar se soma não é 100%, mas permitir (pode ser estratégia intencional)
      double totalClosePercent = TP1_ClosePercent + TP2_ClosePercent;
      if(UseTP3)
         totalClosePercent += TP3_ClosePercent;
      
      if(totalClosePercent < 95 || totalClosePercent > 105)
        {
         PrintFormat("⚠️ AVISO: Soma dos TP ClosePercent: %.1f%% (recomendado ~100%%)", totalClosePercent);
         PrintFormat("   TP1: %.1f%%, TP2: %.1f%%, TP3: %.1f%%", TP1_ClosePercent, TP2_ClosePercent, TP3_ClosePercent);
         // Não retornar false, apenas avisar
        }
     }
   
   // Trailing Stop
   if(TrailingDistancePoints < 0 || TrailingDistancePoints > 10000)
     {
      PrintFormat("❌ TrailingDistancePoints inválido: %.1f (deve ser 0-10000)", TrailingDistancePoints);
      return false;
     }
   
   if(TrailingStepPoints < 0 || TrailingStepPoints > TrailingDistancePoints)
     {
      PrintFormat("❌ TrailingStepPoints inválido: %.1f (deve ser 0-%.1f)", TrailingStepPoints, TrailingDistancePoints);
      return false;
     }
   
   if(TrailingActivationRR < 0 || TrailingActivationRR > 10)
     {
      PrintFormat("❌ TrailingActivationRR inválido: %.2f (deve ser 0-10)", TrailingActivationRR);
      return false;
     }
   
   if(TrailingUseATR && (TrailingATRMultiplier < 0.1 || TrailingATRMultiplier > 10))
     {
      PrintFormat("❌ TrailingATRMultiplier inválido: %.2f (deve ser 0.1-10)", TrailingATRMultiplier);
      return false;
     }
   
   // Horários customizados
   if(UseCustomTradingHours)
     {
      if(CustomStartHour < 0 || CustomStartHour > 23)
        {
         PrintFormat("❌ CustomStartHour inválido: %d (deve ser 0-23)", CustomStartHour);
         return false;
        }
      
      if(CustomStartMinute < 0 || CustomStartMinute > 59)
        {
         PrintFormat("❌ CustomStartMinute inválido: %d (deve ser 0-59)", CustomStartMinute);
         return false;
        }
      
      if(CustomEndHour < 0 || CustomEndHour > 23)
        {
         PrintFormat("❌ CustomEndHour inválido: %d (deve ser 0-23)", CustomEndHour);
         return false;
        }
      
      if(CustomEndMinute < 0 || CustomEndMinute > 59)
        {
         PrintFormat("❌ CustomEndMinute inválido: %d (deve ser 0-59)", CustomEndMinute);
         return false;
        }
     }
   
   PrintFormat("✅ Todos os parâmetros validados com sucesso");
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
   PrintFormat("   Trades simultâneos: %d", MaxSimultaneousTrades);
   PrintFormat("   Modo posições: %s", 
               (PositionControlMode == POSITION_MODE_SINGLE) ? "SINGLE" :
               (PositionControlMode == POSITION_MODE_MULTIPLE) ? "MULTIPLE" : "PROTECTED");
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
//| Expert timer function (executado a cada hora)                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Obter data/hora atual
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Verificação de integridade do sistema
   ValidateSystemIntegrity();
   
   // Log periódico de status
   if(dt.min == 0) // A cada hora cheia
     {
      PrintFormat("⏰ Status horário: %02d:00 | Posições abertas: %d | Saldo: %.2f",
                  dt.hour,
                  CountOpenTrades(),
                  AccountInfoDouble(ACCOUNT_BALANCE));
     }
  }

//+------------------------------------------------------------------+
//| Limpeza de logs antigos                                         |
//+------------------------------------------------------------------+
void CleanupOldLogs()
  {
   // TODO: Implementar limpeza de logs antigos quando necessário
   // Por enquanto, apenas placeholder para futuras implementações
  }

//+------------------------------------------------------------------+
//| Validação de integridade do sistema                             |
//+------------------------------------------------------------------+
void ValidateSystemIntegrity()
  {
   // Verificar se indicadores ainda estão válidos
   // Reconectar se necessário
   // Por enquanto, apenas placeholder para futuras implementações
  }

//+------------------------------------------------------------------+
