//+------------------------------------------------------------------+
//| Estrategias.mqh                                                  |
//| Nexus Confluence EA v4.23 - Sistema Multi-Timeframe Universal    |
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
//|   - ReleaseIndicators(): Limpeza COMPLETA ao remover EA         |
//|                                                                   |
//| NOVO v4.12: Supertrend obrigatório + Hierarquia otimizada       |
//| NOVO v4.13: Limpeza total (handles + gráfico + objetos)         |
//| 🔥 CRÍTICO v4.14: CORREÇÃO LÓGICA SUPERTREND (DBL_MAX)         |
//| 🔥 CRÍTICO v4.23: SINCRONIZAÇÃO TEMPORAL + M30 LOGIC            |
//|   - GG TrendBar agora lê candle [0] (era [1])                   |
//|   - M30 divergente não rejeita mais (só PREMIUM vs GOOD)        |
//|   - Logs de debug detalhados para diagnóstico                   |
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Parametros.mqh (enums, structs, inputs)                     |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.23 - Correção Crítica Abertura Ordens                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.23"
#property version   "4.23"
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
   
   // 🔥 CORREÇÃO CRÍTICA v4.14: TrendMagic usa DBL_MAX para buffer INATIVO!
   // - bufferUp pequeno (< 1e10) = Linha UP ATIVA (tendência BULLISH)
   // - bufferDown pequeno (< 1e10) = Linha DOWN ATIVA (tendência BEARISH)
   // - Valor gigante (DBL_MAX ~1.7e308) = Linha INATIVA
   
   double DBL_MAX_LIMIT = 1.0e10; // Threshold para detectar DBL_MAX
   
   // Determinar direção atual (qual linha tem valor VÁLIDO/PEQUENO)
   bool currentBullish = (bufferUp[0] < DBL_MAX_LIMIT && bufferUp[0] > 0);
   bool currentBearish = (bufferDown[0] < DBL_MAX_LIMIT && bufferDown[0] > 0);
   
   // Verificar se mudou de cor recentemente (últimos 2 candles)
   bool wasBullish = (bufferUp[2] < DBL_MAX_LIMIT && bufferUp[2] > 0);
   bool wasBearish = (bufferDown[2] < DBL_MAX_LIMIT && bufferDown[2] > 0);
   
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
   
   // 🔥 v4.26: Buffers usando candle FECHADO [1]
   double baseStrength[1], quoteStrength[1];

   if(CopyBuffer(g_handles.cs_oper, 0, 1, 1, baseStrength) != 1 ||
      CopyBuffer(g_handles.cs_oper, 1, 1, 1, quoteStrength) != 1)
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
   
   // 🔥 v4.26: Usar candle FECHADO [1] para cálculos
   // Calcular inclinação linha vermelha (últimos 3 candles FECHADOS)
   result.slope = (rsiRed[1] - rsiRed[2]) / 1.0;  // [1] vs [2] (1 candle de diferença)
   result.strength = MathAbs(rsiRed[1] - rsiBlue[1]);
   result.isValid = true;

   // Verificar posição e inclinação no candle FECHADO
   bool redAboveBlue = (rsiRed[1] > rsiBlue[1]);
   bool slopePositive = (result.slope > 0.5);  // Mínimo 0.5 de inclinação
   bool slopeNegative = (result.slope < -0.5);

   // ✅ CORREÇÃO CRÍTICA v4.3: Validar zona de sobrecompra/sobrevenda
   bool notOverbought = (rsiRed[1] < RSI_OPER_HighLevel);   // <70 (evita topos)
   bool notOversold = (rsiRed[1] > RSI_OPER_LowLevel);      // >30 (evita fundos)

   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para compra: linha vermelha acima da azul + inclinação positiva + NÃO sobrecomprado
      result.isAligned = (redAboveBlue && slopePositive && notOverbought);

      if(!notOverbought)
         PrintFormat("   ⚠️ RSI OMA rejeitado: RSI=%.1f >= %.1f (sobrecompra)", rsiRed[1], RSI_OPER_HighLevel);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para venda: linha vermelha abaixo da azul + inclinação negativa + NÃO sobrevendido
      result.isAligned = (!redAboveBlue && slopeNegative && notOversold);

      if(!notOversold)
         PrintFormat("   ⚠️ RSI OMA rejeitado: RSI=%.1f <= %.1f (sobrevenda)", rsiRed[1], RSI_OPER_LowLevel);
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
   
   // 🔥 v4.26: Usar candle FECHADO [1] para análise
   // Determinar cor do histograma (verde ou vermelho) no candle FECHADO
   bool isGreen = (trendUp[1] > trendDown[1] && trendUp[1] > 0);
   bool isRed = (trendDown[1] > trendUp[1] && trendDown[1] > 0);

   // Calcular força do histograma no candle FECHADO
   double currentStrength = MathMax(trendUp[1], trendDown[1]);
   result.strength = currentStrength;

   // Verificar expansão (últimos 3 candles FECHADOS)
   bool expanding = (MathMax(trendUp[1], trendDown[1]) > MathMax(trendUp[2], trendDown[2]));
   result.isExpanding = expanding;

   // Verificar se está acima da linha de explosão
   double explosion_val[1];
   if(CopyBuffer(handle, 2, 1, 1, explosion_val) == 1)
   {
      bool aboveExplosion = (currentStrength > explosion_val[0]);
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
   // 🔥 v4.21: LER CANDLE FECHADO [1] ao invés do atual [0] para garantir valores CONFIRMADOS
   double gg_m1[2], gg_m5[2], gg_m15[2], gg_m30[2], gg_h1[2], gg_h4[2], gg_d1[2], gg_w1[2], gg_mn1[2];
   
   if(CopyBuffer(g_handles.gg_global, 0, 0, 2, gg_m1) != 2 ||
      CopyBuffer(g_handles.gg_global, 2, 0, 2, gg_m5) != 2 ||
      CopyBuffer(g_handles.gg_global, 4, 0, 2, gg_m15) != 2 ||
      CopyBuffer(g_handles.gg_global, 6, 0, 2, gg_m30) != 2 ||
      CopyBuffer(g_handles.gg_global, 8, 0, 2, gg_h1) != 2 ||
      CopyBuffer(g_handles.gg_global, 10, 0, 2, gg_h4) != 2 ||
      CopyBuffer(g_handles.gg_global, 12, 0, 2, gg_d1) != 2 ||
      CopyBuffer(g_handles.gg_global, 14, 0, 2, gg_w1) != 2 ||
      CopyBuffer(g_handles.gg_global, 16, 0, 2, gg_mn1) != 2)
   {
      PrintFormat("❌ Erro ao copiar buffers GG TrendBar");
      return result;
   }
   
   // 🔥 v4.26 CORREÇÃO CRÍTICA FINAL: LER CANDLE FECHADO [1]!
   // PROBLEMA v4.23: Usava [0] = candle EM FORMAÇÃO (valores instáveis!)
   // MOTIVO: EA executa em NOVO CANDLE, mas [0] acabou de abrir (valores iniciais)
   // RESULTADO: Dessincronia - EA vê valores DIFERENTES dos sinais visuais
   // SOLUÇÃO DEFINITIVA: LER CANDLE FECHADO [1] = valores CONFIRMADOS

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.26] CANDLE FECHADO [1] (CONFIRMADO E ESTÁVEL):");
   PrintFormat("   M1=%.0f | M5=%.0f | M15=%.0f | M30=%.0f | H1=%.0f | H4=%.0f | D1=%.0f | W1=%.0f | MN1=%.0f",
               gg_m1[1], gg_m5[1], gg_m15[1], gg_m30[1], gg_h1[1], gg_h4[1], gg_d1[1], gg_w1[1], gg_mn1[1]);

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.26] CANDLE ATUAL [0] (EM FORMAÇÃO - NÃO USAR!):");
   PrintFormat("   M1=%.0f | M5=%.0f | M15=%.0f | M30=%.0f | H1=%.0f | H4=%.0f | D1=%.0f | W1=%.0f | MN1=%.0f",
               gg_m1[0], gg_m5[0], gg_m15[0], gg_m30[0], gg_h1[0], gg_h4[0], gg_d1[0], gg_w1[0], gg_mn1[0]);

   // 🔥 v4.26: USAR CANDLE FECHADO [1] para SINCRONIZAR COM SINAIS VISUAIS
   // Todos os filtros (GG, WAE, RSI, CS) agora leem [1] → MESMOS VALORES QUE APARECEM NO GRÁFICO!
   result.m1Value = (int)gg_m1[1];
   result.m5Value = (int)gg_m5[1];
   result.m15Value = (int)gg_m15[1];
   result.m30Value = (int)gg_m30[1];
   result.h1Value = (int)gg_h1[1];
   result.h4Value = (int)gg_h4[1];
   result.d1Value = (int)gg_d1[1];
   result.w1Value = (int)gg_w1[1];
   result.mn1Value = (int)gg_mn1[1];

   PrintFormat("🔍 [DEBUG GG TRENDBAR v4.26] Valores convertidos (int) do candle [1] - CONFIRMADOS:");
   PrintFormat("   M1=%+d | M5=%+d | M15=%+d | M30=%+d | H1=%+d | H4=%+d | D1=%+d | W1=%+d | MN1=%+d",
               result.m1Value, result.m5Value, result.m15Value, result.m30Value,
               result.h1Value, result.h4Value, result.d1Value, result.w1Value, result.mn1Value);
   
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
   
   // 🔥 v4.23 DEBUG DETALHADO: Análise completa dos timeframes
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("📊 GG TrendBar - LEITURA DOS TIMEFRAMES:");
   PrintFormat("   MACRO-1 (%s): %+d %s",
               TimeframeToString(g_tfMacro1), macro1Value,
               (macro1Value > 0) ? "🟢 BULLISH" : (macro1Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   PrintFormat("   MACRO-2 (%s): %+d %s",
               TimeframeToString(g_tfMacro2), macro2Value,
               (macro2Value > 0) ? "🟢 BULLISH" : (macro2Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   if(g_numNiveisMacro == 3)
   {
      PrintFormat("   MACRO-3 (%s): %+d %s",
                  TimeframeToString(g_tfMacro3), macro3Value,
                  (macro3Value > 0) ? "🟢 BULLISH" : (macro3Value < 0) ? "🔴 BEARISH" : "⚪ NEUTRO");
   }
   PrintFormat("────────────────────────────────────────────────────────────────");

   // ✅ VALIDAÇÃO 1: Pelo menos UM dos MACRO deve estar DEFINIDO (não neutro)
   if(macro1Value == 0 && macro2Value == 0)
   {
      PrintFormat("❌ REJEIÇÃO ETAPA 1: MACRO-1 e MACRO-2 AMBOS NEUTROS");
      PrintFormat("   Aguardando definição de tendência nos timeframes macro");
      PrintFormat("════════════════════════════════════════════════════════════════");
      return result;
   }
   
   // ✅ VALIDAÇÃO 2: Se ambos definidos, devem estar na MESMA DIREÇÃO
   if(macro1Value != 0 && macro2Value != 0)
   {
      // Ambos definidos - verificar se mesma direção
      bool macro1Bullish = (macro1Value > 0);
      bool macro2Bullish = (macro2Value > 0);
      bool macro1Bearish = (macro1Value < 0);
      bool macro2Bearish = (macro2Value < 0);
      
      // Verificar se estão na MESMA DIREÇÃO (ambos positivos OU ambos negativos)
      if(!((macro1Bullish && macro2Bullish) || (macro1Bearish && macro2Bearish)))
      {
         PrintFormat("❌ REJEIÇÃO ETAPA 2: TIMEFRAMES EM DIREÇÕES OPOSTAS");
         PrintFormat("   MACRO-1 (%s): %s", TimeframeToString(g_tfMacro1),
                     macro1Bullish ? "🟢 BULLISH" : "🔴 BEARISH");
         PrintFormat("   MACRO-2 (%s): %s", TimeframeToString(g_tfMacro2),
                     macro2Bullish ? "🟢 BULLISH" : "🔴 BEARISH");
         PrintFormat("   Aguardando alinhamento entre os timeframes macro");
         PrintFormat("════════════════════════════════════════════════════════════════");
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
   }
   else
   {
      // ✅ APENAS UM DEFINIDO - usar esse como direção (modo fallback)
      if(macro1Value != 0)
      {
         result.direction = (macro1Value > 0) ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
         result.h4Aligned = true;
         result.h1Aligned = false;  // H1 neutro
         PrintFormat("⚠️ FALLBACK: Apenas MACRO-1(%+d) definido, MACRO-2 neutro - usando MACRO-1 como direção",
                     macro1Value);
      }
      else  // macro2Value != 0
      {
         result.direction = (macro2Value > 0) ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
         result.h4Aligned = false;  // H4 neutro
         result.h1Aligned = true;
         PrintFormat("⚠️ FALLBACK: Apenas MACRO-2(%+d) definido, MACRO-1 neutro - usando MACRO-2 como direção",
                     macro2Value);
      }
   }
   
   // VALIDAÇÃO 3: MACRO-3 (se aplicável) - BÔNUS para PREMIUM
   if(g_numNiveisMacro == 3)
   {
      // 🔥 v4.23 CORREÇÃO CRÍTICA: M30 divergente NÃO deve rejeitar, apenas impede PREMIUM
      int expectedValue = (result.direction == TRADE_DIRECTION_BUY) ? 1 : -1;

      if(macro3Value == expectedValue)  // MACRO-3 alinha com direção do trade
      {
         result.m30Aligned = true;
         PrintFormat("🏆 ALINHAMENTO PREMIUM: MACRO-1 + MACRO-2 + MACRO-3 = %s",
                     (result.direction == TRADE_DIRECTION_BUY) ? "BULLISH" : "BEARISH");
      }
      else if(macro3Value == -expectedValue)  // MACRO-3 oposto à direção
      {
         result.m30Aligned = false;

         // 🔥 v4.23: M30 OPOSTO = SETUP GOOD (NÃO REJEITAR!)
         // BUG v4.21: Rejeitava se AllowGoodSetups=false mesmo com H4+H1 válidos
         // CORREÇÃO: M30 só define PREMIUM vs GOOD, não válido vs inválido
         PrintFormat("⭐ ALINHAMENTO GOOD: MACRO-1+MACRO-2 alinhados, MACRO-3 oposto");
         PrintFormat("   ⚠️ MACRO-3 divergente - será classificado como GOOD (não PREMIUM)");
         // NÃO retornar aqui! Continuar validação (será GOOD se 2/3 filtros)
      }
      else  // Neutro (macro3Value == 0)
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

   // 🔥 v4.23 LOG RESUMO FINAL DO ALINHAMENTO
   PrintFormat("────────────────────────────────────────────────────────────────");
   PrintFormat("✅ MULTI-TIMEFRAME APROVADO:");
   PrintFormat("   Direção: %s", (result.direction == TRADE_DIRECTION_BUY) ? "🟢 COMPRA" : "🔴 VENDA");
   PrintFormat("   H4 Alinhado: %s", result.h4Aligned ? "✅" : "❌");
   PrintFormat("   H1 Alinhado: %s", result.h1Aligned ? "✅" : "❌");
   PrintFormat("   M30 Alinhado: %s (determina PREMIUM vs GOOD)", result.m30Aligned ? "✅" : "❌");
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
   
   // ═══════════════════════════════════════════════════════════════════════
   // 🔥 CORREÇÃO CRÍTICA v4.12: ADICIONAR VALIDAÇÃO SUPERTREND OBRIGATÓRIA
   // ═══════════════════════════════════════════════════════════════════════
   PrintFormat("🎯 [FILTRO OBRIGATÓRIO] Validando Supertrend Operacional (%s)...", 
               TimeframeToString(g_tfOperacional));
   
   // Verificar Supertrend no timeframe operacional
   TMSignal supertrend = GetSupertrendSignal(g_handles.st_oper, g_tfOperacional);
   
   // 🔥 v4.20: LOG DETALHADO do Supertrend
   PrintFormat("🔍 [DEBUG SUPERTREND] Leitura do indicador:");
   PrintFormat("   isValid: %s", supertrend.isValid ? "SIM" : "NÃO");
   PrintFormat("   direction: %s", 
               (supertrend.direction == TRADE_DIRECTION_BUY) ? "📈 BUY" :
               (supertrend.direction == TRADE_DIRECTION_SELL) ? "📉 SELL" : "⚠️ NONE");
   PrintFormat("   turnedRecently: %s", supertrend.turnedRecently ? "SIM (BÔNUS!)" : "NÃO");
   PrintFormat("   strength: %.5f", supertrend.strength);
   
   if(!supertrend.isValid)
   {
      PrintFormat("⚠️ Supertrend INVÁLIDO - aguardar confirmação");
      PrintFormat("   Razão: Indicador não retornou sinal válido");
      score.classification = SETUP_REJECT;
      return score;
   }
   
   // Validar se Supertrend alinha com direção GG TrendBar
   if(supertrend.direction != direction)
   {
      PrintFormat("❌ SUPERTREND CONTRA DIREÇÃO GG TRENDBAR - REJECT!");
      PrintFormat("   GG TrendBar: %s", (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
      PrintFormat("   Supertrend: %s", (supertrend.direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
      PrintFormat("   ⚠️ Macro e Micro NÃO estão alinhados - aguardar convergência");
      score.classification = SETUP_REJECT;
      return score;
   }
   
   PrintFormat("✅ Supertrend ALINHADO com GG TrendBar (%s)", 
               (direction == TRADE_DIRECTION_BUY) ? "📈 BUY" : "📉 SELL");
   if(supertrend.turnedRecently)
   {
      PrintFormat("   🎯 BÔNUS: Virada recente detectada (entrada em momentum)");
   }
   // ═══════════════════════════════════════════════════════════════════════
   
   // Determinar quantos filtros são necessários conforme tipo de ativo
   bool useCS = (assetClass == ASSET_CLASS_FOREX_MAJOR ||
                 assetClass == ASSET_CLASS_FOREX_MINOR ||
                 assetClass == ASSET_CLASS_FOREX_EXOTIC ||
                 assetClass == ASSET_CLASS_CURRENCY_B3 ||
                 assetClass == ASSET_CLASS_METALS);
   
   if(useCS)
   {
      // Sistema 3 filtros: WAE + RSI + CS (precisa 2 de 3)
      // ✅ CORREÇÃO v4.12: Ordem otimizada - WAE primeiro (momentum crítico)
      score.requiredPoints = 2;
      
      PrintFormat("────────────────────────────────────────────────────────────────");
      PrintFormat("📊 Analisando Filtros Micro (ORDEM OTIMIZADA):");
      
      // 1️⃣ WAE - MOMENTUM (prioridade máxima)
      PrintFormat("1️⃣ WAE (Momentum/Explosão)...");
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      if(wae.isValid && wae.isAligned)
      {
         score.waePoints = 1;
         PrintFormat("   ✅ WAE alinhado (+1 ponto) - Força: %.2f | Expandindo: %s", 
                     wae.strength, wae.isExpanding ? "SIM" : "NÃO");
      }
      else
      {
         PrintFormat("   ❌ WAE não alinhado (0 pontos)");
      }
      
      // 2️⃣ RSI OMA - FORÇA RELATIVA (OBRIGATÓRIO!)
      PrintFormat("2️⃣ RSI OMA (Força Relativa - OBRIGATÓRIO)...");
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      
      // 🔥 v4.22 CORREÇÃO CRÍTICA: RSI OMA OBRIGATÓRIO!
      // BUG v4.21: Se rsi.isValid=false, continuava sem RSI
      // Evidência: Imagem 6 mostrou RSI bullish mas EA vendeu!
      if(!rsi.isValid)
      {
         PrintFormat("   ❌ RSI OMA INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(rsi.isAligned)
      {
         score.rsiomaPoints = 1;
         PrintFormat("   ✅ RSI OMA alinhado (+1 ponto) - Separação: %.2f | Inclinação: %.2f", 
                     rsi.strength, rsi.slope);
      }
      else
      {
         PrintFormat("   ❌ RSI OMA não alinhado (0 pontos) - Mas VÁLIDO");
      }
      
      // 3️⃣ CURRENCY STRENGTH - CONTEXTO
      PrintFormat("3️⃣ Currency Strength (Contexto Moedas)...");
      CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetClass);
      if(cs.isValid && cs.isAligned)
      {
         score.currencyStrengthPoints = 1;
         PrintFormat("   ✅ Currency Strength alinhado (+1 ponto) - Separação: %.2f", cs.strength);
      }
      else
      {
         PrintFormat("   ❌ Currency Strength não alinhado (0 pontos)");
      }
      
      score.totalPoints = score.waePoints + score.rsiomaPoints + score.currencyStrengthPoints;
      
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
      // Sistema 2 filtros: WAE + RSI (precisa 2 de 2) - ÍNDICES
      // ✅ CORREÇÃO v4.12: Ordem otimizada - WAE primeiro
      score.requiredPoints = 2;
      
      PrintFormat("────────────────────────────────────────────────────────────────");
      PrintFormat("📊 Analisando Filtros Micro - ÍNDICES (ORDEM OTIMIZADA):");
      
      // 1️⃣ WAE - MOMENTUM
      PrintFormat("1️⃣ WAE (Momentum/Explosão)...");
      WAESignal wae = GetWAESignal(g_handles.wae_oper, direction, g_tfOperacional);
      if(wae.isValid && wae.isAligned)
      {
         score.waePoints = 1;
         PrintFormat("   ✅ WAE alinhado (+1 ponto) - Força: %.2f | Expandindo: %s", 
                     wae.strength, wae.isExpanding ? "SIM" : "NÃO");
      }
      else
      {
         PrintFormat("   ❌ WAE não alinhado (0 pontos)");
      }
      
      // 2️⃣ RSI OMA - FORÇA RELATIVA (OBRIGATÓRIO!)
      PrintFormat("2️⃣ RSI OMA (Força Relativa - OBRIGATÓRIO)...");
      RSISignal rsi = GetRSIOMASignal(g_handles.rsi_oper, direction, g_tfOperacional);
      
      // 🔥 v4.22 CORREÇÃO CRÍTICA: RSI OMA OBRIGATÓRIO também para ÍNDICES!
      if(!rsi.isValid)
      {
         PrintFormat("   ❌ RSI OMA INVÁLIDO - REJEITANDO SETUP COMPLETO!");
         score.classification = SETUP_REJECT;
         score.totalPoints = 0;
         return score;
      }
      
      if(rsi.isAligned)
      {
         score.rsiomaPoints = 1;
         PrintFormat("   ✅ RSI OMA alinhado (+1 ponto) - Separação: %.2f | Inclinação: %.2f", 
                     rsi.strength, rsi.slope);
      }
      else
      {
         PrintFormat("   ❌ RSI OMA não alinhado (0 pontos) - Mas VÁLIDO");
      }
      
      score.totalPoints = score.waePoints + score.rsiomaPoints;
      
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
   PrintFormat("   ✅ GG TrendBar: VALIDADO (Filtro Mestre Macro)");
   PrintFormat("   ✅ Supertrend: ALINHADO (Filtro Obrigatório Micro)");
   PrintFormat("   %s WAE (Momentum): %d pt", 
               (score.waePoints > 0) ? "✅" : "❌",
               score.waePoints);
   PrintFormat("   %s RSI OMA (Força): %d pt", 
               (score.rsiomaPoints > 0) ? "✅" : "❌",
               score.rsiomaPoints);
   PrintFormat("   %s Currency Strength (Contexto): %d pt", 
               (score.currencyStrengthPoints > 0) ? "✅" : "❌",
               score.currencyStrengthPoints);
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
//| Libera handles E remove objetos visuais do gráfico              |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("🔓 LIMPANDO INDICADORES E OBJETOS VISUAIS...");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 1: Liberar handles (memória)
   // ═══════════════════════════════════════════════════════════════
   int handlesLiberados = 0;
   
   if(g_handles.gg_global != INVALID_HANDLE)  
   {
      IndicatorRelease(g_handles.gg_global);
      handlesLiberados++;
      PrintFormat("   ✅ Handle GG TrendBar liberado");
   }
   
   if(g_handles.st_oper != INVALID_HANDLE)    
   {
      IndicatorRelease(g_handles.st_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle Supertrend liberado");
   }
   
   if(g_handles.wae_oper != INVALID_HANDLE)   
   {
      IndicatorRelease(g_handles.wae_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle WAE liberado");
   }
   
   if(g_handles.rsi_oper != INVALID_HANDLE)   
   {
      IndicatorRelease(g_handles.rsi_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle RSI OMA liberado");
   }
   
   if(g_handles.cs_oper != INVALID_HANDLE)    
   {
      IndicatorRelease(g_handles.cs_oper);
      handlesLiberados++;
      PrintFormat("   ✅ Handle Currency Strength liberado");
   }
   
   PrintFormat("📊 Total de handles liberados: %d", handlesLiberados);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 2: Remover TODOS os indicadores do gráfico (janelas)
   // ═══════════════════════════════════════════════════════════════
   int indicatorsRemoved = 0;
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   
   PrintFormat("\n🔍 Detectadas %d janelas no gráfico (incluindo principal)", totalWindows);
   
   // Remover indicadores das sub-janelas (janela 1, 2, 3...)
   // IMPORTANTE: Começar do fim para não bagunçar índices
   for(int window = totalWindows - 1; window >= 1; window--)
   {
      int indicatorsInWindow = ChartIndicatorsTotal(0, window);
      PrintFormat("   📊 Janela %d: %d indicador(es)", window, indicatorsInWindow);
      
      // Remover todos os indicadores desta janela
      for(int i = indicatorsInWindow - 1; i >= 0; i--)
      {
         string indicatorName = ChartIndicatorName(0, window, i);
         if(indicatorName != "")
         {
            if(ChartIndicatorDelete(0, window, indicatorName))
            {
               indicatorsRemoved++;
               PrintFormat("      ✅ Removido: %s", indicatorName);
            }
            else
            {
               PrintFormat("      ⚠️ Falha ao remover: %s", indicatorName);
            }
         }
      }
   }
   
   // Remover indicadores da janela principal (janela 0)
   int mainWindowIndicators = ChartIndicatorsTotal(0, 0);
   PrintFormat("   📊 Janela principal: %d indicador(es)", mainWindowIndicators);
   
   for(int i = mainWindowIndicators - 1; i >= 0; i--)
   {
      string indicatorName = ChartIndicatorName(0, 0, i);
      if(indicatorName != "")
      {
         // FILTRO: Só remover indicadores do Nexus (evitar remover outros EAs)
         if(StringFind(indicatorName, "GG_TrendBar") >= 0 ||
            StringFind(indicatorName, "TrendMagic") >= 0 ||
            StringFind(indicatorName, "Supertrend") >= 0 ||
            StringFind(indicatorName, "WAE") >= 0 ||
            StringFind(indicatorName, "Waddah") >= 0 ||
            StringFind(indicatorName, "RSI") >= 0 ||
            StringFind(indicatorName, "RSIOMA") >= 0 ||
            StringFind(indicatorName, "Currency") >= 0 ||
            StringFind(indicatorName, "Strength") >= 0)
         {
            if(ChartIndicatorDelete(0, 0, indicatorName))
            {
               indicatorsRemoved++;
               PrintFormat("      ✅ Removido: %s", indicatorName);
            }
            else
            {
               PrintFormat("      ⚠️ Falha ao remover: %s", indicatorName);
            }
         }
      }
   }
   
   PrintFormat("📊 Total de indicadores removidos do gráfico: %d", indicatorsRemoved);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 3: Remover objetos gráficos (textos, linhas, etc)
   // ═══════════════════════════════════════════════════════════════
   int objectsRemoved = 0;
   int totalObjects = ObjectsTotal(0);
   
   PrintFormat("\n🔍 Detectados %d objetos gráficos no gráfico", totalObjects);
   
   // Remover objetos que começam com prefixos conhecidos do Nexus
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // FILTRO: Só remover objetos do Nexus
      if(StringFind(objName, "Nexus") >= 0 ||
         StringFind(objName, "GG_") >= 0 ||
         StringFind(objName, "TM_") >= 0 ||
         StringFind(objName, "WAE_") >= 0 ||
         StringFind(objName, "RSI_") >= 0 ||
         StringFind(objName, "CS_") >= 0)
      {
         if(ObjectDelete(0, objName))
         {
            objectsRemoved++;
            PrintFormat("   ✅ Objeto removido: %s", objName);
         }
      }
   }
   
   PrintFormat("📊 Total de objetos gráficos removidos: %d", objectsRemoved);
   
   // ═══════════════════════════════════════════════════════════════
   // ETAPA 4: Forçar redesenho do gráfico
   // ═══════════════════════════════════════════════════════════════
   ChartRedraw(0);
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("✅ LIMPEZA COMPLETA!");
   PrintFormat("   Handles liberados: %d", handlesLiberados);
   PrintFormat("   Indicadores removidos: %d", indicatorsRemoved);
   PrintFormat("   Objetos removidos: %d", objectsRemoved);
   PrintFormat("════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
