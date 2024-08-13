//+------------------------------------------------------------------+
//|                                                   FVG_Sniper.mq5 |
//|                                         F&F Trading Applications |
//|                                       https://www.francperez.com |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      "https://www.francperez.com"
#property version   "1.00"

#include <Trade\Trade.mqh>;
#include <Trade\OrderInfo.mqh>
CTrade trade;
COrderInfo order;

// Inputs
input int   TRENDPeriod = 25;

// Flags
int trend = 0;

// Handlers
int handlerMATrend;

// Buffers
double trendMA[];

// Structs 

struct FairValueGap {
   datetime date_time;
   double high_price;
   double low_price; 
};



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ArraySetAsSeries(trendMA, true);
   handlerMATrend = iMA(_Symbol,_Period,TRENDPeriod,0,MODE_SMA,PRICE_TYPICAL);
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
   FairValueGap tmp = fvg(1);
   Print(tmp.date_time, tmp.high_price, tmp.low_price);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Returns an array with the price fork of the FVG. Also returns true if it found
// an FVG or false if not.

FairValueGap fvg(int trendDirection)
  {
   MqlRates data[];
   ArraySetAsSeries(data,true);
   ArrayResize(data, 3);
   int copied = CopyRates(_Symbol,_Period,1,3,data);
   
   FairValueGap out;
   
   if(trendDirection == 1)
     {
         if (data[2].open < data[2].close && data[3].high < data[1].low) {
            Print(data[2].time);
            
            out.date_time = data[2].time;
            out.high_price = data[1].low;
            out.low_price = data[3].high;
            //Print(out);
            return out;
         }
     }
   if(trendDirection == -1)
     {
         if (data[2].open > data[2].close && data[1].high < data[3].low) {
            
            out.date_time = data[2].time;
            out.high_price = data[3].low;
            out.low_price = data[1].high;
            //Print(out);
            return out;
         }
     }
    return out;
  }
//+------------------------------------------------------------------+
