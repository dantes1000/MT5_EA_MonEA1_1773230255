//+------------------------------------------------------------------+
//|                                                      TrendStrategy.mqh |
//|                        Copyright 2024, MonEA1 Project              |
//|                                             https://www.monea1.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA1 Project"
#property link      "https://www.monea1.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trend Strategy Signal Class                                      |
//+------------------------------------------------------------------+
class CTrendStrategy
{
private:
   // Input parameters
   string            m_symbol;               // Trading symbol
   ENUM_TIMEFRAMES   m_exec_tf;              // Execution timeframe (M15/M30)
   ENUM_TIMEFRAMES   m_range_tf;             // Range timeframe (D1)
   
   // Risk management
   double            m_risk_pc;              // Risk percentage per trade
   int               m_sl_pips;              // Stop loss in pips
   int               m_tp_pips;              // Take profit in pips
   double            m_min_lot;              // Minimum lot size
   double            m_max_lot;              // Maximum lot size
   
   // Trend filters
   bool              m_use_trend_filter;     // Enable trend filter
   int               m_ema_period;           // EMA period for trend
   ENUM_TIMEFRAMES   m_ema_tf;               // EMA timeframe
   int               m_adx_period;           // ADX period
   double            m_adx_threshold;        // ADX threshold
   
   // Volatility filters
   bool              m_use_atr_filter;       // Enable ATR filter
   int               m_atr_period;           // ATR period
   double            m_atr_mult_min;         // Minimum ATR multiplier
   double            m_atr_mult_max;         // Maximum ATR multiplier
   
   // Volume confirmation
   bool              m_use_volume_filter;    // Enable volume filter
   int               m_volume_period;        // Volume SMA period
   double            m_volume_mult;          // Volume multiplier threshold
   
   // Bollinger Bands filter
   bool              m_use_bb_filter;        // Enable BB filter
   int               m_bb_period;            // BB period
   double            m_bb_dev;               // BB deviation
   int               m_min_width_pips;       // Minimum width in pips
   int               m_max_width_pips;       // Maximum width in pips
   
   // Internal variables
   int               m_handle_ema;           // EMA indicator handle
   int               m_handle_atr;           // ATR indicator handle
   int               m_handle_adx;           // ADX indicator handle
   int               m_handle_bb;            // Bollinger Bands handle
   
   // Signal tracking
   datetime          m_last_signal_time;     // Time of last signal
   int               m_last_signal_type;     // Last signal type (1=buy, -1=sell, 0=no signal)
   
public:
   // Constructor
   CTrendStrategy() :
      m_symbol(_Symbol),
      m_exec_tf(PERIOD_M30),
      m_range_tf(PERIOD_D1),
      m_risk_pc(1.0),
      m_sl_pips(30),
      m_tp_pips(60),
      m_min_lot(0.01),
      m_max_lot(5.0),
      m_use_trend_filter(true),
      m_ema_period(200),
      m_ema_tf(PERIOD_H1),
      m_adx_period(14),
      m_adx_threshold(20.0),
      m_use_atr_filter(true),
      m_atr_period(14),
      m_atr_mult_min(1.25),
      m_atr_mult_max(3.0),
      m_use_volume_filter(true),
      m_volume_period(20),
      m_volume_mult(1.5),
      m_use_bb_filter(true),
      m_bb_period(20),
      m_bb_dev(2.0),
      m_min_width_pips(30),
      m_max_width_pips(120),
      m_last_signal_time(0),
      m_last_signal_type(0)
   {
      // Initialize indicator handles
      m_handle_ema = iMA(m_symbol, m_ema_tf, m_ema_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr = iATR(m_symbol, PERIOD_H1, m_atr_period);
      m_handle_adx = iADX(m_symbol, PERIOD_H1, m_adx_period);
      m_handle_bb = iBands(m_symbol, m_range_tf, m_bb_period, 0, m_bb_dev, PRICE_CLOSE);
   }
   
   // Destructor
   ~CTrendStrategy()
   {
      // Release indicator handles
      if(m_handle_ema != INVALID_HANDLE) IndicatorRelease(m_handle_ema);
      if(m_handle_atr != INVALID_HANDLE) IndicatorRelease(m_handle_atr);
      if(m_handle_adx != INVALID_HANDLE) IndicatorRelease(m_handle_adx);
      if(m_handle_bb != INVALID_HANDLE) IndicatorRelease(m_handle_bb);
   }
   
   // Set input parameters
   void SetParameters(string symbol, ENUM_TIMEFRAMES exec_tf, ENUM_TIMEFRAMES range_tf,
                      double risk_pc, int sl_pips, int tp_pips,
                      double min_lot, double max_lot,
                      bool use_trend_filter, int ema_period, ENUM_TIMEFRAMES ema_tf,
                      int adx_period, double adx_threshold,
                      bool use_atr_filter, int atr_period, double atr_mult_min, double atr_mult_max,
                      bool use_volume_filter, int volume_period, double volume_mult,
                      bool use_bb_filter, int bb_period, double bb_dev,
                      int min_width_pips, int max_width_pips)
   {
      m_symbol = symbol;
      m_exec_tf = exec_tf;
      m_range_tf = range_tf;
      m_risk_pc = risk_pc;
      m_sl_pips = sl_pips;
      m_tp_pips = tp_pips;
      m_min_lot = min_lot;
      m_max_lot = max_lot;
      m_use_trend_filter = use_trend_filter;
      m_ema_period = ema_period;
      m_ema_tf = ema_tf;
      m_adx_period = adx_period;
      m_adx_threshold = adx_threshold;
      m_use_atr_filter = use_atr_filter;
      m_atr_period = atr_period;
      m_atr_mult_min = atr_mult_min;
      m_atr_mult_max = atr_mult_max;
      m_use_volume_filter = use_volume_filter;
      m_volume_period = volume_period;
      m_volume_mult = volume_mult;
      m_use_bb_filter = use_bb_filter;
      m_bb_period = bb_period;
      m_bb_dev = bb_dev;
      m_min_width_pips = min_width_pips;
      m_max_width_pips = max_width_pips;
   }
   
   // Calculate lot size based on risk percentage
   double CalculateLotSize(double equity, double sl_distance_pips)
   {
      if(sl_distance_pips <= 0) return m_min_lot;
      
      // Calculate risk amount in account currency
      double risk_amount = equity * (m_risk_pc / 100.0);
      
      // Calculate tick value for the symbol
      double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      
      // Calculate lot size
      double lot_size = risk_amount / (sl_distance_pips * 10 * tick_value);
      
      // Normalize lot size
      lot_size = NormalizeDouble(lot_size, 2);
      
      // Apply min/max limits
      if(lot_size < m_min_lot) lot_size = m_min_lot;
      if(lot_size > m_max_lot) lot_size = m_max_lot;
      
      return lot_size;
   }
   
   // Check trend filter (EMA + ADX)
   bool CheckTrendFilter(int direction)
   {
      if(!m_use_trend_filter) return true;
      
      // Get EMA value
      double ema_buffer[1];
      if(CopyBuffer(m_handle_ema, 0, 0, 1, ema_buffer) < 1) return false;
      
      // Get current price
      double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Check EMA condition
      bool ema_condition = false;
      if(direction == 1) // Buy signal
         ema_condition = (current_price > ema_buffer[0]);
      else if(direction == -1) // Sell signal
         ema_condition = (current_price < ema_buffer[0]);
      
      // Get ADX values
      double adx_buffer[1];
      double plus_di_buffer[1];
      double minus_di_buffer[1];
      
      if(CopyBuffer(m_handle_adx, 0, 0, 1, adx_buffer) < 1) return false;
      if(CopyBuffer(m_handle_adx, 1, 0, 1, plus_di_buffer) < 1) return false;
      if(CopyBuffer(m_handle_adx, 2, 0, 1, minus_di_buffer) < 1) return false;
      
      // Check ADX condition
      bool adx_condition = (adx_buffer[0] > m_adx_threshold);
      
      // Check DI condition for direction
      bool di_condition = false;
      if(direction == 1) // Buy signal
         di_condition = (plus_di_buffer[0] > minus_di_buffer[0]);
      else if(direction == -1) // Sell signal
         di_condition = (minus_di_buffer[0] > plus_di_buffer[0]);
      
      return (ema_condition && adx_condition && di_condition);
   }
   
   // Check ATR filter
   bool CheckATRFilter(double breakout_distance_pips)
   {
      if(!m_use_atr_filter) return true;
      
      // Get ATR value
      double atr_buffer[1];
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buffer) < 1) return false;
      
      // Convert ATR to pips
      double atr_pips = atr_buffer[0] / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Calculate required breakout distance
      double required_distance = atr_pips * m_atr_mult_min;
      
      // Check if breakout distance is sufficient
      return (breakout_distance_pips >= required_distance && breakout_distance_pips <= (atr_pips * m_atr_mult_max));
   }
   
   // Check volume filter
   bool CheckVolumeFilter()
   {
      if(!m_use_volume_filter) return true;
      
      // Get volume data
      long volume_array[20];
      if(CopyTickVolume(m_symbol, m_exec_tf, 0, 20, volume_array) < 20) return false;
      
      // Calculate SMA of volume
      long volume_sma = 0;
      for(int i = 0; i < 20; i++)
         volume_sma += volume_array[i];
      volume_sma /= 20;
      
      // Get current volume
      long current_volume = volume_array[0];
      
      // Check if current volume exceeds threshold
      return (current_volume > (volume_sma * m_volume_mult));
   }
   
   // Check Bollinger Bands filter
   bool CheckBBFilter(double range_high, double range_low)
   {
      if(!m_use_bb_filter) return true;
      
      // Get BB values
      double bb_upper_buffer[1];
      double bb_lower_buffer[1];
      
      if(CopyBuffer(m_handle_bb, 1, 0, 1, bb_upper_buffer) < 1) return false;
      if(CopyBuffer(m_handle_bb, 2, 0, 1, bb_lower_buffer) < 1) return false;
      
      // Calculate BB width in pips
      double bb_width_pips = (bb_upper_buffer[0] - bb_lower_buffer[0]) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Check if BB width is within acceptable range
      return (bb_width_pips >= m_min_width_pips && bb_width_pips <= m_max_width_pips);
   }
   
   // Generate trend-following signal
   int GenerateSignal()
   {
      // Reset signal
      m_last_signal_type = 0;
      
      // Get current price
      double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Get Asian session range (simplified - in real implementation, calculate from 00:00-06:00 GMT)
      double range_high = 0;
      double range_low = 0;
      
      // For demonstration, using last day's high/low
      MqlRates rates[1];
      if(CopyRates(m_symbol, m_range_tf, 0, 1, rates) < 1) return 0;
      
      range_high = rates[0].high;
      range_low = rates[0].low;
      
      // Calculate breakout distances
      double buy_distance_pips = (current_price - range_high) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double sell_distance_pips = (range_low - current_price) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Check for buy signal (price above range high)
      if(buy_distance_pips > 0)
      {
         // Check all filters
         if(CheckTrendFilter(1) &&
            CheckATRFilter(buy_distance_pips) &&
            CheckVolumeFilter() &&
            CheckBBFilter(range_high, range_low))
         {
            m_last_signal_type = 1;
            m_last_signal_time = TimeCurrent();
            return 1;
         }
      }
      
      // Check for sell signal (price below range low)
      if(sell_distance_pips > 0)
      {
         // Check all filters
         if(CheckTrendFilter(-1) &&
            CheckATRFilter(sell_distance_pips) &&
            CheckVolumeFilter() &&
            CheckBBFilter(range_high, range_low))
         {
            m_last_signal_type = -1;
            m_last_signal_time = TimeCurrent();
            return -1;
         }
      }
      
      return 0;
   }
   
   // Get signal details
   void GetSignalDetails(int &signal_type, double &entry_price, double &sl_price, double &tp_price, double &lot_size)
   {
      signal_type = m_last_signal_type;
      
      if(signal_type == 0)
      {
         entry_price = 0;
         sl_price = 0;
         tp_price = 0;
         lot_size = 0;
         return;
      }
      
      // Get current price
      double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Get Asian session range
      MqlRates rates[1];
      if(CopyRates(m_symbol, m_range_tf, 0, 1, rates) < 1) return;
      
      double range_high = rates[0].high;
      double range_low = rates[0].low;
      
      // Calculate entry, SL, TP
      if(signal_type == 1) // Buy signal
      {
         entry_price = current_price;
         sl_price = range_low;
         tp_price = entry_price + (m_tp_pips * SymbolInfoDouble(m_symbol, SYMBOL_POINT));
         
         // Calculate SL distance for lot sizing
         double sl_distance_pips = (entry_price - sl_price) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         // Get account equity for lot calculation
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         lot_size = CalculateLotSize(equity, sl_distance_pips);
      }
      else if(signal_type == -1) // Sell signal
      {
         entry_price = current_price;
         sl_price = range_high;
         tp_price = entry_price - (m_tp_pips * SymbolInfoDouble(m_symbol, SYMBOL_POINT));
         
         // Calculate SL distance for lot sizing
         double sl_distance_pips = (sl_price - entry_price) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         
         // Get account equity for lot calculation
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         lot_size = CalculateLotSize(equity, sl_distance_pips);
      }
   }
   
   // Get last signal time
   datetime GetLastSignalTime() { return m_last_signal_time; }
   
   // Get last signal type
   int GetLastSignalType() { return m_last_signal_type; }
   
   // Reset signal
   void ResetSignal()
   {
      m_last_signal_time = 0;
      m_last_signal_type = 0;
   }
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // This function should be implemented in the main EA file
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up resources
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // This function should be implemented in the main EA file
}

//+------------------------------------------------------------------+
