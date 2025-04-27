//+------------------------------------------------------------------+
//|                                                TradeManager.mqh  |
//| مدیریت معاملات و کنترل ریسک                                      |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include "../Settings/Config.mqh"

//+------------------------------------------------------------------+
//| کلاس مدیریت معاملات                                                |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade m_trade;           // شیء معاملاتی
    SSettings m_settings;     // تنظیمات
    
    //--- محاسبه حجم معامله
    double CalculateLotSize(double stopLoss)
    {
        double lotSize = m_settings.LotSize;
        
        // اگر حجم معامله از حداکثر مجاز بیشتر باشد، آن را محدود می‌کنیم
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        if(lotSize > maxLot) lotSize = maxLot;
        
        // اگر حجم معامله از حداقل مجاز کمتر باشد، آن را افزایش می‌دهیم
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        if(lotSize < minLot) lotSize = minLot;
        
        return NormalizeDouble(lotSize, 2);
    }
    
public:
    //--- Constructor
    CTradeManager(const SSettings &settings)
    {
        m_settings = settings;
        Initialize();
    }
    
    //--- راه‌اندازی اولیه
    void Initialize()
    {
        m_trade.SetExpertMagicNumber(123456);        // تنظیم شماره منحصر به فرد
        m_trade.SetMarginMode();                     // تنظیم حالت مارجین
        m_trade.SetTypeFillingBySymbol(_Symbol);     // تنظیم نوع پر کردن سفارش
        m_trade.SetDeviationInPoints(10);            // تنظیم انحراف مجاز قیمت
    }
    
    //--- بررسی وجود پوزیشن باز
    bool HasOpenPositions()
    {
        int total = PositionsTotal();
        for(int i = total - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            if(PositionSelectByTicket(ticket))
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                if(symbol == _Symbol) return true;
            }
        }
        return false;
    }
    
    //--- بررسی شرایط معامله
    bool CheckTradeConditions(bool is_buy, string trend_line_name, 
                            double trend_length, double trend_angle)
    {
        Print("=== Checking Trade Conditions ===");
        Print("Signal Type: ", (is_buy ? "BUY" : "SELL"));
        
        // بررسی اجازه معامله
        if(!m_settings.AllowTrading)
        {
            Print("Trading is not allowed (AllowTrading = false)");
            return false;
        }
        
        // بررسی وجود پوزیشن باز
        if(HasOpenPositions())
        {
            Print("Cannot open position - There are already open positions");
            return false;
        }
        
        // بررسی شرایط خط روند
        if(trend_line_name == "")
        {
            Print("No valid trend line available");
            return false;
        }
        
        // بررسی طول خط روند
        if(trend_length < m_settings.MinVectorLength)
        {
            Print("Trend line too short: ", DoubleToString(trend_length, 1), 
                " < ", DoubleToString(m_settings.MinVectorLength, 1));
            return false;
        }
        
        if(trend_length > m_settings.MaxVectorLength)
        {
            Print("Trend line too long: ", DoubleToString(trend_length, 1), 
                " > ", DoubleToString(m_settings.MaxVectorLength, 1));
            return false;
        }
        
        // بررسی زاویه
        double abs_angle = MathAbs(trend_angle);
        if(abs_angle < m_settings.MinSlopeAngle)
        {
            Print("Angle too small: ", DoubleToString(abs_angle, 1), 
                " < ", DoubleToString(m_settings.MinSlopeAngle, 1));
            return false;
        }
        
        // بررسی تطابق جهت سیگنال با روند
        bool is_uptrend = (trend_angle > 0);
        if(is_buy != is_uptrend)
        {
            Print("Signal direction does not match trend direction: Signal=", 
                (is_buy ? "BUY" : "SELL"), ", Trend=", 
                (is_uptrend ? "UP" : "DOWN"));
            return false;
        }
        
        Print("All trade conditions met!");
        return true;
    }
    
    //--- باز کردن پوزیشن جدید
    bool OpenPosition(bool is_buy)
    {
        Print("=== Attempting to Open Position ===");
        
        if(!m_settings.AllowTrading)
        {
            Print("Trading is not allowed (AllowTrading = false)");
            return false;
        }
        
        if(HasOpenPositions())
        {
            Print("Cannot open position - There are already open positions");
            return false;
        }
        
        // محاسبه حد ضرر بر اساس کندل سیگنال
        double high = iHigh(_Symbol, PERIOD_M5, 1);
        double low = iLow(_Symbol, PERIOD_M5, 1);
        double stop_loss;
        
        // دریافت قیمت‌های فعلی
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // محاسبه حد ضرر و حد سود
        if(is_buy)
        {
            stop_loss = low - (10 * _Point); // اضافه کردن بافر ایمنی
            double take_profit = ask + ((ask - stop_loss) * m_settings.RiskRewardRatio);
            
            // بررسی حداکثر حد ضرر
            if(MathAbs(ask - stop_loss) > m_settings.MaxStopLoss * _Point)
            {
                Print("Stop loss too large: ", 
                    DoubleToString(MathAbs(ask - stop_loss)/_Point, 1),
                    " > ", DoubleToString(m_settings.MaxStopLoss, 1));
                return false;
            }
            
            Print("Attempting BUY at ", ask, " SL: ", stop_loss, " TP: ", take_profit);
            return m_trade.Buy(
                CalculateLotSize(MathAbs(ask - stop_loss)),
                _Symbol,
                ask,
                stop_loss,
                take_profit,
                "Signal Trade"
            );
        }
        else
        {
            stop_loss = high + (10 * _Point); // اضافه کردن بافر ایمنی
            double take_profit = bid - ((stop_loss - bid) * m_settings.RiskRewardRatio);
            
            // بررسی حداکثر حد ضرر
            if(MathAbs(stop_loss - bid) > m_settings.MaxStopLoss * _Point)
            {
                Print("Stop loss too large: ", 
                    DoubleToString(MathAbs(stop_loss - bid)/_Point, 1),
                    " > ", DoubleToString(m_settings.MaxStopLoss, 1));
                return false;
            }
            
            Print("Attempting SELL at ", bid, " SL: ", stop_loss, " TP: ", take_profit);
            return m_trade.Sell(
                CalculateLotSize(MathAbs(stop_loss - bid)),
                _Symbol,
                bid,
                stop_loss,
                take_profit,
                "Signal Trade"
            );
        }
    }
    
    //--- بستن تمام پوزیشن‌ها
    void CloseAllPositions()
    {
        int total = PositionsTotal();
        for(int i = total - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            if(PositionSelectByTicket(ticket))
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                if(symbol == _Symbol)
                {
                    m_trade.PositionClose(ticket);
                }
            }
        }
    }
};



