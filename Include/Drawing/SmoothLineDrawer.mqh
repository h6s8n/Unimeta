#include "TrendLineDrawer.mqh"

//+------------------------------------------------------------------+
//| SmoothLineDrawer.mqh                                             |
//| کلاس رسم خطوط صاف                                                |
//+------------------------------------------------------------------+
class CSmoothLineDrawer {
private:
    CTrendLineDrawer* m_trend_drawer;  // اشاره‌گر به رسم‌کننده خط روند

public:
    // Constructor
    CSmoothLineDrawer(CTrendLineDrawer* trend_drawer) {
        m_trend_drawer = trend_drawer;
    }

    // رسم خط صاف
    void DrawSmoothLine(const string &name, 
                       datetime &times[], 
                       double &prices[]) {
        if(ArraySize(times) < 2 || ArraySize(prices) < 2) return;
        
        for(int i = 0; i < ArraySize(times) - 1; i++) {
            string line_name = name + "_" + IntegerToString(i);
            datetime time1 = times[i];
            double price1 = prices[i];
            datetime time2 = times[i+1];
            double price2 = prices[i+1];
            
            m_trend_drawer.DrawTrendLine(line_name, time1, price1, time2, price2);
        }
    }

    // رسم همه خطوط صاف
    void DrawAllSmoothLines(TrendLineInfo &lines[]) {
        for(int i = 0; i < ArraySize(lines); i++) {
            DrawSmoothLine(lines[i].name, lines[i].times, lines[i].prices);
        }
    }
};
