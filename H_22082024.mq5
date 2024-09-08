//+------------------------------------------------------------------+
//|                                                   H_22082024.mq5 |
//|                         Copyright 2024, F&F Trading Applications |
//|                                      https://www.francperez.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, F&F Trading Applications"
#property link      "https://www.francperez.com/"
#property version   "1.00"

#include <Trade\Trade.mqh>;
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
COrderInfo order;
CPositionInfo Posicion;
CTrade trade;

//--- input parameters INDICATOR
input ENUM_APPLIED_VOLUME  av = VOLUME_REAL; // Applied Volume
double                  precision = 100; //
ENUM_TIMEFRAMES tf = PERIOD_M1;

sinput int lrlenght = 150;
int socket;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   socket=SocketCreate();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   SocketClose(socket);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   MqlDateTime temp_now;
   TimeCurrent(temp_now);

   if(temp_now.hour == 0 && temp_now.min == 00 && temp_now.sec == 01)
     {
      //Print("OUT: yesterdayPOC2() ", yesterdayPOC2());
      //Print("OUT: GetYesterdayPOC(_Symbol) ", GetYesterdayPOC(_Symbol));
      socket=SocketCreate();
      if(socket!=INVALID_HANDLE)
        {
         if(SocketConnect(socket,"localhost",9090,1000))
           {
            Print("Connected to "," localhost",":",9090);
            string tosend;
            StringConcatenate(tosend, Symbol(),"@$",TimeToString(TimeTradeServer(), TIME_DATE));
            string received = socksend(socket, tosend) ? socketreceive(socket, 10) : "";
            Print(received);
           }

         else
            Print("Connection ","localhost",":",9090," error ",GetLastError());
         SocketClose(socket);
        }
      else
         Print("Socket creation error ",GetLastError());
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool socksend(int sock,string request)
  {
   char req[];
   int  len=StringToCharArray(request,req)-1;
   if(len<0)
      return(false);
   return(SocketSend(sock,req,len)==len);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string socketreceive(int sock, int timeout)
  {
   char rsp[];
   string result = "";
   uint len;
   uint timeout_check=GetTickCount()+timeout;
   do
     {
      len=SocketIsReadable(sock);
      if(len)
        {
         int rsp_len;
         rsp_len = SocketRead(sock,rsp,len,timeout);
         if(rsp_len>0)
           {
            result+=CharArrayToString(rsp,0,rsp_len);
           }
        }
     }
   while((GetTickCount()<timeout_check) && !IsStopped());
   return result;
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetYesterdayPOC(string symbol)
  {
// Define variables
   int dayBars;               // Number of bars for the previous day
   datetime startTime, endTime; // Time range for the previous day
   double highestVolume = 0;   // The highest volume traded at a price level
   double POC = 0;             // Point of Control (price level with the highest volume)

// Get the timeframe and the current date
   ENUM_TIMEFRAMES timeframe = PERIOD_M1;
   datetime today = TimeCurrent();

// Define start and end times for the previous day (using the midnight shift for daily data)
   startTime = iTime(symbol, PERIOD_D1, 1);  // Start time of yesterday
   endTime = iTime(symbol, PERIOD_D1, 0) - 1;  // End time of yesterday

// Get all the 1-minute bars for the previous day
   dayBars = iBarShift(symbol, timeframe, startTime);
   int barCount = dayBars - iBarShift(symbol, timeframe, endTime);
   Print("DATE: ", startTime);

   if(barCount <= 0)
      return -1; // Return -1 if no bars are available

   double priceStep = SymbolInfoDouble(symbol, SYMBOL_POINT); // Smallest price step
   double pricePrecision = SymbolInfoInteger(symbol, SYMBOL_DIGITS); // Decimal precision for prices
// Define arrays for price and volume
   double prices[];
   double volumes[];
   ArrayResize(volumes, 0);
   ArrayResize(prices, 0);

   double max = iHigh(symbol, PERIOD_D1, 1);
   double min = iLow(symbol, PERIOD_D1, 1);
   double range = MathRound((NormalizeDouble(max, pricePrecision)-NormalizeDouble(min, pricePrecision))/priceStep);

   ArrayResize(volumes, range);
   ArrayResize(prices, range);

   for(int n=0; n<range; n++)
     {
      volumes[n]=0.0;
      prices[n]= NormalizeDouble(min + (priceStep*n), pricePrecision);
     }

// Loop through each bar of yesterday
   for(int i = 0; i < barCount; i++)
     {
      // Get the high, low, and volume for each minute bar
      double high = iHigh(symbol, timeframe, dayBars + i);
      double low = iLow(symbol, timeframe, dayBars + i);
      double volume = iVolume(symbol, timeframe, dayBars + i);


      // Accumulate volumes at each price level
      for(double price = low; price <= high; price = NormalizeDouble(price + priceStep, pricePrecision))
        {
         // Normalize the price to the precision of the symbol
         price = NormalizeDouble(price, pricePrecision);
         int index = ArrayBsearch(prices, price);

         if(index < 0) // If price is not found, add it to the array
           {
            int newSize = ArraySize(prices) + 1;
            ArrayResize(prices,newSize);
            ArrayResize(volumes, newSize);

            prices[newSize - 1] = price;
            volumes[newSize - 1] = volume;

           }
         else // If price is found, accumulate volume
           {
            volumes[index] += volume;
           }
        }
     }
   ObjectCreate(
      0,
      "POC",
      OBJ_HLINE,
      0,
      startTime,
      prices[ArrayMaximum(volumes,0,WHOLE_ARRAY)]
   );
   ObjectCreate(
      0,
      "POC",
      OBJ_VLINE,
      0,
      startTime,
      prices[ArrayMaximum(volumes,0,WHOLE_ARRAY)]
   );
   return prices[ArrayMaximum(volumes,0,WHOLE_ARRAY)];
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+


// Based on Mohammad E. Baset Volume Profile indicator.
double yesterdayPOC()
  {
   if(precision<=0)
     {
      Alert("precision couldn't be zero or less than zero");
      return -1;
     }

//---Get the datetime data of the begining and end of the range.
   datetime time_begin = iTime(_Symbol, PERIOD_D1, 1);
   datetime time_finish = iTime(_Symbol, PERIOD_D1, 0) - 1;
//---Number of bars in the range based on the calculation timeframe (not the current timeframe visible in the chart).
   int bars = Bars(_Symbol,tf,time_begin,time_finish);
   if(time_begin>=time_finish)
      return -1;

//---Copy high-low-volume data of the calculation timeframe.
   double high_array[];
   double low_array[];
   long volume[];
   ArrayResize(high_array,bars);
   ArrayResize(low_array,bars);
   ArrayResize(volume,bars);

// Separation of Real or Tick Volume
   if(CopyHigh(_Symbol,tf,time_begin,time_finish,high_array)==-1 ||
      CopyLow(_Symbol,tf,time_begin,time_finish,low_array)==-1 ||
      CopyRealVolume(_Symbol,tf,time_begin,time_finish,volume)==-1)
      return -1;
   if(av==VOLUME_TICK || volume[0]==0)
      if(CopyTickVolume(_Symbol,tf,time_begin,time_finish,volume)==-1)
         return -1;
//---Find the max-min price in the range & the height of VP bars based on the number of bars (precision input)
   double max = high_array[ArrayMaximum(high_array,0,WHOLE_ARRAY)]; // highest price in the range
   double min = low_array[ArrayMinimum(low_array,0,WHOLE_ARRAY)]; // lowest price in the range
   double range = (max-min)/precision; // height of the VP bars

//---Create an array to store the VP data
   double profile[];
   double prices[];
   ArrayResize(profile,precision);

//---Calculate VP array
//---Loop through all price bars in the range and cumulatively assign their volume to VPs.
   for(int i=0; i<bars; i++)
     {
      int Floor = (int)MathFloor((low_array[i]-min)/range); // the first level of VP just below the low of the ith candle
      int Ceil = (int)MathFloor((high_array[i]-min)/range); // the first level ov VP just above the high of the ith candle
      double body = high_array[i]-low_array[i]; // the height of ith candle
      //---When the lower part of the candle falls between two levels of VPs, we have to consider just that part, not the entire level height
      double tail = min+(Floor+1)*range-low_array[i];
      //---When the upper part of the candle falls between two levels of VPs, we have to consider just that part, not the entire level height
      double wick = high_array[i]-(min+(Ceil)*range);
      //---set the values of VPs to zero in the first step of the loop, because we are accumulating volumes to find VPs and they should be zero in the begining
      if(i==0)
         for(int n=0; n<precision; n++)
            profile[n]=0.0;
      for(int n=0; n<precision; n++)
        {
         if(n<Floor || n>Ceil) // when no part of the candle is in the nth level of VP, continue
            continue;
         if(Ceil-Floor==0) // when all of the candle is in the nth level of VP, add whole volume of the candle to that level of VP
            profile[n]+=(double)volume[i];
         else
            if(n==Floor) // when the lower part of the candle falls in the nth level of VP, but it doesn't cover the whole height of the nth level
               profile[n]+=(tail/body)*volume[i];
            else
               if(n==Ceil) // when the upper part of the candle falls in the nth level of VP, but it doesn't cover the entire height of the nth level
                  profile[n]+=(wick/body)*volume[i];
               else
                  profile[n]+=(range/body)*volume[i]; // when a part of the candle covers the entire height of the nth level
        }
     }
//--- Point of Control is the maximum VP found in the volume profile array
   double POC=profile[ArrayMaximum(profile,0,WHOLE_ARRAY)];

   if(POC==0.0)
      return -1;

   return POC;
  }
//+------------------------------------------------------------------+




// Based on Mohammad E. Baset Volume Profile indicator.
double yesterdayPOC2()
  {
//---Get the datetime data of the begining and end of the range.
   datetime time_begin = iTime(_Symbol, PERIOD_D1, 1);
   datetime time_finish = iTime(_Symbol, PERIOD_D1, 0) - 1;
//---Number of bars in the range based on the calculation timeframe (not the current timeframe visible in the chart).
   int bars = Bars(_Symbol,tf,time_begin,time_finish);
   if(time_begin>=time_finish)
      return -1;

//---Copy high-low-volume data of the calculation timeframe.
   double high_array[];
   double low_array[];
   long volume[];
   ArrayResize(high_array,bars);
   ArrayResize(low_array,bars);
   ArrayResize(volume,bars);

// Separation of Real or Tick Volume
   if(CopyHigh(_Symbol,tf,time_begin,time_finish,high_array)==-1 ||
      CopyLow(_Symbol,tf,time_begin,time_finish,low_array)==-1 ||
      CopyRealVolume(_Symbol,tf,time_begin,time_finish,volume)==-1)
      return -1;
   if(av==VOLUME_TICK || volume[0]==0)
      if(CopyTickVolume(_Symbol,tf,time_begin,time_finish,volume)==-1)
         return -1;
//---Find the max-min price in the range & the height of VP bars based on the number of bars (precision input)
   double max = high_array[ArrayMaximum(high_array,0,WHOLE_ARRAY)]; // highest price in the range
   double min = low_array[ArrayMinimum(low_array,0,WHOLE_ARRAY)]; // lowest price in the range
   double range = (max-min)/SymbolInfoDouble(_Symbol, SYMBOL_POINT); // height of the VP bars
   precision = range;
   if(precision<=0)
     {
      Alert("precision couldn't be zero or less than zero");
      return -1;
     }

//---Create an array to store the VP data
   double profile[];
   double prices[];
   ArrayResize(profile,precision);
   ArrayResize(prices,precision);

   double priceStep = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Smallest price step
   long pricePrecision = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); // Decimal precision for prices

//---Calculate VP array
//---Loop through all price bars in the range and cumulatively assign their volume to VPs.
   for(int i=0; i<bars; i++)
     {
      int Floor = (int)MathFloor((low_array[i]-min)/range); // the first level of VP just below the low of the ith candle
      int Ceil = (int)MathFloor((high_array[i]-min)/range); // the first level ov VP just above the high of the ith candle
      double body = high_array[i]-low_array[i]; // the height of ith candle
      //---When the lower part of the candle falls between two levels of VPs, we have to consider just that part, not the entire level height
      double tail = min+(Floor+1)*range-low_array[i];
      //---When the upper part of the candle falls between two levels of VPs, we have to consider just that part, not the entire level height
      double wick = high_array[i]-(min+(Ceil)*range);

      //---set the values of VPs to zero in the first step of the loop, because we are accumulating volumes to find VPs and they should be zero in the begining
      if(i==0)
         for(int n=0; n<precision; n++)
           {
            profile[n]=0.0;
            prices[n]= NormalizeDouble(min + (priceStep*n), pricePrecision);
           }

      Print(prices[1]);
      for(int n=0; n<precision; n++) //int n=min; n<=max; n = NormalizeDouble(n + priceStep, pricePrecision)
        {
         if(n<Floor || n>Ceil) // when no part of the candle is in the nth level of VP, continue
            continue;

         if(Ceil-Floor==0) // when all of the candle is in the nth level of VP, add whole volume of the candle to that level of VP
            profile[n]+=(double)volume[i];
         else
            if(n==Floor) // when the lower part of the candle falls in the nth level of VP, but it doesn't cover the whole height of the nth level
               profile[n]+=(tail/body)*volume[i];
            else
               if(n==Ceil) // when the upper part of the candle falls in the nth level of VP, but it doesn't cover the entire height of the nth level
                  profile[n]+=(wick/body)*volume[i];
               else
                  profile[n]+=(range/body)*volume[i]; // when a part of the candle covers the entire height of the nth level

        }
     }
//--- Point of Control is the maximum VP found in the volume profile array
   double POC=prices[ArrayMaximum(profile,0,WHOLE_ARRAY)];

   if(POC==0.0)
      return -1;

   return POC;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
