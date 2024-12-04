//+------------------------------------------------------------------+
//*USDJPYで取引をする
//*開始時の値段を把握
//*0.03円ずつ値段を下げなら10個オーダー
//*ロットサイズは0.03
//*(A)5分ごとに建玉を確認し、建玉がなければ、
//すでに出しているオーダーの一番高い買値から0.03円ずつ上げながら、その時点の値段を超えないようにオーダーを出す。
//また、常に買い注文は10個までとする。
//新しくオーダーを入れたら、トータルのオーダーのうちで、低い値段で入れた買い注文は、トータルのオーダーが10個になるまで、キャンセルする
//*(B)5分ごとに建玉を確認し、建玉があり、含み益になっている場合は
//その建玉をすべて利確する。そして、買い注文が10個になるまで、すでにある買い注文の一番低い買値から0.03円ずつ下げて注文を入れる。
//*(C)5分ごとに建玉を確認し、建玉があり、含み益の建玉がない場合は
//何もせずに5分待つ。また5分後に建玉を確認し、含み益がない場合、買い注文がまだ残っている場合は、
//指値買い注文をすべてキャンセルし、
//その時点の値段を取得したうえで、
//その売値から0.03円低い値段から、0.03円ずつ下げて注文を10個新たに入れる。
//買い注文が残っていない場合は、5分待ってから、Aに戻る。
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                test-20241126.mq4 |
//|                                          Copyright 2024, DaiAndo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, DaiAndo"
#property link      ""
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                          Custom Trading Logic EA.mq4             |
//|                         Written for Your Request                 |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property version   "1.00"
#property strict

// 入力パラメータ
input double LotSize = 0.02;    // ロットサイズ
input double StepSize = 15;   // 価格間隔
input int MaxOrders = 12;       // 最大注文数
input int CheckInterval = 1;    // チェック間隔（分）
input int Max_Retry = 10;
input double Slippage = 35;

// グローバル変数
double startPrice;              // 開始時の価格
datetime lastCheckTime;         // 最後にチェックした時間

//+------------------------------------------------------------------+
//| 初期化関数                                                       |
//+------------------------------------------------------------------+
int OnInit()
{
    // 初期化
    startPrice = iClose("USDJPY", PERIOD_M1, 0); // 現在の価格を取得
    lastCheckTime = TimeCurrent();
    Print("EA initialized with start price: ", startPrice);

    // 最初のxx個の注文を配置
    PlaceInitialOrders();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| メイン関数                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    // xx分ごとにロジックを実行
    if (TimeCurrent() - lastCheckTime >= CheckInterval * 60)
    {
        lastCheckTime = TimeCurrent();
        ManageOrders();
    }
}

//+------------------------------------------------------------------+
//| 初期注文を配置する関数                                           |
//+------------------------------------------------------------------+
void PlaceInitialOrders()
{
    for (int i = 0; i < MaxOrders; i++)
    { 
        double price = NormalizeDouble(startPrice - i * StepSize * Point, 3);
        Print("stepsize * i: ", i, " - ", i * StepSize * Point);
        Print("checking price @ PlaceInitialOrders: ", i, " - ", price);
        PlaceBuyOrder(price);
    }
}

//+------------------------------------------------------------------+
//| 注文管理関数                                                     |
//+------------------------------------------------------------------+
void ManageOrders()
{
    int totalPositions = 0;
    double highestOrderPrice = -1;
    double lowestOrderPrice = DBL_MAX;
    bool hasOpenTrades = false;
    bool hasProfitableTrades = false;

   Print("ManageOrders...");
    // 建玉を確認
    for (int i = 0; i < OrdersTotal(); i++)
    {
        Print("checking OP_BUY...", i);
        if (OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == "USDJPY")
        {
            if (OrderType() == OP_BUY)
            {
                totalPositions++;
                Print("checking 001...", totalPositions);
                Print("checking 001-02... OrderOpenPrice : ", OrderOpenPrice());
                if (OrderOpenPrice() > highestOrderPrice) highestOrderPrice = OrderOpenPrice();
                if (OrderOpenPrice() < lowestOrderPrice) lowestOrderPrice = GetLowestBuyLimitPrice();
            }

            // 含み益の確認
            if (OrderType() == OP_BUY && OrderProfit() > 10)
            {
                Print("checking 002...", totalPositions);
                hasOpenTrades = true;
                hasProfitableTrades = true;
            }
            else if (OrderType() == OP_BUY)
            {
               Print("checking 003...", totalPositions);
                hasOpenTrades = true;
            }
        }
    }

    // (A) 建玉がなく、注文を再配置
    if (!hasOpenTrades && totalPositions == 0)
    {
        for (int i = 0; i < MaxOrders; i++)
        {
            Print("checking 004...", i);
            double price = NormalizeDouble(highestOrderPrice + i * StepSize * Point, Digits);
            if (price <= Bid) PlaceBuyOrder(price);
        }
        ManageBuyLimitOrders();
    }
    // (B) 建玉があり、含み益のある場合は利確して再配置
    else if (hasOpenTrades && hasProfitableTrades)
    {
        CloseProfitableBuyOrders();
        for (int i = 0; i < MaxOrders; i++)
        {
            Print("checking 005...", i);
            double price = NormalizeDouble(lowestOrderPrice - i * StepSize * Point, Digits);
            PlaceBuyOrder(price);
        }
        ManageBuyLimitOrders();
    }
    // (C) 建玉があり、含み益がない場合
    else if (hasOpenTrades && !hasProfitableTrades)
    {
        CancelAllBuyLimitOrders();
        startPrice = iClose("USDJPY", PERIOD_M1, 0); // 現在の価格を取得
        for (int i = 0; i < MaxOrders; i++)
        {
            Print("checking 005...MaxOrders * ", i, "  ", MaxOrders);
            double price = NormalizeDouble(startPrice - i * StepSize * Point, Digits);
            PlaceBuyOrder(price);
        }
    }
}

//+------------------------------------------------------------------+
//| 買い注文を配置する関数                                           |
//+------------------------------------------------------------------+
void PlaceBuyOrder(double price)
{
    int Retry = 0;
    Print("PlaceBuyOrder ... #price  ", price);
    int ticket = OrderSend("USDJPY", OP_BUYLIMIT, LotSize, price, Slippage, 0, 0, "Buy Order", 0, 0, clrBlue);
    
    while(ticket <= 0 && Retry <= Max_Retry)
      {
        ticket = OrderSend("USDJPY", OP_BUYLIMIT, LotSize, price, Slippage, 0, 0, "Buy Order", 0, 0, clrBlue);
        Retry++;
        if(Retry > Max_Retry)
        {
           Print("OrderSend failed with error #", GetLastError());
           break;
        }
        Sleep(100);
      }
}

//+------------------------------------------------------------------+
//| 全建玉を利確する関数                                             |
//+------------------------------------------------------------------+
//void CloseOrderWithRetry()
//{
//    int Retry = 0;
//    Print("closing op_buy ...  ");
//    for (int i = OrdersTotal() - 1; i >= 0; i--)
//    {
//        int ticket = OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == "USDJPY" && OrderType() == OP_BUY;
//        while(ticket <= 0 && Retry <= Max_Retry)
//        {
//            ticket = OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == "USDJPY" && OrderType() == OP_BUY;
//            Retry++;
//            if(Retry > Max_Retry)
//            {
//              Print("OrderSend failed with error #", GetLastError());
//              break;
//            }
//            Sleep(100);
//        }
//     }
//}

bool CloseOrderWithRetry(int ticket, double lots, double price, int slippage, color arrowColor) {
   const int maxRetries = 10; // リトライ回数
   int attempt = 0; // 試行回数カウンター
   bool success = false;

   while (attempt < maxRetries) {
      if (OrderSelect(ticket, SELECT_BY_TICKET)) {
         // 注文を閉じる
         success = OrderClose(ticket, lots, price, slippage, arrowColor);
         if (success) {
            Print("注文クローズ成功: チケット番号 = ", ticket);
            break; // 成功したらループを抜ける
         } else {
            Print("注文クローズ失敗: チケット番号 = ", ticket, " エラーコード: ", GetLastError());
         }
      } else {
         Print("注文選択失敗: チケット番号 = ", ticket, " エラーコード: ", GetLastError());
         break; // チケット選択に失敗したらリトライせず終了
      }

      // リトライの前に少し待機
      Sleep(200); // 200ms待機
      price = MarketInfo(OrderSymbol(), MODE_BID); //売値再取得
      attempt++;
   }

   if (!success) {
      Print("注文クローズに失敗しました: チケット番号 = ", ticket, " 最大リトライ回数到達");
   }

   return success;
}

//+------------------------------------------------------------------+
//| 含み益のある買いポジションを利確する関数                         |
//+------------------------------------------------------------------+
void CloseProfitableBuyOrders() {
   int totalOrders = OrdersTotal();

   for (int i = 0; i < totalOrders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         // 買い注文 (OP_BUY) のみを対象にする
         if (OrderType() == OP_BUY) {
            double profit = OrderProfit(); // 含み益を取得
            if (profit > 0) { // 含み益がある場合のみ利確
               double lots = OrderLots();
               double closePrice = MarketInfo(OrderSymbol(), MODE_BID); // 買い注文はBid価格でクローズ

               // ポジションを閉じる
               CloseOrderWithRetry(OrderTicket(), lots, closePrice, Slippage, clrBlue);
            }
         }
      } else {
         Print("注文選択失敗: インデックス = ", i, " エラーコード: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| 指値買い注文を管理する関数                                       |
//+------------------------------------------------------------------+
void ManageBuyLimitOrders() {
   int totalOrders = OrdersTotal();
   double buyLimitPrices[100]; // 最大100個の指値を格納可能
   int buyLimitOrderTicket[100]; // 該当する注文のチケット番号

   int count = 0;

   // 現在の指値買い注文を取得
   for (int i = 0; i < totalOrders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         // 指値買い注文のみを対象にする
         if (OrderType() == OP_BUYLIMIT) {
            buyLimitPrices[count] = OrderOpenPrice();
            buyLimitOrderTicket[count] = OrderTicket();
            count++;
         }
      }
   }

   // 指値買い注文が10個以下の場合は何もしない
   if (count <= 10) {
      return;
   }

   // 指値買い注文を価格の昇順にソート
   for (int i = 0; i < count - 1; i++) {
      for (int j = i + 1; j < count; j++) {
         if (buyLimitPrices[i] > buyLimitPrices[j]) {
            // 価格を入れ替え
            double tempPrice = buyLimitPrices[i];
            buyLimitPrices[i] = buyLimitPrices[j];
            buyLimitPrices[j] = tempPrice;

            // チケット番号も入れ替え
            int tempTicket = buyLimitOrderTicket[i];
            buyLimitOrderTicket[i] = buyLimitOrderTicket[j];
            buyLimitOrderTicket[j] = tempTicket;
         }
      }
   }

   // 余分な注文を削除
   for (int i = 0; i < count - 10; i++) {
      int ticket = buyLimitOrderTicket[i];
      if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
         Print("注文選択エラー: ", GetLastError());
         continue;
      }

      // 注文削除
      if (!OrderDelete(ticket)) {
         Print("注文削除エラー: ", GetLastError());
      } else {
         Print("注文削除成功: ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| 一番低い指値買い注文の価格を取得する関数                         |
//+------------------------------------------------------------------+
double GetLowestBuyLimitPrice() {
   int totalOrders = OrdersTotal();
   double lowestPrice = DBL_MAX; // 初期値は最大のダブル値

   for (int i = 0; i < totalOrders; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         // 指値買い注文 (OP_BUYLIMIT) のみを対象
         if (OrderType() == OP_BUYLIMIT) {
            double orderPrice = OrderOpenPrice(); // 指値価格を取得
            if (orderPrice < lowestPrice) {
               lowestPrice = orderPrice; // 最低価格を更新
            }
         }
      } else {
         Print("注文選択失敗: インデックス = ", i, " エラーコード: ", GetLastError());
      }
   }
   // 指値買い注文が1つもなければ -1 を返す
   if (lowestPrice == DBL_MAX) {
      Print("指値買い注文が存在しません。");
      return -1;
   }

   return lowestPrice;
}

//+------------------------------------------------------------------+
//| いったん指値の買い注文をすべてキャンセル                   |
//+------------------------------------------------------------------+
void CancelAllBuyLimitOrders() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_BUYLIMIT) {
                OrderDelete(OrderTicket());
            }
        }
    }
}