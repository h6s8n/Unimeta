#include "DrawingTypes.mqh"

//+------------------------------------------------------------------+
//| TrendLineDrawer.mqh                                              |
//| کلاس اصلی برای رسم خطوط روند                                     |
//+------------------------------------------------------------------+
class CTrendLineDrawer {
private:
    color m_line_color;    // رنگ خط
    int m_line_width;      // ضخامت خط
    double m_atr;          // مقدار ATR برای محاسبات
    TrendLineInfo trend_lines[];  // آرایه خطوط روند
    int trend_count;       // شمارنده خطوط روند

public:
    // Constructor
    CTrendLineDrawer(color line_color = clrBlue, int line_width = 1) {
        m_line_color = line_color;
        m_line_width = line_width;
        m_atr = 0;
        trend_count = 0;
    }

    // تنظیم ATR
    void SetATR(double atr) {
        m_atr = atr;
    }

    // رسم خط روند
    void DrawTrendLine(const string &name, 
                      datetime time1, double price1, 
                      datetime time2, double price2) {
        ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, m_line_color);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, m_line_width);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    }

    // نمایش زاویه و طول
    void DisplayAngle(const string &name, 
                     datetime time1, double price1, 
                     datetime time2, double price2) {
        // محاسبه زاویه و طول
        double delta_y = price2 - price1;
        double delta_x = (double)((time2 - time1) / PeriodSeconds(PERIOD_M5));
        
        if(delta_x == 0) return;
        
        // محاسبه زاویه
        double angle = MathArctan(delta_y/delta_x) * 180.0 / M_PI;
        
        // ذخیره اطلاعات خط روند
        ArrayResize(trend_lines, trend_count + 1);
        trend_lines[trend_count].name = name;
        trend_lines[trend_count].length = MathSqrt(MathPow(delta_x, 2) + MathPow(delta_y, 2));
        trend_lines[trend_count].end_time = time2;
        trend_lines[trend_count].angle = angle;
        trend_count++;
    }

    // هایلایت کردن خط
    void HighlightLine(const string &name) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 5);
    }

    // دریافت آخرین خط روند معتبر
    TrendLineInfo GetLatestValidTrendLine() {
        TrendLineInfo latest;
        latest.name = "";
        latest.length = 0;
        latest.end_time = 0;
        latest.angle = 0;
        ArrayResize(latest.times, 0);
        ArrayResize(latest.prices, 0);
        
        datetime latest_time = 0;
        
        for(int i = 0; i < trend_count; i++) {
            if(trend_lines[i].end_time > latest_time) {
                latest_time = trend_lines[i].end_time;
                latest = trend_lines[i];
            }
        }
        
        return latest;
    }

    // دریافت آخرین خط روند
    TrendLineInfo GetLatestTrendLine() {
        if(trend_count > 0) {
            return trend_lines[trend_count - 1];
        }
        TrendLineInfo empty;
        empty.name = "";
        empty.length = 0;
        empty.end_time = 0;
        empty.angle = 0;
        ArrayResize(empty.times, 0);
        ArrayResize(empty.prices, 0);
        return empty;
    }
};
