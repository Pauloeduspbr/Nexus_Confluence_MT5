//+------------------------------------------------------------------+
//|                                                 OBV_MACD.mq5     |
//|                        MACD baseado em OBV (Tick ou Real)        |
//|         Histograma multi-cor: força, enfraquecimento, reversão   |
//+------------------------------------------------------------------+
#property copyright   "Nexus Confluence EA"
#property link        "https://adaptiveflow.systems"
#property version     "4.00"
#property description "MACD do OBV - Histogram + MACD Line + Signal Line"
#property description "v4.00: WINDOWED OBV - Uses rolling window instead of infinite accumulation"
#property description "Fixed: Histogram responds immediately to trend changes"

#property indicator_separate_window
#property indicator_plots   3  // Histogram + MACD + Signal
#property indicator_buffers  10  // Reduced from 11 (removed DirectionBuffer)
#property indicator_level1  0.0
#property indicator_levelcolor clrSilver

//--- Plot 1: Histograma com 4 cores
#property indicator_label1  "OBV Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_width1  2
#property indicator_color1  clrLime,clrRed,clrPaleGreen,clrLightPink

//--- Plot 2: MACD Line (OBV MACD)
#property indicator_label2  "OBV MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

//--- Plot 3: Signal Line (OBV Signal)
#property indicator_label3  "OBV Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCornflowerBlue
#property indicator_width3  1
#property indicator_style3  STYLE_SOLID

#include <MovingAverages.mqh>

//--- Inputs (v4.00: WINDOWED OBV for faster response)
input int   InpFastEMA=5;                 // Fast EMA Period (reduced from 8)
input int   InpSlowEMA=13;                // Slow EMA Period (reduced from 17)
input int   InpSignalSMA=4;               // Signal EMA Period (reduced from 6)
input int   InpObvWindow=20;              // OBV Lookback Window (NEW - key fix)
input bool  InpUseTickVolume=true;        // Use Tick Volume (true) ou Real Volume (false)
input bool  InpShowMACDLine=true;         // Show MACD Line
input bool  InpShowSignalLine=true;       // Show Signal Line
input int   InpThreshPeriod=14;           // Threshold EMA period (reduced from 21)
input double InpThreshMult=0.4;           // Threshold multiplier (reduced from 0.5)

//--- Buffers
// Plot buffers (visible)
double HistBuffer[];        // Histograma (MACD - Signal)
double HistColorBuffer[];   // Índice de cor
double MacdLineBuffer[];    // Linha MACD
double SignalLineBuffer[];  // Linha Signal
double ThresholdBuffer[];   // Linha de limiar

// Calculation buffers (internal)
double FastObvEmaBuffer[];
double SlowObvEmaBuffer[];
double ObvWindowBuffer[];   // OBV com janela (não mais cumulativo infinito)
double ObvDeltaBuffer[];    // Delta de OBV por barra (volume com sinal)
double AbsHistCalc[];       // |histogram| para threshold

enum ENUM_PLOT_COLOR_INDEX {
   COLOR_POS_STRONG=0,  // Verde forte (hist >=0 e aumentando)
   COLOR_NEG_STRONG=1,  // Vermelho forte (hist <0 e diminuindo)
   COLOR_POS_WEAK =2,   // Verde fraco (hist >=0 mas enfraquecendo)
   COLOR_NEG_WEAK =3    // Vermelho fraco (hist <0 mas recuperando)
};

//+------------------------------------------------------------------+
//| OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // ═══════════════════════════════════════════════════════════════
   // Buffer mapping: 3 visible plots + 7 calculation buffers = 10 total
   // Plot index 0: Histogram (buffers 0+1: data + color index)
   // Plot index 1: MACD Line (buffer 2: visible)
   // Plot index 2: Signal Line (buffer 3: visible)
   // Buffer 4: Threshold (calculation - EA reads)
   // Buffers 5-9: Calculation buffers
   // ═══════════════════════════════════════════════════════════════
   
   // Plot index 0 (Plot 1 in properties): Histogram with color index
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer, INDICATOR_COLOR_INDEX);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrPaleGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrLightPink);
   PlotIndexSetString(0, PLOT_LABEL, "OBV Histogram");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   // Plot index 1 (Plot 2 in properties): MACD Line (OBV MACD - laranja)
   SetIndexBuffer(2, MacdLineBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrangeRed);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetString(1, PLOT_LABEL, "OBV MACD");
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Plot index 2 (Plot 3 in properties): Signal Line (azul)
   SetIndexBuffer(3, SignalLineBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrCornflowerBlue);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetString(2, PLOT_LABEL, "OBV Signal");
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Buffer 4: Threshold (calculation only - EA reads this)
   SetIndexBuffer(4, ThresholdBuffer, INDICATOR_CALCULATIONS);

   // Calculation buffers (INDICATOR_CALCULATIONS)
   SetIndexBuffer(5, FastObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SlowObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, ObvWindowBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ObvDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, AbsHistCalc, INDICATOR_CALCULATIONS);

   string short_name = StringFormat("OBV MACD (%d,%d,%d) W%d", 
                                    InpFastEMA, InpSlowEMA, InpSignalSMA, InpObvWindow);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                     |
//+------------------------------------------------------------------+
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
   int minBars = MathMax(InpObvWindow + InpSlowEMA + 5, 30);
   if(rates_total < minBars)
      return(0);

   // v4.00: Recalcular desde o início da janela para garantir precisão
   int start = prev_calculated;
   if(start <= 0)
   {
      ArrayInitialize(HistBuffer, 0.0);
      ArrayInitialize(HistColorBuffer, 0.0);
      ArrayInitialize(MacdLineBuffer, EMPTY_VALUE);
      ArrayInitialize(SignalLineBuffer, EMPTY_VALUE);
      ArrayInitialize(FastObvEmaBuffer, 0.0);
      ArrayInitialize(SlowObvEmaBuffer, 0.0);
      ArrayInitialize(ObvWindowBuffer, 0.0);
      ArrayInitialize(ObvDeltaBuffer, 0.0);
      ArrayInitialize(AbsHistCalc, 0.0);
      start = 1;
   }
   else
   {
      // Recalcular últimas barras
      start = MathMax(rates_total - 2, 1);
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 1: Calculate OBV Delta per bar (signed volume)
   // This is the building block for windowed OBV
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; ++i)
   {
      double vol = InpUseTickVolume ? (double)tick_volume[i] : (double)volume[i];
      
      if(close[i] > close[i-1])
         ObvDeltaBuffer[i] = vol;
      else if(close[i] < close[i-1])
         ObvDeltaBuffer[i] = -vol;
      else
         ObvDeltaBuffer[i] = 0.0;
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 2: Calculate WINDOWED OBV (sum of last N deltas)
   // ✅ v4.00 KEY FIX: This eliminates the infinite accumulation lag!
   // Instead of cumulative OBV since chart start, we only look at
   // the last InpObvWindow bars. This makes reversals instant.
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; ++i)
   {
      double obvSum = 0.0;
      int lookback = MathMin(i, InpObvWindow);
      
      // Sum the OBV deltas over the window
      for(int j = 0; j < lookback; ++j)
      {
         obvSum += ObvDeltaBuffer[i - j];
      }
      
      ObvWindowBuffer[i] = obvSum;
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 3: Calculate Fast and Slow EMAs on Windowed OBV
   // Using faster EMA constants for quicker response
   // ═══════════════════════════════════════════════════════════════
   if(prev_calculated == 0)
   {
      // Initialize at first valid bar
      int initBar = InpObvWindow;
      if(initBar < rates_total)
      {
         FastObvEmaBuffer[initBar] = ObvWindowBuffer[initBar];
         SlowObvEmaBuffer[initBar] = ObvWindowBuffer[initBar];
      }
   }
   
   double kFast = 2.0 / (InpFastEMA + 1.0);
   double kSlow = 2.0 / (InpSlowEMA + 1.0);
   
   int emaStart = MathMax(start, InpObvWindow + 1);
   for(int i = emaStart; i < rates_total; ++i)
   {
      // Ensure previous values exist
      if(FastObvEmaBuffer[i-1] == 0.0 && i > InpObvWindow)
      {
         FastObvEmaBuffer[i-1] = ObvWindowBuffer[i-1];
         SlowObvEmaBuffer[i-1] = ObvWindowBuffer[i-1];
      }
      
      FastObvEmaBuffer[i] = FastObvEmaBuffer[i-1] + kFast * (ObvWindowBuffer[i] - FastObvEmaBuffer[i-1]);
      SlowObvEmaBuffer[i] = SlowObvEmaBuffer[i-1] + kSlow * (ObvWindowBuffer[i] - SlowObvEmaBuffer[i-1]);
      MacdLineBuffer[i] = FastObvEmaBuffer[i] - SlowObvEmaBuffer[i];
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 4: Calculate Signal Line (EMA of MACD)
   // ═══════════════════════════════════════════════════════════════
   double kSignal = 2.0 / (InpSignalSMA + 1.0);
   
   int sigStart = MathMax(emaStart, InpObvWindow + 2);
   if(prev_calculated == 0 && sigStart < rates_total)
   {
      SignalLineBuffer[sigStart] = MacdLineBuffer[sigStart];
   }
   
   for(int i = MathMax(start, sigStart + 1); i < rates_total; ++i)
   {
      if(SignalLineBuffer[i-1] == EMPTY_VALUE || SignalLineBuffer[i-1] == 0.0)
         SignalLineBuffer[i] = MacdLineBuffer[i];
      else
         SignalLineBuffer[i] = SignalLineBuffer[i-1] + kSignal * (MacdLineBuffer[i] - SignalLineBuffer[i-1]);
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 5: Calculate Histogram and Color Index
   // Simplified - no need for direction boost with windowed OBV
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; ++i)
   {
      if(MacdLineBuffer[i] == EMPTY_VALUE || SignalLineBuffer[i] == EMPTY_VALUE)
      {
         HistBuffer[i] = 0.0;
         HistColorBuffer[i] = 0.0;
         continue;
      }
      
      double hist = MacdLineBuffer[i] - SignalLineBuffer[i];
      HistBuffer[i] = hist;
      AbsHistCalc[i] = MathAbs(hist);
      
      int color_index = 0;
      
      if(i <= InpObvWindow + 2)
      {
         color_index = (hist >= 0.0) ? COLOR_POS_STRONG : COLOR_NEG_STRONG;
      }
      else
      {
         double prev_hist = HistBuffer[i-1];
         
         if(hist >= 0.0)
         {
            // Positive histogram
            color_index = (hist >= prev_hist) ? COLOR_POS_STRONG : COLOR_POS_WEAK;
         }
         else
         {
            // Negative histogram
            color_index = (hist <= prev_hist) ? COLOR_NEG_STRONG : COLOR_NEG_WEAK;
         }
      }
      
      HistColorBuffer[i] = (double)color_index;
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 6: Calculate Threshold = EMA(|hist| * mult)
   // ═══════════════════════════════════════════════════════════════
   if(InpThreshPeriod <= 1)
   {
      for(int i = start; i < rates_total; ++i)
         ThresholdBuffer[i] = AbsHistCalc[i] * InpThreshMult;
   }
   else
   {
      if(prev_calculated == 0 || ThresholdBuffer[0] == 0.0)
      {
         ThresholdBuffer[0] = MathMax(AbsHistCalc[0] * InpThreshMult, 0.00001);
      }
      
      double kT = 2.0 / (InpThreshPeriod + 1.0);
      for(int i = MathMax(start, 1); i < rates_total; ++i)
      {
         double scaled_input = AbsHistCalc[i] * InpThreshMult;
         ThresholdBuffer[i] = ThresholdBuffer[i-1] + kT * (scaled_input - ThresholdBuffer[i-1]);
         
         if(ThresholdBuffer[i] > 1e9 || ThresholdBuffer[i] < 0)
         {
            ThresholdBuffer[i] = MathMax(scaled_input, 0.00001);
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
