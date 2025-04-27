//+------------------------------------------------------------------+
//|                                                 DrawManager.mqh  |
//| مدیریت ترسیم خطوط و اشیاء گرافیکی روی چارت                        |
//+------------------------------------------------------------------+
#pragma once
#include "../Settings/Config.mqh"
#include "../Analysis/TrendAnalyzer.mqh"

class CDrawManager
{
private:
    SSettings m_settings;         // تنظیمات
    CTrendAnalyzer* m_analyzer;   // اشاره‌گر به تحلیلگر روند
    double m_atr;                 // مقدار ATR برای محاسبات

public:
    //--- Constructor
    CDrawManager(const SSettings &settings, CTrendAnalyzer* analyzer)
    {
        m_settings = settings;
        m_analyzer = analyzer;
        m_atr = 0;
    }

    //--- تنظیم مقدار ATR
    void SetATR(double atr)
    {
        m_atr = atr;
    }

    //--- پاک کردن تمام اشیاء
    void ClearAll()
    {
        ObjectsDeleteAll(0, "TrendLine");
        ObjectsDeleteAll(0, "Signal_");
        ObjectsDeleteAll(0, "Slope_");
        ObjectsDeleteAll(0, "EMA_");
        ObjectsDeleteAll(0, "Angle_");
        ObjectsDeleteAll(0, "TrendInfo_");
        ObjectsDeleteAll(0, "TrendArrow_");
    }

    //--- ترسیم خط روند
    void DrawTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color line_color)
    {
        if(!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2))
        {
            Print("Error creating trend line: ", GetLastError());
            return;
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, m_settings.LineWidth);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }

    //--- نمایش زاویه و اطلاعات خط روند
    void DisplayAngle(string base_name, datetime time1, double price1, datetime time2, double price2)
    {
        double angle = m_analyzer.CalculateAngle(time1, price1, time2, price2);
        double length = m_analyzer.CalculateVectorLength(time1, price1, time2, price2);
        m_analyzer.AddTrendLine(base_name, length, time2, angle);

        datetime time_mid = time1 + (time2 - time1)/2;
        double price_mid = price1 + (price2 - price1)/2;
        double price_offset = m_atr * 0.5;

        string angle_name = "Angle_" + base_name;
        if(!ObjectCreate(0, angle_name, OBJ_TEXT, 0, time_mid, price_mid + price_offset))
        {
            Print("Error creating angle text: ", GetLastError());
            return;
        }
        ObjectSetString(0, angle_name, OBJPROP_TEXT, StringFormat("%.1f° (%.1f)", angle, length));
        ObjectSetInteger(0, angle_name, OBJPROP_COLOR, clrMagenta);
        ObjectSetInteger(0, angle_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, angle_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
        ObjectSetString(0, angle_name, OBJPROP_FONT, "Arial Bold");
    }

    //--- ترسیم فلش سیگنال
    void DrawSignalArrow(int index, bool is_up)
    {
        datetime signal_time = iTime(_Symbol, PERIOD_M5, index);
        double signal_price = is_up ? 
            iLow(_Symbol, PERIOD_M5, index) - (m_settings.ArrowDistance * _Point) :
            iHigh(_Symbol, PERIOD_M5, index) + (m_settings.ArrowDistance * _Point);

        string signal_name = "Signal_" + IntegerToString(index);
        if(!ObjectCreate(0, signal_name, OBJ_ARROW, 0, signal_time, signal_price))
        {
            Print("Error creating signal arrow: ", GetLastError());
            return;
        }
        ObjectSetInteger(0, signal_name, OBJPROP_ARROWCODE, is_up ? 225 : 226);
        ObjectSetInteger(0, signal_name, OBJPROP_COLOR, m_settings.SignalColor);
        ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, m_settings.ArrowSize);
        ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_TOP);
    }

    //--- هایلایت کردن خط روند انتخاب شده
    void HighlightTrendLine(string name, double length)
    {
        string last_highlighted = m_analyzer.GetLastHighlighted();

        // بازنشانی خط قبلی هایلایت شده
        if(last_highlighted != "")
        {
            double price1 = ObjectGetDouble(0, last_highlighted, OBJPROP_PRICE, 0);
            double price2 = ObjectGetDouble(0, last_highlighted, OBJPROP_PRICE, 1);
            ObjectSetInteger(0, last_highlighted, OBJPROP_COLOR, price2 > price1 ? clrLime : clrRed);
            ObjectSetInteger(0, last_highlighted, OBJPROP_WIDTH, 1);
        }

        // هایلایت کردن خط جدید
        if(!ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow) ||
           !ObjectSetInteger(0, name, OBJPROP_WIDTH, 5))
        {
            Print("Error highlighting line: ", GetLastError());
            return;
        }

        // به‌روزرسانی جعبه اطلاعات
        string infoBoxName = "TrendInfo_" + name;
        ObjectsDeleteAll(0, "TrendInfo_");

        if(!ObjectCreate(0, infoBoxName, OBJ_LABEL, 0, 0, 0))
        {
            Print("Error creating info box: ", GetLastError());
            return;
        }
        ObjectSetInteger(0, infoBoxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, infoBoxName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, infoBoxName, OBJPROP_YDISTANCE, 10);
        ObjectSetInteger(0, infoBoxName, OBJPROP_COLOR, clrBlack);
        ObjectSetString(0, infoBoxName, OBJPROP_TEXT, "Last Valid Line Length = " + DoubleToString(length, 1));
        ObjectSetInteger(0, infoBoxName, OBJPROP_FONTSIZE, 8);

        m_analyzer.SetLastHighlighted(name);
        ChartRedraw();
    }
};
