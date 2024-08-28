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

// Definir constantes
#define STD_MULTIPLIER 1.0

// Estructura para guardar el perfil de mercado diario
struct MarketProfile
{
   double close;
   double tick_volume;
   double volume_cumsum;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() 
{
   
//---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{
   
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() 
{
   
}

//+------------------------------------------------------------------+

// Función para crear el perfil de mercado
void CreateMarketProfile(MqlRates rates[], int count, MarketProfile &profile[], int &profile_count)
{
   // Map para acumular el volumen por precio de cierre
   double volume_by_price[];
   ArrayResize(profile, count);
   profile_count = 0;

   for(int i = 0; i < count; i++)
   {
      volume_by_price[rates[i].close] += rates[i].tick_volume;
   }

   // Ordenar los precios y calcular el volumen acumulado
   double prices[], cumulative_volume = 0;
   int total_volume = 0;

   for(int i = 0; i < ArraySize(volume_by_price); i++)
   {
      prices[i] = volume_by_price[i];
      total_volume += prices[i];
   }

   for(int i = 0; i < ArraySize(prices); i++)
   {
      profile[i].close = prices[i];
      profile[i].tick_volume = volume_by_price[prices[i]];
      cumulative_volume += profile[i].tick_volume;
      profile[i].volume_cumsum = cumulative_volume;
      profile_count++;
   }
}

// Función para obtener la zona de máximo volumen
bool GetMaxVolZone(MarketProfile profile[], int profile_count, double threshold, double &zone_low, double &zone_high)
{
   int start = -1, max_size = 0;
   int range_start = -1, range_end = -1;

   for(int i = 0; i < profile_count; i++)
   {
      if(profile[i].tick_volume > threshold)
      {
         if(start == -1)
            start = i;
      }
      else
      {
         if(start != -1)
         {
            int size = i - start;
            if(size > max_size)
            {
               max_size = size;
               range_start = start;
               range_end = i - 1;
            }
            start = -1;
         }
      }
   }

   // Si la última zona no se cerró explícitamente en el bucle
   if(start != -1)
   {
      int size = profile_count - start;
      if(size > max_size)
      {
         max_size = size;
         range_start = start;
         range_end = profile_count - 1;
      }
   }

   if(range_start == -1 || range_end == -1)
      return false;

   zone_low = profile[range_start].close;
   zone_high = profile[range_end].close;
   return true;
}

// Función para obtener la zona de mayor volumen por día
void GetMaxVolZoneByDay()
{
   MqlRates rates[];
   int rates_count = CopyRates(Symbol(), PERIOD_M1, 0, 1440, rates); // Ajuste para un día

   MarketProfile profile[];
   int profile_count;

   // Crear perfil de mercado
   CreateMarketProfile(rates, rates_count, profile, profile_count);

   // Calcular media y desviación estándar del volumen
   double mean = 0, stddev = 0;
   for(int i = 0; i < profile_count; i++)
   {
      mean += profile[i].tick_volume;
   }
   mean /= profile_count;

   for(int i = 0; i < profile_count; i++)
   {
      stddev += MathPow(profile[i].tick_volume - mean, 2);
   }
   stddev = MathSqrt(stddev / profile_count);

   double threshold = mean + stddev * STD_MULTIPLIER;

   // Obtener zona de volumen máximo
   double zone_low, zone_high;
   if(GetMaxVolZone(profile, profile_count, threshold, zone_low, zone_high))
   {
      Print("Zone Low: ", zone_low, " Zone High: ", zone_high);
   }
}
