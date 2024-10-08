//+------------------------------------------------------------------+
//|                                                VWAP_Strategy.mq5 |
//|                                                      Franc Pérez |
//|  /francperez/VWAP-Strategy-Idea-936e6cf8de8b472ea7889d5139d70fd7 |
//+------------------------------------------------------------------+
#property copyright "Franc Pérez"
#property link      "www.francperez.com"
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

//--- input parameters
input double   LOTAJE=1.0;
input double   TPFactor=2.0;
input int      VWAPperiod=14;

// Handlers
int handlerVWAP; // El buffer del VWAP diario es el 0;

// Buffers
double vwap[10];

// Flags

// Variables
datetime previous_candle_open_time = 0;
double tradeCounter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handlerVWAP = iCustom(_Symbol,PERIOD_D1,"Market\\Full VWAP");
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
   CopyBuffer(handlerVWAP,0,0,10,vwap);
   MqlDateTime dts;
   TimeTradeServer(dts);
   double open = iOpen(_Symbol,PERIOD_D1,0);
   double prev_high = iHigh(_Symbol,PERIOD_D1,1);
   double prev_low = iLow(_Symbol,PERIOD_D1,1);
   double prev_close = iClose(_Symbol,PERIOD_D1,1);
/*
   if(PositionSelect(_Symbol) == false && dts.hour == 1 && oneTradePerDay() == true)
     {
      if(vwap[1] < prev_close)
        {
         double dstoploss = NormalizePrice(SymbolInfoDouble(_Symbol,SYMBOL_LAST) + (prev_close - vwap[1]));
         trade.Sell(LOTAJE,_Symbol,open,dstoploss,vwap[1],"Sell");
         previous_candle_open_time = iTime(_Symbol, PERIOD_D1, 0);
        }

      if(vwap[1] > prev_close)
        {
         double dstoploss = NormalizePrice(SymbolInfoDouble(_Symbol,SYMBOL_LAST) - (vwap[1] - prev_close));
         trade.Buy(LOTAJE,_Symbol,open,dstoploss,vwap[1],"Sell");
         previous_candle_open_time = iTime(_Symbol, PERIOD_D1, 0);
        }
     }

   if(PositionSelect(_Symbol) == true)
     {
      if (dts.hour == 10 && dts.min == 59) {
         trade.PositionClose(_Symbol);
      }
     }

*/
   Print(vwap[0]);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double m_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));
  }

//+------------------------------------------------------------------+
//| Check if is the same bar                                         |
//+------------------------------------------------------------------+
bool oneTradePerDay()
  {
// Obtener la hora de apertura de la vela actual
   datetime current_candle_open_time = iTime(_Symbol, PERIOD_D1, 0);

// Comparar la hora de apertura de la vela actual con la de la iteración anterior
   if(current_candle_open_time == previous_candle_open_time)
     {
      return false;
     }
   else
     {
      // Actualizar la variable global con la hora de apertura de la vela actual
      previous_candle_open_time = current_candle_open_time;
      return true;
     }
  }
//+------------------------------------------------------------------+

double CalculateDailyVWAP()
{
   int startPos = iBarShift(NULL, PERIOD_D1, iTime(NULL, PERIOD_D1, 0)); // Get the start of the current day
   double volumeSum = 0.0;
   double priceVolumeSum = 0.0;

   for (int i = startPos; i >= 0; i--) 
   {
      double typicalPrice = (iHigh(NULL, 0, i) + iLow(NULL, 0, i) + iClose(NULL, 0, i)) / 3.0;
      double volume = iVolume(NULL, 0, i);
      priceVolumeSum += typicalPrice * volume;
      volumeSum += volume;
   }

   return (volumeSum > 0) ? (priceVolumeSum / volumeSum) : 0.0; // Return VWAP or 0 if no volume
}

double CalculateMonthlyVWAP()
{
   int startPos = iBarShift(NULL, PERIOD_MN1, iTime(NULL, PERIOD_MN1, 0)); // Get the start of the current month
   double volumeSum = 0.0;
   double priceVolumeSum = 0.0;

   for (int i = startPos; i >= 0; i--) 
   {
      double typicalPrice = (iHigh(NULL, 0, i) + iLow(NULL, 0, i) + iClose(NULL, 0, i)) / 3.0;
      double volume = iVolume(NULL, 0, i);
      priceVolumeSum += typicalPrice * volume;
      volumeSum += volume;
   }

   return (volumeSum > 0) ? (priceVolumeSum / volumeSum) : 0.0; // Return VWAP or 0 if no volume
}
