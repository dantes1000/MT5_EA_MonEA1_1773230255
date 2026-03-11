//+------------------------------------------------------------------+
//|                                                      Utilities.mqh |
//|                        Copyright 2024, MonEA1 Project             |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA1 Project"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Common constants and helper functions for MonEA1 Expert Advisor  |
//+------------------------------------------------------------------+

//--- Input parameter groups
#define GROUP_RISK           "=== Risk Management ==="
#define GROUP_TRADE          "=== Trade Settings ==="
#define GROUP_FILTERS        "=== Market Filters ==="
#define GROUP_SESSION        "=== Session Times ==="
#define GROUP_INDICATORS     "=== Indicator Parameters ==="
#define GROUP_ADVANCED       "=== Advanced Settings ==="

//--- Magic numbers
const long MAGIC_NUMBER = 20241101;  // Unique EA identifier

//--- Common error codes
enum ENUM_ERROR_CODES
{
    ERR_NO_ERROR = 0,
    ERR_INVALID_PARAMETER = 1,
    ERR_MARKET_CLOSED = 2,
    ERR_NO_TRADING_ALLOWED = 3,
    ERR_INSUFFICIENT_FUNDS = 4,
    ERR_ORDER_SEND_FAILED = 5,
    ERR_POSITION_NOT_FOUND = 6,
    ERR_INDICATOR_FAILED = 7,
    ERR_NEWS_FILTER_ACTIVE = 8,
    ERR_DAILY_DD_LIMIT = 9,
    ERR_MAX_TRADES_REACHED = 10,
    ERR_MIN_TIME_BETWEEN_TRADES = 11,
    ERR_WEEKEND_CLOSE = 12
};

//--- Trade types
enum ENUM_TRADE_DIRECTION
{
    TRADE_NONE = 0,
    TRADE_BUY = 1,
    TRADE_SELL = 2
};

//--- Timeframes
const ENUM_TIMEFRAMES DEFAULT_RANGE_TF = PERIOD_D1;
const ENUM_TIMEFRAMES DEFAULT_EXEC_TF = PERIOD_M30;
const ENUM_TIMEFRAMES DEFAULT_TREND_TF = PERIOD_H1;

//--- Session times (GMT)
const int ASIAN_SESSION_START_HOUR = 0;    // 00:00 GMT
const int ASIAN_SESSION_END_HOUR = 6;      // 06:00 GMT
const int LONDON_SESSION_START_HOUR = 8;   // 08:00 GMT
const int LONDON_SESSION_END_HOUR = 16;    // 16:00 GMT

//--- Default risk parameters
const double DEFAULT_RISK_PERCENT = 1.0;
const double DEFAULT_SL_PIPS = 30.0;
const double DEFAULT_TP_PIPS = 60.0;
const double DEFAULT_MIN_LOT = 0.01;
const double DEFAULT_MAX_LOT = 5.0;

//--- Default filter parameters
const int DEFAULT_ATR_PERIOD = 14;
const double DEFAULT_ATR_MULT_MIN = 1.25;
const double DEFAULT_ATR_MULT_MAX = 3.0;
const int DEFAULT_VOL_PERIOD = 20;
const double DEFAULT_VOL_MULT = 1.5;
const int DEFAULT_EMA_PERIOD = 200;
const int DEFAULT_ADX_PERIOD = 14;
const int DEFAULT_ADX_THRESHOLD = 20;
const int DEFAULT_BB_PERIOD = 20;
const double DEFAULT_BB_DEV = 2.0;
const double DEFAULT_MIN_RANGE_PIPS = 30.0;
const double DEFAULT_MAX_RANGE_PIPS = 120.0;
const double DEFAULT_MIN_ATR_PIPS = 20.0;
const double DEFAULT_MAX_ATR_PIPS = 150.0;

//--- Default trailing stop parameters
const double DEFAULT_TRAIL_ACTIVATION_PC = 50.0;
const double DEFAULT_TRAIL_MULT = 0.5;

//--- Default news filter parameters
const int DEFAULT_PAUSE_BEFORE_MIN = 60;
const int DEFAULT_PAUSE_AFTER_MIN = 30;

//--- Default trade limits
const int DEFAULT_MAX_OPEN_TRADES = 1;
const int DEFAULT_MAX_TRADES_PER_DAY = 3;
const int DEFAULT_MIN_TIME_BETWEEN_TRADES_HRS = 1;

//--- Weekend close parameters
const int DEFAULT_CLOSE_HOUR_FRI = 21;  // 21:00 GMT

//--- Margin for range calculation
const double DEFAULT_MARGIN_PIPS = 5.0;

//+------------------------------------------------------------------+
//| Utility functions                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize price to tick size                                     |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
}

//+------------------------------------------------------------------+
//| Normalize lot size to step size                                  |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    
    int steps = (int)MathRound(lot / lotStep);
    return steps * lotStep;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double stopLossPips, double equity = 0)
{
    if(equity <= 0) equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue <= 0 || tickSize <= 0) return DEFAULT_MIN_LOT;
    
    // Calculate risk amount in account currency
    double riskAmount = equity * riskPercent / 100.0;
    
    // Calculate lot size
    double lotSize = riskAmount / (stopLossPips * (tickValue / tickSize) * 10.0);
    
    return NormalizeLot(lotSize);
}

//+------------------------------------------------------------------+
//| Convert pips to price points                                     |
//+------------------------------------------------------------------+
double PipsToPoints(double pips)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    return pips * 10.0 * point;
}

//+------------------------------------------------------------------+
//| Calculate distance in pips between two prices                    |
//+------------------------------------------------------------------+
double PriceDistanceInPips(double price1, double price2)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    return MathAbs(price1 - price2) / (point * 10.0);
}

//+------------------------------------------------------------------+
//| Check if current time is within specified session                |
//+------------------------------------------------------------------+
bool IsInSession(int startHour, int endHour, datetime currentTime = 0)
{
    if(currentTime == 0) currentTime = TimeCurrent();
    
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    int currentHour = dt.hour;
    
    if(startHour <= endHour)
        return (currentHour >= startHour && currentHour < endHour);
    else
        return (currentHour >= startHour || currentHour < endHour);
}

//+------------------------------------------------------------------+
//| Check if it's Friday close time                                  |
//+------------------------------------------------------------------+
bool IsFridayCloseTime(int closeHour, datetime currentTime = 0)
{
    if(currentTime == 0) currentTime = TimeCurrent();
    
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    return (dt.day_of_week == 5 && dt.hour >= closeHour);
}

//+------------------------------------------------------------------+
//| Get number of open positions for this EA                         |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Get total profit/loss for today                                  |
//+------------------------------------------------------------------+
double GetDailyProfitLoss()
{
    double dailyPL = 0;
    datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
    
    HistorySelect(todayStart, TimeCurrent());
    
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MAGIC_NUMBER &&
           HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            dailyPL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
        }
    }
    
    // Add current open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
            dailyPL += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    return dailyPL;
}

//+------------------------------------------------------------------+
//| Check if symbol is in allowed pairs list                         |
//+------------------------------------------------------------------+
bool IsSymbolAllowed(string allowedPairs)
{
    string pairs[];
    StringSplit(allowedPairs, ',', pairs);
    
    for(int i = 0; i < ArraySize(pairs); i++)
    {
        StringTrimLeft(pairs[i]);
        StringTrimRight(pairs[i]);
        
        if(StringCompare(pairs[i], _Symbol, false) == 0)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get ATR value for specified timeframe                            |
//+------------------------------------------------------------------+
double GetATRValue(int period, ENUM_TIMEFRAMES tf, int shift = 0)
{
    double atrArray[];
    ArraySetAsSeries(atrArray, true);
    
    int handle = iATR(_Symbol, tf, period);
    if(handle == INVALID_HANDLE)
        return 0;
    
    if(CopyBuffer(handle, 0, shift, 1, atrArray) <= 0)
        return 0;
    
    IndicatorRelease(handle);
    return atrArray[0];
}

//+------------------------------------------------------------------+
//| Get EMA value for specified timeframe                            |
//+------------------------------------------------------------------+
double GetEMAValue(int period, ENUM_TIMEFRAMES tf, int shift = 0)
{
    double emaArray[];
    ArraySetAsSeries(emaArray, true);
    
    int handle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
        return 0;
    
    if(CopyBuffer(handle, 0, shift, 1, emaArray) <= 0)
        return 0;
    
    IndicatorRelease(handle);
    return emaArray[0];
}

//+------------------------------------------------------------------+
//| Get ADX value for specified timeframe                            |
//+------------------------------------------------------------------+
double GetADXValue(int period, ENUM_TIMEFRAMES tf, int shift = 0)
{
    double adxArray[];
    ArraySetAsSeries(adxArray, true);
    
    int handle = iADX(_Symbol, tf, period);
    if(handle == INVALID_HANDLE)
        return 0;
    
    if(CopyBuffer(handle, 0, shift, 1, adxArray) <= 0)
        return 0;
    
    IndicatorRelease(handle);
    return adxArray[0];
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands width in pips                                |
//+------------------------------------------------------------------+
double GetBBWidth(int period, double deviation, ENUM_TIMEFRAMES tf, int shift = 0)
{
    double upperArray[], lowerArray[];
    ArraySetAsSeries(upperArray, true);
    ArraySetAsSeries(lowerArray, true);
    
    int handle = iBands(_Symbol, tf, period, 0, deviation, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
        return 0;
    
    if(CopyBuffer(handle, 1, shift, 1, upperArray) <= 0 ||
       CopyBuffer(handle, 2, shift, 1, lowerArray) <= 0)
        return 0;
    
    IndicatorRelease(handle);
    return PriceDistanceInPips(upperArray[0], lowerArray[0]);
}

//+------------------------------------------------------------------+
//| Get volume ratio (current volume vs average)                     |
//+------------------------------------------------------------------+
double GetVolumeRatio(int period, ENUM_TIMEFRAMES tf, int shift = 0)
{
    double volumeArray[];
    ArraySetAsSeries(volumeArray, true);
    
    if(CopyTickVolume(_Symbol, tf, shift, period, volumeArray) <= 0)
        return 0;
    
    double currentVolume = volumeArray[0];
    double sumVolume = 0;
    
    for(int i = 0; i < period; i++)
    {
        sumVolume += volumeArray[i];
    }
    
    double avgVolume = sumVolume / period;
    
    if(avgVolume <= 0) return 0;
    
    return currentVolume / avgVolume;
}

//+------------------------------------------------------------------+
//| Check if price has broken above/below level with ATR confirmation|
//+------------------------------------------------------------------+
bool IsValidBreakout(double level, ENUM_TRADE_DIRECTION direction, 
                     double atrValue, double atrMultiplier, 
                     double currentPrice = 0)
{
    if(currentPrice <= 0) currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double breakoutThreshold = atrValue * atrMultiplier;
    
    if(direction == TRADE_BUY)
        return (currentPrice - level) >= breakoutThreshold;
    else if(direction == TRADE_SELL)
        return (level - currentPrice) >= breakoutThreshold;
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate trailing stop level                                     |
//+------------------------------------------------------------------+
double CalculateTrailingStop(double entryPrice, double currentPrice, 
                            double atrValue, double trailMultiplier,
                            ENUM_TRADE_DIRECTION direction)
{
    double trailDistance = atrValue * trailMultiplier;
    
    if(direction == TRADE_BUY)
    {
        double newStop = currentPrice - trailDistance;
        return MathMax(newStop, entryPrice);
    }
    else if(direction == TRADE_SELL)
    {
        double newStop = currentPrice + trailDistance;
        return MathMin(newStop, entryPrice);
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Format error message                                             |
//+------------------------------------------------------------------+
string FormatErrorMessage(ENUM_ERROR_CODES errorCode, string additionalInfo = "")
{
    string message;
    
    switch(errorCode)
    {
        case ERR_NO_ERROR:
            message = "No error";
            break;
        case ERR_INVALID_PARAMETER:
            message = "Invalid parameter: " + additionalInfo;
            break;
        case ERR_MARKET_CLOSED:
            message = "Market is closed";
            break;
        case ERR_NO_TRADING_ALLOWED:
            message = "Trading not allowed";
            break;
        case ERR_INSUFFICIENT_FUNDS:
            message = "Insufficient funds";
            break;
        case ERR_ORDER_SEND_FAILED:
            message = "Order send failed: " + additionalInfo;
            break;
        case ERR_POSITION_NOT_FOUND:
            message = "Position not found";
            break;
        case ERR_INDICATOR_FAILED:
            message = "Indicator failed: " + additionalInfo;
            break;
        case ERR_NEWS_FILTER_ACTIVE:
            message = "News filter active";
            break;
        case ERR_DAILY_DD_LIMIT:
            message = "Daily drawdown limit reached";
            break;
        case ERR_MAX_TRADES_REACHED:
            message = "Maximum trades reached";
            break;
        case ERR_MIN_TIME_BETWEEN_TRADES:
            message = "Minimum time between trades not met";
            break;
        case ERR_WEEKEND_CLOSE:
            message = "Weekend close time";
            break;
        default:
            message = "Unknown error: " + IntegerToString(errorCode);
    }
    
    return message;
}

//+------------------------------------------------------------------+
//| Log message to journal                                           |
//+------------------------------------------------------------------+
void LogMessage(string message, bool printToChart = true)
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string logMessage = StringFormat("[%s] %s", timestamp, message);
    
    Print(logMessage);
    
    if(printToChart)
        Comment(logMessage);
}

//+------------------------------------------------------------------+
//| Check if enough time has passed since last trade                 |
//+------------------------------------------------------------------+
bool CheckMinTimeBetweenTrades(int minHours, datetime &lastTradeTime)
{
    if(lastTradeTime == 0) return true;
    
    datetime currentTime = TimeCurrent();
    int secondsPassed = (int)(currentTime - lastTradeTime);
    int hoursPassed = secondsPassed / 3600;
    
    return hoursPassed >= minHours;
}

//+------------------------------------------------------------------+
//| Get Asian session high and low                                   |
//+------------------------------------------------------------------+
bool GetAsianSessionRange(ENUM_TIMEFRAMES tf, int startHour, int endHour,
                         double &sessionHigh, double &sessionLow,
                         datetime &sessionStartTime)
{
    sessionHigh = 0;
    sessionLow = DBL_MAX;
    
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    // Set session start time to today at startHour
    dt.hour = startHour;
    dt.min = 0;
    dt.sec = 0;
    sessionStartTime = StructToTime(dt);
    
    // Calculate how many bars to check (from session start to now)
    int bars = iBars(_Symbol, tf, sessionStartTime, currentTime);
    
    if(bars <= 0) return false;
    
    // Get high and low arrays
    double highArray[], lowArray[], timeArray[];
    ArraySetAsSeries(highArray, true);
    ArraySetAsSeries(lowArray, true);
    ArraySetAsSeries(timeArray, true);
    
    if(CopyHigh(_Symbol, tf, 0, bars, highArray) <= 0 ||
       CopyLow(_Symbol, tf, 0, bars, lowArray) <= 0 ||
       CopyTime(_Symbol, tf, 0, bars, timeArray) <= 0)
        return false;
    
    // Find high and low within Asian session hours
    for(int i = 0; i < bars; i++)
    {
        TimeToStruct(timeArray[i], dt);
        
        if(dt.hour >= startHour && dt.hour < endHour)
        {
            sessionHigh = MathMax(sessionHigh, highArray[i]);
            sessionLow = MathMin(sessionLow, lowArray[i]);
        }
    }
    
    if(sessionHigh <= 0 || sessionLow >= DBL_MAX)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
