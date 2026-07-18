import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// 账本接口类型 — 1:1 uni-app bookApiType ('favorite' | 'asset')
/// favorite: 自选分组 (pages/optional/ledger.vue)
/// asset:    持仓账本 (pages/position/ledger.vue)
enum LedgerBookType { favorite, asset }

/// 账本管理接口封装 — 按 bookApiType 路由到自选/持仓两套 V2 接口
/// uni-app 对应: api/api.js 中 getFavoriteBooks/getAssetBooks 等成对接口
class LedgerBookApi {
  final LedgerBookType type;
  const LedgerBookApi(this.type);

  bool get isFavorite => type == LedgerBookType.favorite;

  /// 清空列/弹窗文案 (uni-app: 清空自选 | 清空持仓)
  String get clearTitle => isFavorite ? '清空自选' : '清空持仓';
  String get clearContent =>
      isFavorite ? '清空后当前账户下的自选记录将被移除，确定继续吗？' : '清空后当前账户下的持仓记录将被移除，确定继续吗？';

  /// 获取账本列表 (getFavoriteBooks | getAssetBooks)
  Future<Response<dynamic>> fetchBooks() =>
      ApiClient().get(isFavorite ? ApiEndpoints.favoriteBooks : ApiEndpoints.assetBooks);

  /// 创建账本 (createFavoriteBook: PUT bookName?bookName= | createAssetBook: POST books?bookName=)
  Future<Response<dynamic>> createBook(String name) {
    final encoded = Uri.encodeComponent(name);
    return isFavorite
        ? ApiClient().put('${ApiEndpoints.favoriteBookName}?bookName=$encoded')
        : ApiClient().post('${ApiEndpoints.assetBooks}?bookName=$encoded');
  }

  /// 重命名账本 (renameFavoriteBook: PUT Favorite/book | renameAssetBook: PUT Asset/books)
  /// body: {bookId, newName}; bookId=0 表示默认账本
  Future<Response<dynamic>> renameBook(int bookId, String newName) {
    final body = {'bookId': bookId, 'newName': newName};
    return isFavorite
        ? ApiClient().put(ApiEndpoints.favoriteBook, data: body)
        : ApiClient().put(ApiEndpoints.assetBooks, data: body);
  }

  /// 删除账本 (deleteFavoriteBook: DELETE Favorite/delete/{id} | deleteAssetBook: DELETE Asset/books/{id})
  Future<Response<dynamic>> deleteBook(int bookId) => isFavorite
      ? ApiClient().delete('${ApiEndpoints.favoriteBookDelete}/$bookId')
      : ApiClient().delete('${ApiEndpoints.assetBooks}/$bookId');

  /// 清空账本内容 (clearFavoriteBook: DELETE Favorite/clear/{id} | clearAssetBook: DELETE Asset/clear/{id})
  Future<Response<dynamic>> clearBook(int bookId) => isFavorite
      ? ApiClient().delete('${ApiEndpoints.favoriteClear}/$bookId')
      : ApiClient().delete('${ApiEndpoints.assetBookClear}/$bookId');

  /// 账本排序保存 — uni-app 两个 ledger 页统一走 updateAssetBookOrder
  /// PUT /asset/api/Asset/books/order, body: {bookOrders: {bookId: sortOrder}}
  Future<Response<dynamic>> updateBookOrder(Map<int, int> bookOrders) =>
      ApiClient().put(ApiEndpoints.assetBooksOrder, data: {'bookOrders': bookOrders});
}
