#include "DrawingTypes.mqh"

//+------------------------------------------------------------------+
//| SignalDrawer.mqh                                                 |
//| کلاس رسم سیگنال‌ها                                               |
//+------------------------------------------------------------------+
class CSignalDrawer {
private:
    color m_signal_color;  // رنگ سیگنال
    int m_arrow_size;      // اندازه فلش
    int m_arrow_distance;  // فاصله از کندل

public:
    // Constructor
    CSignalDrawer(color signal_color = clrYellow, 
                 int arrow_size = 3, 
                 int arrow_distance = 5) {
        m_signal_color = signal_color;
        m_arrow_size = arrow_size;
        m_arrow_distance = arrow_distance;
    }

    // رسم فلش سیگنال
    void DrawSignal(const SignalInfo &signal) {
        string arrow_name = "Signal_" + signal.name;
        ObjectCreate(0, arrow_name, OBJ_ARROW, 0, signal.time, signal.price);
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, signal.is_buy ? 233 : 234);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_signal_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, m_arrow_size);
    }

    // رسم همه سیگنال‌ها
    void DrawAllSignals(const SignalInfo &signals[]) {
        for(int i = 0; i < ArraySize(signals); i++) {
            DrawSignal(signals[i]);
        }
    }
};
