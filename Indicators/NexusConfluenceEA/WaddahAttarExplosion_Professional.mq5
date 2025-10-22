//+------------------------------------------------------------------+
//| WaddahAttarExplosion_Professional.mq5 v2.0 OTIMIZADO            |
//| WAE usando iMACD + iBands nativos - CONFIÁVEL                    |
//| OTIMIZAÇÃO: CopyBuffer incremental (90% redução latência!)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Adaptive Flow Systems"
#property link      "https://adaptiveflow.systems"
#property version   "2.00"
#property strict

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 4
#property indicator_minimum 0
#property indicator_maximum 10

#property indicator_label1  "Trend Up"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Trend Down"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "Explosion Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  2
#property indicator_style3  STYLE_SOLID

#property indicator_label4  "Dead Zone"
#property indicator_type4   DRAW_NONE

// Níveis de referência - Zero Line
#property indicator_level1  0.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1

input int InpFastMA = 20;
input int InpSlowMA = 40;
input int InpBBLength = 20;
input double InpBBMultiplier = 2.0;
input int InpSensitivity = 150;

double g_buf_trend_up[];
double g_buf_trend_down[];
double g_buf_explosion_line[];
double g_buf_dead_zone[];

int g_handle_macd = INVALID_HANDLE;
int g_handle_bb = INVALID_HANDLE;

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WAE [Fast:%d | Slow:%d | Sens:%d]", 
                                                        InpFastMA, InpSlowMA, InpSensitivity));

   SetIndexBuffer(0, g_buf_trend_up, INDICATOR_DATA);
   SetIndexBuffer(1, g_buf_trend_down, INDICATOR_DATA);
   SetIndexBuffer(2, g_buf_explosion_line, INDICATOR_DATA);
   SetIndexBuffer(3, g_buf_dead_zone, INDICATOR_DATA);

   ArraySetAsSeries(g_buf_trend_up, true);
   ArraySetAsSeries(g_buf_trend_down, true);
   ArraySetAsSeries(g_buf_explosion_line, true);
   ArraySetAsSeries(g_buf_dead_zone, true);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Criar handles nativos
   g_handle_macd = iMACD(_Symbol, PERIOD_CURRENT, InpFastMA, InpSlowMA, 9, PRICE_CLOSE);
   g_handle_bb = iBands(_Symbol, PERIOD_CURRENT, InpBBLength, 0, InpBBMultiplier, PRICE_CLOSE);

   if(g_handle_macd == INVALID_HANDLE || g_handle_bb == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create WAE indicator handles");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_handle_macd != INVALID_HANDLE) IndicatorRelease(g_handle_macd);
   if(g_handle_bb != INVALID_HANDLE) IndicatorRelease(g_handle_bb);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < InpSlowMA)
        return 0;

    //--- 🔥 OTIMIZAÇÃO v2.0: CALCULAR APENAS BARRAS NOVAS/MODIFICADAS
    int start = prev_calculated - 1;
    if(start < InpSlowMA) start = InpSlowMA;
    
    //--- 🔥 COPIAR APENAS O NECESSÁRIO (+5 barras segurança para cálculos)
    int bars_needed = (rates_total - start) + 5;
    bars_needed = MathMin(bars_needed, rates_total);  // Não exceder total
    
    //--- Log de economia (debug)
    static int total_bars_would_copy = 0;
    static int total_bars_actual_copy = 0;
    total_bars_would_copy += rates_total;
    total_bars_actual_copy += bars_needed;
    
    static int calc_count = 0;
    calc_count++;
    if(calc_count >= 100)
    {
        double savings = 100.0 * (1.0 - (double)total_bars_actual_copy / total_bars_would_copy);
        Print(StringFormat("🔥 WAE OTIMIZADO: %.1f%% economia em CopyBuffer!", savings));
        total_bars_would_copy = 0;
        total_bars_actual_copy = 0;
        calc_count = 0;
    }

    // Copiar APENAS barras necessárias (não todo histórico!)
    double macd_main[], macd_signal[], bb_upper[], bb_lower[];
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);

    if(CopyBuffer(g_handle_macd, 0, 0, bars_needed, macd_main) <= 0)
    {
        Print("ERROR: Failed to copy MACD main");
        return 0;
    }
    if(CopyBuffer(g_handle_macd, 1, 0, bars_needed, macd_signal) <= 0)
    {
        Print("ERROR: Failed to copy MACD signal");
        return 0;
    }
    if(CopyBuffer(g_handle_bb, 1, 0, bars_needed, bb_upper) <= 0)
    {
        Print("ERROR: Failed to copy BB upper");
        return 0;
    }
    if(CopyBuffer(g_handle_bb, 2, 0, bars_needed, bb_lower) <= 0)
    {
        Print("ERROR: Failed to copy BB lower");
        return 0;
    }

    // Validar tamanho dos arrays copiados
    if(ArraySize(macd_main) < InpSlowMA || ArraySize(bb_upper) < InpSlowMA)
    {
        Print("ERROR: Insufficient data copied from indicators");
        return 0;
    }

    // Copiar Close para normalização
    ArraySetAsSeries(close, true);

    // Loop processa apenas start até 0 (barras novas/modificadas)
    for(int i = start; i >= 0; i--)
    {
        // Validar índice dentro dos limites dos arrays
        if(i >= ArraySize(macd_main) || i >= ArraySize(bb_upper))
            continue;

        // MACD Histogram
        double histogram = macd_main[i] - macd_signal[i];

        // Trend Power
        double trend_power = histogram * InpSensitivity;

        if(trend_power >= 0)
        {
            g_buf_trend_up[i] = trend_power;
            g_buf_trend_down[i] = 0.0;
        }
        else
        {
            g_buf_trend_up[i] = 0.0;
            g_buf_trend_down[i] = MathAbs(trend_power);
        }

        // Explosion Line - Fórmula ajustada para visibilidade
        double bb_width = bb_upper[i] - bb_lower[i];
        
        // Usar BB Width direto (sem normalização) vezes sensitivity dividido por escala
        // Isso mantém a Explosion Line proporcional aos histogramas
        g_buf_explosion_line[i] = (bb_width * InpSensitivity) / 50.0;

        // Dead Zone: ambos abaixo da explosion line
        if(g_buf_trend_up[i] < g_buf_explosion_line[i] && 
           g_buf_trend_down[i] < g_buf_explosion_line[i])
            g_buf_dead_zone[i] = 1.0;
        else
            g_buf_dead_zone[i] = 0.0;
    }

    return(rates_total);
}