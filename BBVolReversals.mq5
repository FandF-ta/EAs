//+------------------------------------------------------------------+
//|                                               BBVolReversals.mq5 |
//|                                         F&F Trading Applications |
//|                                       https://www.francperez.com |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      "https://www.francperez.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

// Inputs
input int LOTAJE = 1;
input ENUM_TIMEFRAMES EAPeriod = PERIOD_CURRENT;
input int BBPeriod = 20;
input double BBDeviation = 2.0;
input ENUM_APPLIED_PRICE EAPriceApplied = PRICE_TYPICAL;
input int CloseAfterNumBars = 5;

// Flags
int direction = 0;
MqlRates reference_bar;
double reference_bar_extreme = 0.0;

// Handlers

int handlerBB;
int handlerATR;

// Buffers

double bb[];
double bb_low[];
double bb_high[];
double atr[];
MqlRates bars[];

// Variables
datetime previous_candle_open_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ArraySetAsSeries(bb, true);
   ArraySetAsSeries(bb_high, true);
   ArraySetAsSeries(bb_low, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(bars, true);
   
   handlerBB = iBands(_Symbol,EAPeriod,BBPeriod,0,BBDeviation,EAPriceApplied);
   handlerATR = iATR(_Symbol,EAPeriod,14);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   ArrayResize(bb,25);
   ArrayResize(bb_high,25);
   ArrayResize(bb_low,25);
   ArrayResize(atr,25);
   ArrayResize(bars,25);
   
   CopyBuffer(handlerBB,0,0,10,bb);
   CopyBuffer(handlerBB,1,0,10,bb_high);
   CopyBuffer(handlerBB,2,0,10,bb_low);
   CopyBuffer(handlerATR,0,0,10,atr);
   CopyRates(_Symbol,EAPeriod,0,25,bars);
   
   bool active_order = PositionSelect(_Symbol);
   
   if (active_order == false && isSameBar() == false) {
      // TRADING ALLOWED
      
      if (direction == 0) {
         bool is_out_BB_High = bars[1].close > bb_high[1] && bars[2].close > bb_high[2];
         bool is_out_BB_Low = bars[1].close < bb_low[1] && bars[2].close < bb_low[2];
         bool volume_decreasing = bars[1].tick_volume < bars[2].tick_volume;   
            
         if (is_out_BB_High && volume_decreasing) {
            reference_bar = bars[1];
            direction = -1; // Señal de venta
            Print("Out BB High and Volume Decreasing");
         }
         if (is_out_BB_Low && volume_decreasing) {
            reference_bar = bars[1];
            direction = 1; // Señal de compra
            Print("Out BB High and Volume Decreasing");
         }
      } else {
         if (direction == 1 ) { //&& reference_bar.time != bars[1].time
            double current_extreme = bars[1].low;
            reference_bar_extreme = reference_bar_extreme < current_extreme ? reference_bar_extreme : current_extreme;
            double stopLoss = NormalizeDouble((reference_bar_extreme - atr[1]),Point());
            if (reference_bar_extreme < current_extreme) {
               trade.Buy(LOTAJE,_Symbol,bars[1].close,stopLoss,NULL,"BUY TRADE");
               direction = 0;
            }
         }
         if (direction == -1 ) {
            double current_extreme = bars[1].high;
            reference_bar_extreme = reference_bar_extreme > current_extreme ? reference_bar_extreme : current_extreme;
            double stopLoss = NormalizeDouble((reference_bar_extreme + atr[1]),Point());
            if (reference_bar_extreme > current_extreme) {
               trade.Sell(LOTAJE,_Symbol,bars[1].close,stopLoss,NULL,"SELL TRADE");
               direction = 0;
            }
         }
      }
      
   } else {
      // POSITION OPEN, RISK MANAGEMENT
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol,SYMBOL_LAST) > bb[0]) {
         trade.PositionClose(_Symbol);
      }
   
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol,SYMBOL_LAST) < bb[0]) {
         trade.PositionClose(_Symbol);
      }
   
      int nPosition_OpeningTime_Difference = Bars(Symbol(), Period(), PositionGetInteger(POSITION_TIME), TimeCurrent()) - 1;
      if(nPosition_OpeningTime_Difference >= CloseAfterNumBars) {
         trade.PositionClose(_Symbol);
      }
   }
 
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if is the same bar                                         |
//+------------------------------------------------------------------+
bool isSameBar()
  {
// Obtener la hora de apertura de la vela actual
   datetime current_candle_open_time = iTime(_Symbol, PERIOD_CURRENT, 0);

// Comparar la hora de apertura de la vela actual con la de la iteración anterior
   if(current_candle_open_time == previous_candle_open_time)
     {
      return true;
     }
   else
     {
      // Actualizar la variable global con la hora de apertura de la vela actual
      previous_candle_open_time = current_candle_open_time;
      return false;
     }
  }