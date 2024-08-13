//+------------------------------------------------------------------+
//|                                                VWAP_Strategy.mq5 |
//|                                                      Franc Pérez |
//|  /francperez/VWAP-Strategy-Idea-936e6cf8de8b472ea7889d5139d70fd7 |
//+------------------------------------------------------------------+
#property copyright "Franc Pérez"
#property link      "/francperez/VWAP-Strategy-Idea-936e6cf8de8b472ea7889d5139d70fd7"
#property version   "1.00"

#include <Trade\Trade.mqh>;
CTrade trade;

//--- input parameters
input double   LOTAJE=1.0;
input double   atrMultiplicador=1.5;
input int      atrPeriod=13;
input int      adxPeriod=13;
input double   TPFactor=2.0;
input int      TrendMAperiod=100;
input int      VWAPperiod=14;
input int      PriceMAperiod=6;

// Handlers
int handlerTrendMA;
int handlerPriceMA;
int handlerVWAP; // El buffer del VWAP diario es el 0;
int handlerATR;
int handlerADX;

// Buffers
double trendMA[10];
double priceMA[10];
double atr[10];
double vwap[10];
double adx[10];

// Flags

// Variables

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   handlerVWAP = iCustom(_Symbol,PERIOD_CURRENT,"/Free Indicators/VWAP");
   handlerATR = iATR(_Symbol,PERIOD_CURRENT,atrPeriod);
   handlerADX = iADX(_Symbol,PERIOD_CURRENT,adxPeriod);
   handlerPriceMA = iMA(_Symbol,PERIOD_CURRENT,PriceMAperiod,0,MODE_SMA,PRICE_MEDIAN);
   handlerTrendMA = iMA(_Symbol,PERIOD_CURRENT,TrendMAperiod,0,MODE_SMA,PRICE_CLOSE);
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
   
  }
//+------------------------------------------------------------------+
