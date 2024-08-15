//+------------------------------------------------------------------+
//|                                                RangeBreakOut.mq5 |
//|                                         F&F Trading Applications |
//|                                       https://www.francperez.com |
//+------------------------------------------------------------------+
#property copyright "F&F Trading Applications"
#property link      "https://www.francperez.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>;
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo order;
CPositionInfo Posicion;
CTrade trade;

// Definitions and Enums
enum tipeOfBehaviour {
   TREND = 0,
   REVERSAL = 1,
};
// Inputs
input int ATR_PERIOD = 7;
input tipeOfBehaviour BOT_BEHAVIOUR = TREND;

input group "Time Assignment"
input int start_hour = 3;
input int start_minute = 5;
input int end_hour = 6;
input int end_minute = 5;
input int CLOSE_POSITION_HOUR = 17;
input int CLOSE_POSITION_MIN = 0;

input group "R/R Ratios"
input double TP_MUL_RATIO = 0.3;
input double SL_MUL_RATIO = 2.0;

// Variables
MqlDateTime now;
datetime start_time = 0;
datetime end_time = 0;
double high_level_range = 0;
double low_level_range = 0;
double range_size = 0;

// Handlers
int handlerATR;

// Buffers
double atr[];
double high_range[];
double low_range[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high_range, true);
   ArraySetAsSeries(low_range, true);

   handlerATR = iATR(_Symbol,PERIOD_D1,ATR_PERIOD);
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
   ArrayResize(atr,10);
   CopyBuffer(handlerATR,0,0,10,atr);

   bool active_trade = PositionSelect(_Symbol);

   TimeCurrent(now); // Calcular el dia de hoy

   if(active_trade == false && now.hour == end_hour && now.min == end_minute+1 && now.sec == 0 && end_time != StructToTime(now))
     {
      // Analizamos el rango que hay entre las dos franjas horarias predefinidas en las INPUTS
      MqlDateTime start_tmp;
      start_tmp.year= now.year;
      start_tmp.mon = now.mon;
      start_tmp.day = now.day;
      start_tmp.hour= start_hour;
      start_tmp.min = start_minute;
      start_tmp.sec = 0;

      MqlDateTime end_tmp;
      end_tmp.year= now.year;
      end_tmp.mon = now.mon;
      end_tmp.day = now.day;
      end_tmp.hour= end_hour;
      end_tmp.min = end_minute;
      end_tmp.sec = 0;

      start_time = StructToTime(start_tmp);
      end_time = StructToTime(end_tmp);

      // Dimensionamos los arrays a la medida justa de las velas que van a tener lugar.
      ArrayResize(high_range, Bars(_Symbol,PERIOD_CURRENT,start_time, end_time));
      ArrayResize(low_range, Bars(_Symbol,PERIOD_CURRENT,start_time, end_time));

      CopyHigh(_Symbol,PERIOD_CURRENT,start_time, end_time, high_range);
      CopyLow(_Symbol,PERIOD_CURRENT,start_time, end_time, low_range);

      // Extraemos los extremos del rango.
      high_level_range = high_range[ArrayMaximum(high_range,0)];
      low_level_range = low_range[ArrayMinimum(low_range,0)];
      range_size = high_level_range - low_level_range;

      ObjectCreate(0, "RANGE", OBJ_RECTANGLE, 0, start_time, high_level_range, end_time, low_level_range);

      if(SymbolInfoDouble(_Symbol, SYMBOL_LAST) < high_level_range && SymbolInfoDouble(_Symbol, SYMBOL_LAST) > low_level_range)
        {
         // El precio esta dentro del rango. Posicionamos las ordenes.
         if (BOT_BEHAVIOUR == TREND) {
         trade.BuyStop(1,high_level_range,_Symbol,NormalizeDouble(high_level_range - range_size*SL_MUL_RATIO, Digits()),NormalizeDouble((high_level_range + range_size*TP_MUL_RATIO), Digits()),ORDER_TIME_GTC,NULL,"Buy stop from range");
         trade.SellStop(1,low_level_range,_Symbol,NormalizeDouble(low_level_range + range_size*SL_MUL_RATIO, Digits()),NormalizeDouble((low_level_range - range_size*TP_MUL_RATIO), Digits()),ORDER_TIME_GTC,NULL,"Sell stop from range");
         }
         
         if (BOT_BEHAVIOUR == REVERSAL) {
         trade.BuyLimit(1,low_level_range,_Symbol,NormalizeDouble(low_level_range - range_size*SL_MUL_RATIO, Digits()),NormalizeDouble((high_level_range + range_size*TP_MUL_RATIO), Digits()),ORDER_TIME_GTC,NULL,"Buy Limit from range");
         trade.SellLimit(1,high_level_range,_Symbol,NormalizeDouble(high_level_range + range_size*SL_MUL_RATIO, Digits()),NormalizeDouble((low_level_range - range_size*TP_MUL_RATIO), Digits()),ORDER_TIME_GTC,NULL,"Sell Limit from range");
         }
         
        }
     }

   if(active_trade == true)
     {
      // Cerrar las ordenes pendientes si ya se ha ejecutado una.
      //PendingOrderDelete();

     }
   
   if (now.hour == CLOSE_POSITION_HOUR && now.min == CLOSE_POSITION_MIN) {
         trade.PositionClose(_Symbol);
         PendingOrderDelete();
      }
   
  }
//+------------------------------------------------------------------+

// Calcula la dimensión de la posición que va a ejecutar para mantener al gestión del riesgo.
void calculateLots()
  {
//---

  }

//+------------------------------------------------------------------+
//| Delete all pending orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders(void)
  {
   for(int i=OrdersTotal()-1; i>=0; i--)  // returns the number of current orders
     {
      if(order.SelectByIndex(i))      // selects the pending order by index for further access to its properties
        {
         if(order.Symbol()==_Symbol)
           {
            trade.OrderDelete(order.Ticket());
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PendingOrderDelete()
  {

   int o_total=OrdersTotal();
   for(int j=o_total-1; j>=0; j--)
     {
      ulong o_ticket = OrderGetTicket(j);
      if(o_ticket != 0)
        {
         // delete the pending order
         trade.OrderDelete(o_ticket);
         Print("Pending order deleted sucessfully!");
        }
     }
  }
//+------------------------------------------------------------------+
