/// API 端点常量 — 1:1 复刻 uni-app api/api.js
class ApiEndpoints {
  ApiEndpoints._();

  // 对齐 zdj-v1 api/req.js API_BASE_URL（api2 为当前启用环境，api 已被源码注释弃用）
  static const baseUrl = 'https://api2.huangjinetf.com';

  // ===================== UserCenter - Auth =====================
  static const login = '/usercenter/api/Auth/login';                    // POST
  static const appleLogin = '/usercenter/api/Auth/appleLogin';          // POST
  static const wechatLogin = '/usercenter/api/Auth/wechatLogin';        // GET ?code=&appId=
  static const wechatWebLoginUrl = '/usercenter/api/Auth/wechatWebLoginUrl'; // GET
  static const consumeWechatWebLoginTicket = '/usercenter/api/Auth/wechatWebLoginTicket'; // POST
  static const getCurrentUser = '/usercenter/api/Auth/me';              // GET
  static const logout = '/usercenter/api/Auth/logout';                  // POST
  static const generateCaptcha = '/usercenter/api/Auth/captcha/generate'; // GET
  static const sendSmsCode = '/usercenter/api/Auth/sendSmsCode';        // POST
  static const phoneLogin = '/usercenter/api/Auth/phoneLogin';          // POST
  static const checkAppVersion = '/usercenter/api/App/version/check';   // POST

  // ===================== UserCenter - User =====================
  static const uploadSign = '/usercenter/api/User/uploadSign';          // GET
  static const userOcrSign = '/usercenter/api/User/ocrSign';            // GET ?ext=
  static const userOcrSignForm = '/usercenter/api/User/ocrSignForm';    // GET ?ext=
  static const updateAvatar = '/usercenter/api/User/avatar';            // PUT
  static const updateAvatarCallback = '/usercenter/api/User/avatarcallback'; // PUT
  static const updateNickname = '/usercenter/api/User/nickname';        // PUT
  static const bindPhone = '/usercenter/api/User/bindPhone';            // POST
  static const bindWechat = '/usercenter/api/User/bindWechat';          // POST
  static const getPreferences = '/usercenter/api/User/preferences';     // GET
  static const savePreferences = '/usercenter/api/User/preferences';    // POST

  // ===================== SymbolData =====================
  static const symbolSearch = '/symboldata/api/SymbolBase/search';      // GET ?keyword=
  static const symbolSearchInfo = '/symboldata/api/SymbolBase/searchInfo'; // GET ?symbolId=
  static const symbolDetail = '/symboldata/api/SymbolBase';             // GET /{uniqueSymbol} 需拼接
  static const symbolSearchOperate = '/symboldata/api/SymbolBase/searchOperate'; // POST

  // ===================== UserAsset (V1) =====================
  // Home
  static const homeSymbols = '/userasset/api/Home/HomeSymbols';         // GET

  // AssetDetail
  static const assetDetailByBook = '/userasset/api/AssetDetail/bybook'; // GET ?bookId=
  static const assetDetail = '/userasset/api/AssetDetail';              // POST(create) PUT(update)
  static const assetDetailDelete = '/userasset/api/AssetDetail';        // DELETE /{assetId} 需拼接
  static const assetDetailBatchImport = '/userasset/api/AssetDetail/BatchImport'; // POST

  // AssetTrade
  static const assetTrade = '/userasset/api/AssetTrade';               // POST(create)
  static const assetTradeDelete = '/userasset/api/AssetTrade';          // DELETE /{recordId} 需拼接
  static const assetTradeRecords = '/userasset/api/AssetTrade/records'; // GET

  // AssetStats
  static const assetStatsTradestats = '/userasset/api/AssetStats/tradestats'; // GET
  static const assetStatsSummary = '/userasset/api/AssetStats/summary'; // GET
  static const assetStatsProfit = '/userasset/api/AssetStats/profit';   // GET
  static const assetStatsBookstats = '/userasset/api/AssetStats/bookstats'; // GET

  // Book
  static const book = '/userasset/api/Book';                           // GET(list) POST(create)
  static const bookUpdate = '/userasset/api/Book';                     // PUT /{bookId} 需拼接
  static const bookDelete = '/userasset/api/Book';                     // DELETE /{bookId} 需拼接
  static const bookBatchSort = '/userasset/api/Book/batchsort';        // PUT

  // Alert
  static const alertList = '/userasset/api/AssetAlert/list';           // GET
  static const alert = '/userasset/api/AssetAlert';                    // POST (create/update in one)
  static const alertDelete = '/userasset/api/AssetAlert';              // DELETE /{uniqueSymbol} 需拼接

  // ===================== Asset V2 =====================
  // Main
  static const assetBooks = '/asset/api/Asset/books';                  // GET(list) POST(?bookName= create) PUT(rename) DELETE /{bookId}
  static const assetBooksOrder = '/asset/api/Asset/books/order';       // PUT 账本排序 {bookOrders:{bookId:sort}}
  static const assetBookClear = '/asset/api/Asset/clear';              // DELETE /{bookId} 清空账本持仓
  static const assetBuy = '/asset/api/Asset/buy';                      // POST
  static const assetSell = '/asset/api/Asset/sell';                    // POST
  static const assetListV2 = '/asset/api/Asset';                       // GET ?bookId=
  static const assetReload = '/asset/api/Asset/reload';                // POST
  static const assetOrder = '/asset/api/Asset/order';                  // PUT
  static const assetBatchInput = '/asset/api/Asset/batchinput';        // POST
  static const assetBatchCorrect = '/asset/api/Asset/batchcorrect';    // POST
  static const assetOcr = '/asset/api/Asset/ocrSource';               // POST
  static const assetOcrPic = '/asset/api/Asset/ocr';                  // POST — ocrResult.vue ocrAssetPic 图片识别
  static const assetBySymbol = '/asset/api/Asset/symbol';            // GET /{symbolId} 需拼接
  static const assetDeleteV2 = '/asset/api/Asset';                     // DELETE /{assetId} 需拼接

  // Profit
  static const profitCalendarAsset = '/asset/api/Profit/asset';        // GET /{assetId}
  static const profitCalendarSymbol = '/asset/api/Profit/symbol';      // GET /{symbolId}
  static const profitCalendarBook = '/asset/api/Profit/book';          // GET /{bookId}
  static const profitCalendarAll = '/asset/api/Profit/all';            // GET
  static const profitDay = '/asset/api/Profit/day';                    // GET
  static const profitDistribution = '/asset/api/Profit/distribution';  // GET
  static const profitBookProfit = '/asset/api/Profit/bookProfit';      // GET

  // Favorite
  static const favoriteBooks = '/asset/api/Favorite/books';            // GET
  static const favoriteByBook = '/asset/api/Favorite';                  // GET /{bookId} 需拼接
  static const favorite = '/asset/api/Favorite';                       // POST(add) DELETE(remove/{id})
  static const favoriteBatchInput = '/asset/api/Favorite/batchinput';  // POST
  static const favoriteClear = '/asset/api/Favorite/clear';            // DELETE /{bookId} 需拼接
  static const favoriteBook = '/asset/api/Favorite/book';              // PUT 重命名自选账本 {bookId,newName}
  static const favoriteBookName = '/asset/api/Favorite/bookName';      // PUT ?bookName= 创建自选账本
  static const favoriteBookDelete = '/asset/api/Favorite/delete';      // DELETE /{bookId} 需拼接
  static const favoriteBySymbol = '/asset/api/Favorite/symbol';        // GET /{symbolId} 需拼接
  static const favoriteRemoveBySymbol = '/asset/api/Favorite/remove';  // DELETE /{symbolId} 需拼接

  // Symbol
  static const assetSymbolSearch = '/asset/api/Symbol/search';         // GET ?keyword=&assetType=
  static const assetSymbolSearchInfo = '/asset/api/Symbol/searchInfo'; // GET ?assetType= — 热搜/历史
  static const assetSymbolSearchOperate = '/asset/api/Symbol/searchOperate'; // POST ?symbolId= 记录搜索历史
  static const assetSymbolSearchHistory = '/asset/api/Symbol/searchHistory'; // DELETE 清空搜索历史
  static const assetSymbolHotIndex = '/asset/api/Symbol/hotIndex';     // GET
  static const assetSymbolIndicators = '/asset/api/Symbol/indicators'; // GET
  static const assetSymbolMinuteKline = '/asset/api/Symbol/minuteKline'; // GET /{symbolId}
  static const assetSymbolDailyLine = '/asset/api/Symbol/dailyLine';   // GET /{symbolId}
  static const assetSymbolDailyLines = '/asset/api/Symbol/dailyLines'; // POST
  static const assetSymbolDailyLinesRange = '/asset/api/Symbol/dailyLines/range'; // GET ?symbolId=&startDate=&endDate=
  static const assetSymbolDailyLinesAfter = '/asset/api/Symbol/dailyLines/after'; // GET ?symbolId=&afterDate=&count=
  static const assetSymbolInfo = '/asset/api/Symbol';                  // GET /{symbolId} 需拼接
  static const assetSymbolBatchInfo = '/asset/api/Symbol/symbolIds';   // POST body=[symbolId...]
  static const assetSymbolFundHoldings = '/asset/api/Symbol/fundHoldings'; // GET /{symbolId} 十大重仓股

  // FundDca 定投
  static const fundDcaFeeEstimate = '/asset/api/FundDca/fee-estimate'; // POST
  static const fundDcaPlans = '/asset/api/FundDca/plans';              // GET(list) POST(create) PUT /{id} POST /{id}/pause POST /{id}/cancel

  // AssetTrades 交易流水
  static const assetTrades = '/asset/api/Asset';                       // GET /{assetId}/trades 需拼接
  static const assetTradesQuery = '/asset/api/Asset/trades/query';     // POST 分页查询
  static const assetTradesBatchAmount = '/asset/api/Asset/trades/batch-amount'; // POST 批量加减仓

  // Market
  static const marketHotIndex = '/asset/api/Market/hotIndex';          // GET
  static const marketHotMetals = '/asset/api/Market/hotMetals';        // GET
  static const marketFundSectorRanking = '/asset/api/Market/fundSectorRanking'; // GET
  static const marketFundHeatTop = '/asset/api/Market/FundHeatTop';    // GET
  static const marketFundPickTop = '/asset/api/Market/FundPickTop';    // GET — 基金自选榜单
  static const marketFundContinuousUpCount = '/asset/api/Market/FundContinuousUpCount'; // GET
  static const marketFundChangeCount = '/asset/api/Market/FundChangeCount'; // GET
  static const marketFundHoldTop = '/asset/api/Market/FundHoldTop';    // GET
  static const marketFundStreakTop = '/asset/api/Market/FundStreakTop'; // GET
  static const marketFundQuoteTop = '/asset/api/Market/FundQuoteTop';  // GET

  // Banner
  static const banner = '/asset/api/Banner';                           // GET ?limit=

  // Vip
  static const vipHome = '/asset/api/Vip/home';                        // GET
  static const vipMorningReports = '/asset/api/Vip/morning-reports';   // GET ?pageNum=&pageSize= 或 GET /{id}
  static const vipClosingReports = '/asset/api/Vip/closing-reports';   // GET 或 GET /{id}
  static const vipFlowDataLatestSummary = '/asset/api/Vip/flow-data/latest-summary'; // GET
  static const vipAttentionRiseRanks = '/asset/api/Vip/attention-rise-ranks'; // GET /{period} 或 /{id}

  // Barrage
  static const barrage = '/asset/api/Barrage';                         // POST(send) GET /{fundId}
  static const barrageTrend = '/asset/api/Barrage/trend';              // GET

  // ===================== SignalR =====================
  static const signalrHub = '/asset/hubs/market';
  static String get signalrUrl => '$baseUrl$signalrHub';
}
