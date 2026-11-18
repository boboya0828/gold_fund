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
  static const assetFundsMove = '/asset/api/Asset/funds/move';         // POST 移动分组 {sourceBookId,targetBookId,assetIds,keepSource,requestId}
  static const assetBatchDelete = '/asset/api/Asset/batch-delete';     // POST 批量删除 {assetIds:[...]}
  static const assetBatchInput = '/asset/api/Asset/batchinput';        // POST
  static const assetBatchCorrect = '/asset/api/Asset/batchcorrect';    // POST
  static const assetOcr = '/asset/api/Asset/ocrSource';               // POST
  static const assetOcrPic = '/asset/api/Asset/ocr';                  // POST — ocrResult.vue ocrAssetPic 图片识别
  static const assetBySymbol = '/asset/api/Asset/symbol';            // GET /{symbolId} 需拼接
  static const assetDeleteV2 = '/asset/api/Asset';                     // DELETE /{assetId} 需拼接
  static const assetExtendedColumns = '/asset/api/Asset/extended-columns'; // GET ?bookId= 重仓均涨幅/本周/本月/今年
  static const assetOverviewCards = '/asset/api/Asset/overview/cards'; // GET 账户汇总卡片
  static const holdingColumns = '/usercenter/api/User/holding-columns'; // GET 持仓表头管理配置
  static const holdingColumnsSave = '/usercenter/api/User/holding-columns'; // PUT 保存表头配置 {showHoldingAmount,showFundCode,columns:[{key,visible}]}
  static const estimateSourceOptions = '/usercenter/api/User/estimate-source/options'; // GET ?bookId= 估值数据源选项
  static const estimateSource = '/usercenter/api/User/estimate-source'; // GET 当前模式 / PUT 保存 {mode, bookId?}
  static const scrollContentCurrent = '/asset/api/ScrollContent/current'; // GET ?slotCode= 滚动通知条
  static const announcement = '/asset/api/Announcement';               // GET ?position=&limit= 公告开关
  static const assetIndexCarousel = '/asset/api/Asset/index-carousel'; // GET 指数轮播（免鉴权）
  static const symbolIndexes = '/asset/api/Symbol/indexes';            // GET ?MarketType=CN|HK|US|GL&PageIndex&PageSize
  static const goldEyeV1Quotes = '/asset/api/gold-eye-v1/quotes';      // GET 黄金商品行情列表
  static const goldEyeV1Intraday = '/asset/api/gold-eye-v1/intraday';  // GET /{symbolId} 需拼接 黄金分时
  static const communityGroupCount = '/asset/api/CommunityGroup/count'; // GET 基金群人数（匿名）

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
  static const assetSymbolDrawdownRecovery = '/asset/api/Symbol/drawdownRecovery'; // GET /{symbolId}?period= 需拼接
  static const indexDetailQuote = '/asset/api/IndexDetail';             // GET /{symbolId}/quote 需拼接
  static const indexDetailIntraday = '/asset/api/IndexDetail';          // GET /{symbolId}/intraday?days= 需拼接
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

  // 基金持仓详情页 (pages/index/fund/position-details)
  static const fundReturnRanking = '/asset/api/Market/FundReturnRanking'; // GET ?type=&period=&market=&pageIndex=&pageSize=
  static const fundStockFundFlowRoundSummaries = '/asset/api/Market/fundStockFundFlowRoundSummaries'; // GET ?fundCode=
  static const fundStockFundFlowDailyDetails = '/asset/api/Market/fundStockFundFlowDailyDetails'; // GET ?FundCode=&PageIndex=&PageSize=
  static const assetHoldDay = '/asset/api/Asset';                     // PUT /{assetId}/hold-day 需拼接 {holdDay}
  static const pointsAiDiagnosisAccess = '/asset/api/Points/ai-diagnosis/access'; // POST {businessNo}
  static const pointsStatus = '/asset/api/Points/status';              // GET 积分余额兜底

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
