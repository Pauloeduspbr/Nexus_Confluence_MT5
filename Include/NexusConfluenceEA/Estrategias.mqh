//+------------------------------------------------------------------+
//| Estrategias.mqh                                                  |
//| Nexus Confluence EA v4.1 - Sistema Multi-Timeframe Universal     |
//|                                                                   |
//| PROPÓSITO: Centralizar TODA a lógica de estratégias multi-TF     |
//|                                                                   |
//| FUNÇÕES PRINCIPAIS:                                              |
//|   - DefineMultiTimeframes(): Define TFs macro conforme TF oper   |
//|   - AnalyzeMultiTimeframeAlignment(): Valida alinhamento macro   |
//|   - AnalyzeMicroFilters(): Analisa filtros e pontua setup        |
//|   - GetTrendMagicSignal(): Lê sinal Trend Magic                  |
//|   - GetCurrencyStrengthSignal(): Lê força de moedas             |
//|   - GetRSIOMASignal(): Lê RSI OMA                               |
//|   - GetWAESignal(): Lê WAE                                      |
//|   - GetGGTrendBarSignal(): Lê GG TrendBar                       |
//|   - CalculateSetupScore(): Pontua e classifica setup            |
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Parametros.mqh (enums, structs, inputs)                     |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.1 - Multi-Timeframe                                    |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.1"
#property version   "4.10"
#property strict

// Incluir primeiro o arquivo de parâmetros
#include "Parametros.mqh"

//+------------------------------------------------------------------+
//| FUNÇÕES AUXILIARES DO MÓDULO                                     |
//+------------------------------------------------------------------+

// Converter ENUM_TIMEFRAMES para string legível
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS DO MÓDULO ESTRATÉGIAS                          |
//+------------------------------------------------------------------+

// Timeframes macro definidos dinamicamente
ENUM_TIMEFRAMES g_tfMacro1       = PERIOD_H4;   // MACRO-1 (mais longo)
ENUM_TIMEFRAMES g_tfMacro2       = PERIOD_H1;   // MACRO-2 (intermediário)
ENUM_TIMEFRAMES g_tfMacro3       = PERIOD_M30;  // MACRO-3 (curto) - pode ser PERIOD_CURRENT se não aplicável
ENUM_TIMEFRAMES g_tfOperacional  = PERIOD_M15;  // OPERACIONAL (atual do gráfico)
int             g_numNiveisMacro = 3;           // 2 ou 3 níveis macro

// Handles dos indicadores (preenchidos em InitializeIndicators)
IndicatorHandles g_handles;

//+------------------------------------------------------------------+
//| FUNÇÃO: DefineMultiTimeframes                                    |
//| Define os timeframes macro conforme o TF operacional do gráfico |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - tfOper: Timeframe atual do gráfico (Period())               |
//|   - tfM1: (output) Timeframe MACRO-1 definido                   |
//|   - tfM2: (output) Timeframe MACRO-2 definido                   |
//|   - tfM3: (output) Timeframe MACRO-3 definido                   |
//|   - numNiveisMacro: (output) 2 ou 3 níveis macro                |
//|                                                                  |
//| RETORNO: void (modifica variáveis por referência)               |
//+------------------------------------------------------------------+
void DefineMultiTimeframes(ENUM_TIMEFRAMES tfOper,
                           ENUM_TIMEFRAMES &tfM1,
                           ENUM_TIMEFRAMES &tfM2,
                           ENUM_TIMEFRAMES &tfM3,
                           int &numNiveisMacro)
{
   // Switch baseado no timeframe operacional
   switch(tfOper)
   {
      case PERIOD_M1:
         // M1 → MACRO-1: M30, MACRO-2: M15, MACRO-3: M5
         tfM1 = PERIOD_M30;
         tfM2 = PERIOD_M15;
         tfM3 = PERIOD_M5;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M1 → Macro: M30/M15/M5 (3 níveis)");
         break;
         
      case PERIOD_M5:
         // M5 → MACRO-1: H1, MACRO-2: M30, MACRO-3: M15
         tfM1 = PERIOD_H1;
         tfM2 = PERIOD_M30;
         tfM3 = PERIOD_M15;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M5 → Macro: H1/M30/M15 (3 níveis)");
         break;
         
      case PERIOD_M15:
         // M15 → MACRO-1: H4, MACRO-2: H1, MACRO-3: M30 (SISTEMA ORIGINAL)
         tfM1 = PERIOD_H4;
         tfM2 = PERIOD_H1;
         tfM3 = PERIOD_M30;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M15 → Macro: H4/H1/M30 (3 níveis) ⭐ ORIGINAL");
         break;
         
      case PERIOD_M30:
         // M30 → MACRO-1: D1, MACRO-2: H4, MACRO-3: H1
         tfM1 = PERIOD_D1;
         tfM2 = PERIOD_H4;
         tfM3 = PERIOD_H1;
         numNiveisMacro = 3;
         PrintFormat("🎯 TF Detectado: M30 → Macro: D1/H4/H1 (3 níveis)");
         break;
         
      case PERIOD_H1:
         // H1 → MACRO-1: D1, MACRO-2: H4 (APENAS 2 NÍVEIS)
         tfM1 = PERIOD_D1;
         tfM2 = PERIOD_H4;
         tfM3 = PERIOD_CURRENT; // Não aplicável
         numNiveisMacro = 2;
         PrintFormat("🎯 TF Detectado: H1 → Macro: D1/H4 (2 níveis apenas)");
         break;
         
      case PERIOD_H4:
         // H4 → MACRO-1: W1, MACRO-2: D1 (APENAS 2 NÍVEIS)
         tfM1 = PERIOD_W1;
         tfM2 = PERIOD_D1;
         tfM3 = PERIOD_CURRENT; // Não aplicável
         numNiveisMacro = 2;
         PrintFormat("🎯 TF Detectado: H4 → Macro: W1/D1 (2 níveis apenas)");
         break;
         
      default:
         // Não suportado: D1, W1, MN1
         PrintFormat("❌ ERRO: Timeframe %s não suportado pelo sistema!", EnumToString(tfOper));
         tfM1 = PERIOD_CURRENT;
         tfM2 = PERIOD_CURRENT;
         tfM3 = PERIOD_CURRENT;
         numNiveisMacro = 0;
         break;
   }
   
   // Atualizar variáveis globais
   g_tfMacro1 = tfM1;
   g_tfMacro2 = tfM2;
   g_tfMacro3 = tfM3;
   g_tfOperacional = tfOper;
   g_numNiveisMacro = numNiveisMacro;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: InitializeIndicators                                     |
//| Inicializa todos os handles dos indicadores                     |
//|                                                                  |
//| NOVO v4.2: Sistema simplificado com GG TrendBar como mestre     |
//|            Remove handles multi-TF desnecessários                |
//|                                                                  |
//| RETORNO: true se sucesso, false se erro                         |
//+------------------------------------------------------------------+
bool InitializeIndicators(string symbol)
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 Inicializando indicadores (Sistema v4.2 Simplificado)...");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // Construir caminhos dos indicadores
   string path_st = IndicatorsBasePath + TrendMagicIndicator;
   string path_cs = IndicatorsBasePath + CurrencyStrengthIndicator;
   string path_rsi = IndicatorsBasePath + RSIOMAIndicator;
   string path_wae = IndicatorsBasePath + WAEIndicator;
   string path_gg = IndicatorsBasePath + GGTrendBarIndicator;
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  1️⃣ GG TRENDBAR - FILTRO MESTRE (Multi-TF Interno)          ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("🎯 [1/5] GG TrendBar (Filtro Mestre Multi-TF)...");
   g_handles.gg_global = iCustom(symbol, PERIOD_CURRENT, path_gg,
                                  GG_UpColor,
                                  GG_DownColor,
                                  GG_FlatColor,
                                  GG_TextColor,
                                  GG_Corner,
                                  GG_CreateVisualObjects,
                                  GG_ADX_Period,
                                  GG_ADX_Price,
                                  GG_Step_Psar,
                                  GG_Max_Psar);
   if(g_handles.gg_global == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO CRÍTICO: Falha ao criar handle GG TrendBar!");
      PrintFormat("   GG TrendBar é o FILTRO MESTRE - sistema não pode operar sem ele!");
      return false;
   }
   PrintFormat("   ✅ GG TrendBar OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  2️⃣ SUPERTREND (Trend Magic Oper) - Tendência Local         ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("📈 [2/5] Supertrend (Tendência Local %s)...", EnumToString(g_tfOperacional));
   g_handles.st_oper = iCustom(symbol, g_tfOperacional, path_st,
                                ST_OPER_CCI_Period,
                                ST_OPER_ATR_Period,
                                ST_OPER_ATR_Multiplier);
   if(g_handles.st_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: Supertrend falhou!");
      return false;
   }
   PrintFormat("   ✅ Supertrend OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  3️⃣ WAE - Momentum/Explosão                                  ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("💥 [3/5] WAE (Momentum)...");
   g_handles.wae_oper = iCustom(symbol, g_tfOperacional, path_wae,
                                 WAE_OPER_FastMA,
                                 WAE_OPER_SlowMA,
                                 WAE_OPER_BBLength,
                                 WAE_OPER_BBMultiplier,
                                 WAE_OPER_Sensitivity);
   if(g_handles.wae_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: WAE falhou!");
      return false;
   }
   PrintFormat("   ✅ WAE OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  4️⃣ RSI OMA - Força Relativa                                 ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("📊 [4/5] RSI OMA (Força Relativa)...");
   g_handles.rsi_oper = iCustom(symbol, g_tfOperacional, path_rsi,
                                 RSI_OPER_Period,
                                 RSI_OPER_MA_Period,
                                 RSI_OPER_MA_Method,
                                 RSI_OPER_HighLevel,
                                 RSI_OPER_LowLevel,
                                 RSI_OPER_ShowLevels);
   if(g_handles.rsi_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: RSI OMA falhou!");
      return false;
   }
   PrintFormat("   ✅ RSI OMA OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  5️⃣ CURRENCY STRENGTH - Contexto Moedas (Forex/Metais)      ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("� [5/5] Currency Strength (Contexto)...");
   g_handles.cs_oper = iCustom(symbol, g_tfOperacional, path_cs,
                                CS_CalculationPeriod,
                                CS_SmoothingPeriod,
                                CS_ShowInPercent);
   if(g_handles.cs_oper == INVALID_HANDLE)
   {
      PrintFormat("❌ ERRO: Currency Strength falhou!");
      return false;
   }
   PrintFormat("   ✅ Currency Strength OK");
   
   //╔══════════════════════════════════════════════════════════════╗
   //║  📌 ANEXANDO INDICADORES AO GRÁFICO                          ║
   //╚══════════════════════════════════════════════════════════════╝
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("📌 Anexando indicadores ao gráfico...");
   
   // GG TrendBar - Janela principal (com Supertrend)
   if(!ChartIndicatorAdd(0, 0, g_handles.gg_global))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar GG TrendBar ao gráfico principal");
   }
   else
   {
      PrintFormat("   ✅ GG TrendBar anexado à janela principal");
   }
   
   // Supertrend - Janela principal (junto com GG TrendBar)
   if(!ChartIndicatorAdd(0, 0, g_handles.st_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar Supertrend ao gráfico principal");
   }
   else
   {
      PrintFormat("   ✅ Supertrend anexado à janela principal");
   }
   
   // Currency Strength - Subwindow 1
   if(!ChartIndicatorAdd(0, 1, g_handles.cs_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar Currency Strength ao subwindow 1");
   }
   else
   {
      PrintFormat("   ✅ Currency Strength anexado ao subwindow 1");
   }
   
   // RSI OMA - Subwindow 2
   if(!ChartIndicatorAdd(0, 2, g_handles.rsi_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar RSI OMA ao subwindow 2");
   }
   else
   {
      PrintFormat("   ✅ RSI OMA anexado ao subwindow 2");
   }
   
   // WAE - Subwindow 3
   if(!ChartIndicatorAdd(0, 3, g_handles.wae_oper))
   {
      PrintFormat("⚠️ Aviso: Não foi possível anexar WAE ao subwindow 3");
   }
   else
   {
      PrintFormat("   ✅ WAE anexado ao subwindow 3");
   }
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("✅ TODOS OS 5 INDICADORES INICIALIZADOS E ANEXADOS COM SUCESSO!");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return true;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetSupertrendSignal                                      |
//| Lê sinal do Supertrend (antigo Trend Magic) operacional         |
//|                                                                  |
//| NOTA v4.2: Esta função agora é usada APENAS para o timeframe    |
//|            operacional (st_oper). Multi-TF é feito por GG Bar.  |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - timeframe: Timeframe do sinal                               |
//|                                                                  |
//| RETORNO: TMSignal (struct com direção e força)                  |
//+------------------------------------------------------------------+
TMSignal GetSupertrendSignal(int handle, ENUM_TIMEFRAMES timeframe)
{
   TMSignal result;
   result.isValid = false;
   result.direction = TRADE_DIRECTION_NONE;
   result.strength = 0.0;
   result.timeframe = timeframe;
   result.turnedRecently = false;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // Buffers: 0 = Up (azul), 1 = Down (vermelho)
   double bufferUp[3], bufferDown[3];
   
   if(CopyBuffer(handle, 0, 0, 3, bufferUp) != 3 ||
      CopyBuffer(handle, 1, 0, 3, bufferDown) != 3)
   {
      PrintFormat("❌ Erro ao copiar buffer Supertrend (%s)", EnumToString(timeframe));
      return result;
   }
   
   // DEBUG: Mostrar valores dos buffers
   PrintFormat("📊 Supertrend %s - Buffers [0]Up=%.5f [0]Down=%.5f [1]Up=%.5f [1]Down=%.5f", 
               TimeframeToString(timeframe),
               bufferUp[0], bufferDown[0],
               bufferUp[1], bufferDown[1]);
   
   // CORREÇÃO CRÍTICA: Em Supertrend/TrendMagic, quando o buffer tem valor (não é EMPTY_VALUE),
   // aquele é o buffer ATIVO. O outro buffer fica em EMPTY_VALUE ou 0.
   
   // Determinar direção atual (qual linha tem valor válido)
   bool currentBullish = (bufferUp[0] != EMPTY_VALUE && bufferUp[0] != 0);
   bool currentBearish = (bufferDown[0] != EMPTY_VALUE && bufferDown[0] != 0);
   
   // Verificar se mudou de cor recentemente (últimos 2 candles)
   bool wasBullish = (bufferUp[2] != EMPTY_VALUE && bufferUp[2] != 0);
   bool wasBearish = (bufferDown[2] != EMPTY_VALUE && bufferDown[2] != 0);
   
   // Detectar mudança confirmada
   if(currentBullish && !wasBullish)
   {
      result.turnedRecently = true;
   }
   else if(currentBearish && !wasBearish)
   {
      result.turnedRecently = true;
   }
   
   // Definir direção
   if(currentBullish && !currentBearish)
   {
      result.direction = TRADE_DIRECTION_BUY;
      result.strength = bufferUp[0];
      result.isValid = true;
      PrintFormat("   ✅ %s = BULLISH (BUY)", TimeframeToString(timeframe));
   }
   else if(currentBearish && !currentBullish)
   {
      result.direction = TRADE_DIRECTION_SELL;
      result.strength = bufferDown[0];
      result.isValid = true;
      PrintFormat("   ✅ %s = BEARISH (SELL)", TimeframeToString(timeframe));
   }
   else if(currentBullish && currentBearish)
   {
      // Ambos têm valor - situação anormal, tratar como indeciso
      result.direction = TRADE_DIRECTION_NONE;
      result.isValid = false;
      PrintFormat("   ⚠️ %s = AMBÍGUO (ambos buffers ativos)", TimeframeToString(timeframe));
   }
   else
   {
      // Nenhum tem valor - indeciso (amarelo ou sem sinal)
      result.direction = TRADE_DIRECTION_NONE;
      result.isValid = false;
      PrintFormat("   ⚠️ %s = NEUTRO/INDECISO", TimeframeToString(timeframe));
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetCurrencyStrengthSignal                                |
//| Lê força das moedas e verifica alinhamento                      |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a analisar                                  |
//|   - direction: Direção pretendida do trade                      |
//|   - assetClass: Classe do ativo (para lógica inversa metais)   |
//|                                                                  |
//| RETORNO: CSSignal (struct com alinhamento)                      |
//+------------------------------------------------------------------+
CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetClass)
{
   CSSignal result;
   result.isValid = false;
   result.isAligned = false;
   result.strength = 0.0;
   
   // Verificar se Currency Strength é aplicável
   if(assetClass != ASSET_CLASS_FOREX_MAJOR &&
      assetClass != ASSET_CLASS_FOREX_MINOR &&
      assetClass != ASSET_CLASS_FOREX_EXOTIC &&
      assetClass != ASSET_CLASS_CURRENCY_B3 &&
      assetClass != ASSET_CLASS_METALS)
   {
      return result; // Não aplicável para índices
   }
   
   if(g_handles.cs_oper == INVALID_HANDLE)
   {
      return result;
   }
   
   // Buffers: 0 = Base Currency, 1 = Quote Currency
   double baseStrength[1], quoteStrength[1];
   
   if(CopyBuffer(g_handles.cs_oper, 0, 0, 1, baseStrength) != 1 ||
      CopyBuffer(g_handles.cs_oper, 1, 0, 1, quoteStrength) != 1)
   {
      PrintFormat("❌ Erro ao copiar buffer Currency Strength");
      return result;
   }
   
   result.strength = MathAbs(baseStrength[0] - quoteStrength[0]);
   result.isValid = true;
   
   // Lógica normal (Forex)
   if(assetClass != ASSET_CLASS_METALS)
   {
      if(direction == TRADE_DIRECTION_BUY)
      {
         // Para compra: moeda base deve ser mais forte
         result.isAligned = (baseStrength[0] > quoteStrength[0]);
      }
      else if(direction == TRADE_DIRECTION_SELL)
      {
         // Para venda: moeda cotação deve ser mais forte
         result.isAligned = (quoteStrength[0] > baseStrength[0]);
      }
   }
   else
   {
      // Lógica INVERSA para metais (XAU/USD, XAG/USD)
      // Ouro sobe quando USD fraco
      if(direction == TRADE_DIRECTION_BUY)
      {
         // Para compra de ouro: USD (quote) deve estar fraco
         result.isAligned = (quoteStrength[0] < baseStrength[0]);
      }
      else if(direction == TRADE_DIRECTION_SELL)
      {
         // Para venda de ouro: USD (quote) deve estar forte
         result.isAligned = (quoteStrength[0] > baseStrength[0]);
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetRSIOMASignal                                          |
//| Lê sinal do RSI OMA (linha vermelha vs azul + inclinação)      |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - direction: Direção pretendida                               |
//|   - timeframe: Timeframe para log                               |
//|                                                                  |
//| RETORNO: RSISignal (struct com alinhamento e inclinação)        |
//+------------------------------------------------------------------+
RSISignal GetRSIOMASignal(int handle, TRADE_DIRECTION direction, ENUM_TIMEFRAMES timeframe)
{
   RSISignal result;
   result.isValid = false;
   result.isAligned = false;
   result.strength = 0.0;
   result.slope = 0.0;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // Buffers: 0 = RSI (linha vermelha), 1 = MA (linha azul)
   double rsiRed[3], rsiBlue[3];
   
   if(CopyBuffer(handle, 0, 0, 3, rsiRed) != 3 ||
      CopyBuffer(handle, 1, 0, 3, rsiBlue) != 3)
   {
      PrintFormat("❌ Erro ao copiar buffer RSI OMA (%s)", EnumToString(timeframe));
      return result;
   }
   
   // Calcular inclinação linha vermelha (últimos 3 candles)
   result.slope = (rsiRed[0] - rsiRed[2]) / 2.0;
   result.strength = MathAbs(rsiRed[0] - rsiBlue[0]);
   result.isValid = true;
   
   // Verificar posição e inclinação
   bool redAboveBlue = (rsiRed[0] > rsiBlue[0]);
   bool slopePositive = (result.slope > 0.5);  // Mínimo 0.5 de inclinação
   bool slopeNegative = (result.slope < -0.5);
   
   // ✅ CORREÇÃO CRÍTICA v4.3: Validar zona de sobrecompra/sobrevenda
   bool notOverbought = (rsiRed[0] < RSI_OPER_HighLevel);   // <70 (evita topos)
   bool notOversold = (rsiRed[0] > RSI_OPER_LowLevel);      // >30 (evita fundos)
   
   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para compra: linha vermelha acima da azul + inclinação positiva + NÃO sobrecomprado
      result.isAligned = (redAboveBlue && slopePositive && notOverbought);
      
      if(!notOverbought)
         PrintFormat("   ⚠️ RSI OMA rejeitado: RSI=%.1f >= %.1f (sobrecompra)", rsiRed[0], RSI_OPER_HighLevel);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para venda: linha vermelha abaixo da azul + inclinação negativa + NÃO sobrevendido
      result.isAligned = (!redAboveBlue && slopeNegative && notOversold);
      
      if(!notOversold)
         PrintFormat("   ⚠️ RSI OMA rejeitado: RSI=%.1f <= %.1f (sobrevenda)", rsiRed[0], RSI_OPER_LowLevel);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetWAESignal                                             |
//| Lê sinal do WAE (histograma + expansão)                         |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - handle: Handle do indicador                                 |
//|   - direction: Direção pretendida                               |
//|   - timeframe: Timeframe para log                               |
//|                                                                  |
//| RETORNO: WAESignal (struct com expansão e força)                |
//+------------------------------------------------------------------+
WAESignal GetWAESignal(int handle, TRADE_DIRECTION direction, ENUM_TIMEFRAMES timeframe)
{
   WAESignal result;
   result.isValid = false;
   result.isAligned = false;
   result.isExpanding = false;
   result.strength = 0.0;
   
   if(handle == INVALID_HANDLE)
   {
      return result;
   }
   
   // Buffers: 0 = Trend Up (verde), 1 = Trend Down (vermelho),
   //          2 = Explosion Line (amarela), 3 = Dead Zone
   double trendUp[3], trendDown[3], explosion[1];
   
   if(CopyBuffer(handle, 0, 0, 3, trendUp) != 3 ||
      CopyBuffer(handle, 1, 0, 3, trendDown) != 3 ||
      CopyBuffer(handle, 2, 0, 1, explosion) != 1)
   {
      PrintFormat("❌ Erro ao copiar buffer WAE (%s)", EnumToString(timeframe));
      return result;
   }
   
   // Determinar cor do histograma (verde ou vermelho)
   bool isGreen = (trendUp[0] > trendDown[0] && trendUp[0] > 0);
   bool isRed = (trendDown[0] > trendUp[0] && trendDown[0] > 0);
   
   // Calcular força do histograma
   double currentStrength = MathMax(trendUp[0], trendDown[0]);
   result.strength = currentStrength;
   
   // Verificar expansão (últimos 3 candles)
   bool expanding = (currentStrength > MathMax(trendUp[1], trendDown[1]) &&
                     MathMax(trendUp[1], trendDown[1]) > MathMax(trendUp[2], trendDown[2]));
   result.isExpanding = expanding;
   
   // Verificar se está acima da linha de explosão
   bool aboveExplosion = (currentStrength > explosion[0]);
   
   result.isValid = true;
   
   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para compra: verde + expandindo + acima explosão
      result.isAligned = (isGreen && expanding && aboveExplosion);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para venda: vermelho + expandindo + acima explosão
      result.isAligned = (isRed && expanding && aboveExplosion);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: GetGGTrendBarSignal                                      |
//| Lê sinais multi-timeframe do GG TrendBar                        |
//|                                                                  |
//| RETORNO: GGTrendBarSignal (struct com sinais de todos os TFs)   |
//+------------------------------------------------------------------+
GGTrendBarSignal GetGGTrendBarSignal()
{
   GGTrendBarSignal result;
   result.isValid = false;
   
   if(g_handles.gg_global == INVALID_HANDLE)
   {
      return result;
   }
   
   // GG TrendBar tem 18 buffers (9 TFs × 2)
   // Buffers de dados: 0=M1, 2=M5, 4=M15, 6=M30, 8=H1, 10=H4, 12=D1, 14=W1, 16=MN1
   double m1[1], m5[1], m15[1], m30[1], h1[1], h4[1], d1[1], w1[1], mn1[1];
   
   if(CopyBuffer(g_handles.gg_global, 0, 0, 1, m1) != 1 ||
      CopyBuffer(g_handles.gg_global, 2, 0, 1, m5) != 1 ||
      CopyBuffer(g_handles.gg_global, 4, 0, 1, m15) != 1 ||
      CopyBuffer(g_handles.gg_global, 6, 0, 1, m30) != 1 ||
      CopyBuffer(g_handles.gg_global, 8, 0, 1, h1) != 1 ||
      CopyBuffer(g_handles.gg_global, 10, 0, 1, h4) != 1 ||
      CopyBuffer(g_handles.gg_global, 12, 0, 1, d1) != 1 ||
      CopyBuffer(g_handles.gg_global, 14, 0, 1, w1) != 1 ||
      CopyBuffer(g_handles.gg_global, 16, 0, 1, mn1) != 1)
   {
      PrintFormat("❌ Erro ao copiar buffers GG TrendBar");
      return result;
   }
   
   // Preencher valores (+1 = bullish, 0 = neutral, -1 = bearish)
   result.m1Value = (int)m1[0];
   result.m5Value = (int)m5[0];
   result.m15Value = (int)m15[0];
   result.m30Value = (int)m30[0];
   result.h1Value = (int)h1[0];
   result.h4Value = (int)h4[0];
   result.d1Value = (int)d1[0];
   result.w1Value = (int)w1[0];
   result.mn1Value = (int)mn1[0];
   
   // Interpretação booleana
   result.h4Bullish = (result.h4Value == 1);
   result.h1Bullish = (result.h1Value == 1);
   result.m30Bullish = (result.m30Value == 1);
   result.m15Bullish = (result.m15Value == 1);
   
   // Determinar direção geral (pode ser usado como confirmação)
   int sumSignals = result.h4Value + result.h1Value + result.m30Value + result.m15Value;
   if(sumSignals >= 2)
   {
      result.overallDirection = TRADE_DIRECTION_BUY;
   }
   else if(sumSignals <= -2)
   {
      result.overallDirection = TRADE_DIRECTION_SELL;
   }
   else
   {
      result.overallDirection = TRADE_DIRECTION_NONE;
   }
   
   result.isValid = true;
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: AnalyzeMultiTimeframeAlignment                           |
//| Valida alinhamento multi-TF usando GG TRENDBAR (FILTRO MESTRE)  |
//|                                                                  |
//| NOVO v4.2: Substitui lógica de Trend Magic multi-TF             |
//|            GG TrendBar analisa M1-MN1 internamente              |
//|                                                                  |
//| RETORNO: MultiTFResult (struct com resultado da análise)        |
//+------------------------------------------------------------------+
MultiTFResult AnalyzeMultiTimeframeAlignment()
{
   MultiTFResult result;
   result.isValid = false;
   result.direction = TRADE_DIRECTION_NONE;
   result.h4Aligned = false;
   result.h1Aligned = false;
   result.m30Aligned = false;
   result.structureValid = false;
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("🎯 Analisando Multi-Timeframe com GG TRENDBAR (FILTRO MESTRE)");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // Obter sinais GG TrendBar de todos os timeframes
   GGTrendBarSignal gg = GetGGTrendBarSignal();
   
   if(!gg.isValid)
   {
      PrintFormat("❌ GG TrendBar inválido - não é possível analisar");
      return result;
   }
   
   // Mapear timeframes conforme sistema atual
   int macro1Value = 0;  // MACRO-1 (mais longo)
   int macro2Value = 0;  // MACRO-2 (intermediário)
   int macro3Value = 0;  // MACRO-3 (curto) - opcional
   
   // Determinar quais buffers do GG TrendBar usar baseado no sistema definido
   switch(g_tfMacro1)
   {
      case PERIOD_H4:  macro1Value = gg.h4Value;  break;
      case PERIOD_D1:  macro1Value = gg.d1Value;  break;
      case PERIOD_W1:  macro1Value = gg.w1Value;  break;
      case PERIOD_M30: macro1Value = gg.m30Value; break;
      case PERIOD_H1:  macro1Value = gg.h1Value;  break;
   }
   
   switch(g_tfMacro2)
   {
      case PERIOD_H1:  macro2Value = gg.h1Value;  break;
      case PERIOD_H4:  macro2Value = gg.h4Value;  break;
      case PERIOD_D1:  macro2Value = gg.d1Value;  break;
      case PERIOD_M30: macro2Value = gg.m30Value; break;
      case PERIOD_M15: macro2Value = gg.m15Value; break;
   }
   
   if(g_numNiveisMacro == 3)
   {
      switch(g_tfMacro3)
      {
         case PERIOD_M30: macro3Value = gg.m30Value; break;
         case PERIOD_H1:  macro3Value = gg.h1Value;  break;
         case PERIOD_M15: macro3Value = gg.m15Value; break;
         case PERIOD_M5:  macro3Value = gg.m5Value;  break;
      }
   }
   
   PrintFormat("📊 GG TrendBar - MACRO-1(%s)=%+d | MACRO-2(%s)=%+d | MACRO-3(%s)=%+d",
               TimeframeToString(g_tfMacro1), macro1Value,
               TimeframeToString(g_tfMacro2), macro2Value,
               TimeframeToString(g_tfMacro3), macro3Value);
   
   // VALIDAÇÃO 1: MACRO-1 e MACRO-2 devem estar DEFINIDOS (não neutros)
   if(macro1Value == 0 || macro2Value == 0)
   {
      PrintFormat("⚠️ MACRO-1 ou MACRO-2 neutros/indefinidos - aguardar definição");
      return result;
   }
   
   // ✅ CORREÇÃO CRÍTICA: VALIDAÇÃO 2 - Verificar DIREÇÃO (positivo/negativo), não valor exato
   // +1 e +2 = AMBOS BULLISH (mesma direção)
   // -1 e -2 = AMBOS BEARISH (mesma direção)
   bool macro1Bullish = (macro1Value > 0);
   bool macro2Bullish = (macro2Value > 0);
   bool macro1Bearish = (macro1Value < 0);
   bool macro2Bearish = (macro2Value < 0);
   
   // Verificar se estão na MESMA DIREÇÃO (ambos positivos OU ambos negativos)
   if(!((macro1Bullish && macro2Bullish) || (macro1Bearish && macro2Bearish)))
   {
      PrintFormat("⚠️ MACRO-1(%+d) e MACRO-2(%+d) em direções OPOSTAS - aguardar alinhamento",
                  macro1Value, macro2Value);
      return result;
   }
   
   // ✅ MACRO-1 e MACRO-2 ALINHADOS NA MESMA DIREÇÃO!
   result.direction = (macro1Value > 0) ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
   result.h4Aligned = true;
   result.h1Aligned = true;
   
   // Calcular força do alinhamento (ambos +2/-2 = máximo)
   int alignmentStrength = MathMin(MathAbs(macro1Value), MathAbs(macro2Value));
   
   PrintFormat("✅ MACRO-1 + MACRO-2 ALINHADOS: %s (Forças: %+d/%+d, Alinhamento: %d/2)", 
               (result.direction == TRADE_DIRECTION_BUY) ? "BULLISH" : "BEARISH",
               macro1Value, macro2Value, alignmentStrength);
   
   // VALIDAÇÃO 3: MACRO-3 (se aplicável) - BÔNUS para PREMIUM
   if(g_numNiveisMacro == 3)
   {
      if(macro3Value == macro1Value)  // Mesmo sinal
      {
         result.m30Aligned = true;
         PrintFormat("🏆 ALINHAMENTO PREMIUM: MACRO-1 + MACRO-2 + MACRO-3 = %s",
                     (result.direction == TRADE_DIRECTION_BUY) ? "BULLISH" : "BEARISH");
      }
      else if(macro3Value == -macro1Value)  // Oposto
      {
         result.m30Aligned = false;
         
         // CORREÇÃO CRÍTICA: MACRO-3 oposto NÃO deve rejeitar o trade!
         // Deve apenas impedir classificação PREMIUM, mas permite GOOD
         if(AllowCautiousSetups)
         {
            PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 oposto (ACEITO com cautela)");
         }
         else
         {
            PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 oposto (ACEITO, mas não PREMIUM)");
         }
      }
      else  // Neutro
      {
         result.m30Aligned = false;
         PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 neutro");
      }
   }
   else
   {
      // Sistema 2 níveis - sempre GOOD se passou validações
      result.m30Aligned = false;
      PrintFormat("⭐ ALINHAMENTO GOOD: Sistema 2 níveis (MACRO-1 + MACRO-2)");
   }
   
   // Estrutura válida (por ora, simplificado)
   result.structureValid = true;
   result.isValid = true;
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: CalculateSetupScore                                      |
//| Pontua e classifica o setup com base nos filtros micro          |
//|                                                                  |
//| HIERARQUIA v4.2 (NOVO):                                          |
//|   1️⃣ GG TRENDBAR - Já validado (FILTRO MESTRE obrigatório)      |
//|   2️⃣ WAE - Momentum/Explosão                                     |
//|   3️⃣ RSI OMA - Força relativa                                    |
//|   4️⃣ SUPERTREND - Tendência local (opcional)                    |
//|   5️⃣ CURRENCY STRENGTH - Contexto moedas (Forex/Metais)        |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a analisar                                  |
//|   - assetClass: Classe do ativo                                 |
//|   - direction: Direção do alinhamento macro                     |
//|   - m30Aligned: Se MACRO-3 está alinhado (para PREMIUM)        |
//|                                                                  |
//| RETORNO: SetupScore (struct com pontuação e classificação)      |
//+------------------------------------------------------------------+
SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetClass, TRADE_DIRECTION direction, bool m30Aligned)
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 PONTUANDO SETUP - Filtros Micro (GG TrendBar já validado)");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   SetupScore score;
   score.classification = SETUP_REJECT;
   score.direction = direction;
   score.traderMagicPoints = 1; // GG TrendBar já validou multi-TF (FILTRO MESTRE)
   score.currencyStrengthPoints = 0;
   score.rsiomaPoints = 0;
   score.waePoints = 0;
   score.totalPoints = 0;
   
   // Determinar quantos filtros são necessários conforme tipo de ativo
   bool useCS = (assetClass == ASSET_CLASS_FOREX_MAJOR ||
                 assetClass == ASSET_CLASS_FOREX_MINOR ||
                 assetClass == ASSET_CLASS_FOREX_EXOTIC ||
                 assetClass == ASSET_CLASS_CURRENCY_B3 ||
                 assetClass == ASSET_CLASS_METALS);
   
   if(useCS)
   {
      // Sistema 3 filtros: CS + RSI + WAE (precisa 2 de 3)
      score.requiredPoints = 2;
      
      // Currency Strength
      CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetClass);
      if(cs.isValid && cs.isAligned)
      {
         score.currencyStrengthPoints = 1;
      }
      
      // RSI OMA
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      if(rsi.isValid && rsi.isAligned)
      {
         score.rsiomaPoints = 1;
      }
      
      // WAE
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      if(wae.isValid && wae.isAligned)
      {
         score.waePoints = 1;
      }
      
      score.totalPoints = score.currencyStrengthPoints + score.rsiomaPoints + score.waePoints;
      
      // Classificação
      if(score.totalPoints >= 3 && m30Aligned)
      {
         score.classification = SETUP_PREMIUM; // 3/3 + MACRO-3 alinhado
      }
      else if(score.totalPoints >= 2)
      {
         score.classification = SETUP_GOOD; // 2/3
      }
      else
      {
         score.classification = SETUP_REJECT; // <2
      }
   }
   else
   {
      // Sistema 2 filtros: RSI + WAE (precisa 2 de 2) - ÍNDICES
      score.requiredPoints = 2;
      
      // RSI OMA
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      if(rsi.isValid && rsi.isAligned)
      {
         score.rsiomaPoints = 1;
      }
      
      // WAE
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      if(wae.isValid && wae.isAligned)
      {
         score.waePoints = 1;
      }
      
      score.totalPoints = score.rsiomaPoints + score.waePoints;
      
      // Classificação (mais rigorosa para índices)
      if(score.totalPoints >= 2 && m30Aligned)
      {
         score.classification = SETUP_PREMIUM; // 2/2 + MACRO-3 alinhado
      }
      else if(score.totalPoints >= 2)
      {
         score.classification = SETUP_GOOD; // 2/2 mas MACRO-3 não alinhado
      }
      else
      {
         score.classification = SETUP_REJECT; // <2
      }
   }
   
   // Log detalhado com nova hierarquia
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("📊 RESULTADO FINAL - Setup %s:", symbol);
   PrintFormat("   Direção: %s", (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
   PrintFormat("   ✅ GG TrendBar: VALIDADO (Filtro Mestre)");
   PrintFormat("   %s Currency Strength: %d pt", 
               (score.currencyStrengthPoints > 0) ? "✅" : "❌",
               score.currencyStrengthPoints);
   PrintFormat("   %s RSI OMA: %d pt", 
               (score.rsiomaPoints > 0) ? "✅" : "❌",
               score.rsiomaPoints);
   PrintFormat("   %s WAE: %d pt", 
               (score.waePoints > 0) ? "✅" : "❌",
               score.waePoints);
   PrintFormat("   📈 TOTAL: %d/%d pontos", score.totalPoints, score.requiredPoints);
   PrintFormat("   🎯 Classificação: %s",
               (score.classification == SETUP_PREMIUM) ? "🏆 PREMIUM (Máxima Qualidade)" :
               (score.classification == SETUP_GOOD) ? "⭐ GOOD (Boa Qualidade)" : 
               "❌ REJECT (Insuficiente)");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return score;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: ReleaseIndicators                                        |
//| Libera todos os handles dos indicadores                         |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
   PrintFormat("🔓 Liberando handles dos indicadores...");
   
   if(g_handles.gg_global != INVALID_HANDLE)  IndicatorRelease(g_handles.gg_global);
   if(g_handles.st_oper != INVALID_HANDLE)    IndicatorRelease(g_handles.st_oper);
   if(g_handles.wae_oper != INVALID_HANDLE)   IndicatorRelease(g_handles.wae_oper);
   if(g_handles.rsi_oper != INVALID_HANDLE)   IndicatorRelease(g_handles.rsi_oper);
   if(g_handles.cs_oper != INVALID_HANDLE)    IndicatorRelease(g_handles.cs_oper);
   
   PrintFormat("✅ Handles liberados");
}

//+------------------------------------------------------------------+
