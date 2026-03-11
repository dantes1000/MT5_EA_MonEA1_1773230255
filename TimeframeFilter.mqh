//+------------------------------------------------------------------+
//|                                                      TimeframeFilter.mqh |
//|                        Copyright 2024, MonEA1 Project              |
//|                                             https://www.monea1.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA1 Project"
#property link      "https://www.monea1.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Class CTimeframeFilter: Ensures trading only occurs on M30       |
//| timeframe for the MonEA1 Expert Advisor                          |
//+------------------------------------------------------------------+
class CTimeframeFilter
{
private:
   // Input parameters
   ENUM_TIMEFRAMES   m_execution_tf;      // Execution timeframe (default: PERIOD_M30)
   bool              m_enable_filter;     // Enable/disable timeframe filter
   
public:
   // Constructor
   CTimeframeFilter()
   {
      m_execution_tf = PERIOD_M30;
      m_enable_filter = true;
   }
   
   // Destructor
   ~CTimeframeFilter() {}
   
   // Set execution timeframe
   void SetExecutionTF(ENUM_TIMEFRAMES tf) { m_execution_tf = tf; }
   
   // Enable/disable filter
   void EnableFilter(bool enable) { m_enable_filter = enable; }
   
   // Check if current timeframe is allowed for trading
   bool IsTradingAllowed()
   {
      // If filter is disabled, always allow trading
      if(!m_enable_filter)
         return true;
         
      // Get current chart timeframe
      ENUM_TIMEFRAMES current_tf = Period();
      
      // Check if current timeframe matches execution timeframe
      if(current_tf == m_execution_tf)
      {
         return true;
      }
      else
      {
         // Log warning if trading is attempted on wrong timeframe
         Print("TimeframeFilter: Trading not allowed on ", EnumToString(current_tf), 
               ". Required timeframe: ", EnumToString(m_execution_tf));
         return false;
      }
   }
   
   // Get execution timeframe as string
   string GetExecutionTFString()
   {
      return EnumToString(m_execution_tf);
   }
   
   // Get execution timeframe as enum
   ENUM_TIMEFRAMES GetExecutionTF()
   {
      return m_execution_tf;
   }
   
   // Check if specific timeframe is allowed
   bool IsTimeframeAllowed(ENUM_TIMEFRAMES tf)
   {
      if(!m_enable_filter)
         return true;
         
      return (tf == m_execution_tf);
   }
   
   // Get list of all supported timeframes for reference
   static string GetSupportedTimeframes()
   {
      return "M1,M5,M15,M30,H1,H4,D1,W1,MN1";
   }
   
   // Convert timeframe string to enum
   static ENUM_TIMEFRAMES StringToTF(string tf_str)
   {
      if(tf_str == "M1") return PERIOD_M1;
      if(tf_str == "M5") return PERIOD_M5;
      if(tf_str == "M15") return PERIOD_M15;
      if(tf_str == "M30") return PERIOD_M30;
      if(tf_str == "H1") return PERIOD_H1;
      if(tf_str == "H4") return PERIOD_H4;
      if(tf_str == "D1") return PERIOD_D1;
      if(tf_str == "W1") return PERIOD_W1;
      if(tf_str == "MN1") return PERIOD_MN1;
      
      // Default to M30 if string not recognized
      return PERIOD_M30;
   }
   
   // Convert timeframe enum to string
   static string TFToString(ENUM_TIMEFRAMES tf)
   {
      return EnumToString(tf);
   }
   
   // Validate if timeframe is valid for this strategy
   bool IsValidTimeframe(ENUM_TIMEFRAMES tf)
   {
      // For Range Breakout Asian Session strategy, recommend M15 or M30
      // but allow other timeframes for testing
      if(tf == PERIOD_M15 || tf == PERIOD_M30 || tf == PERIOD_H1)
         return true;
         
      // Other timeframes may be used for testing but with warning
      Print("TimeframeFilter: Timeframe ", EnumToString(tf), " may not be optimal for Range Breakout strategy");
      return true; // Still allow for testing purposes
   }
   
   // Display timeframe information
   void DisplayInfo()
   {
      Print("Timeframe Filter Configuration:");
      Print("  Execution Timeframe: ", GetExecutionTFString());
      Print("  Filter Enabled: ", m_enable_filter ? "Yes" : "No");
      Print("  Current Timeframe: ", EnumToString(Period()));
      Print("  Trading Allowed: ", IsTradingAllowed() ? "Yes" : "No");
   }
};

//+------------------------------------------------------------------+
//| Global instance of timeframe filter                              |
//+------------------------------------------------------------------+
CTimeframeFilter TimeframeFilter;