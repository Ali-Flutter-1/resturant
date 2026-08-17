/// One page of a paginated list.
///
/// [ApiClient.list] unwraps `items` and throws the rest away, which is fine for
/// an endpoint that returns everything. A list somebody can page through needs
/// the counts too — without `total_pages` there is no way to know whether asking
/// for another page is worth doing.
class PageData<T> {
  const PageData({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  /// Whether another page exists. `total_pages` is 0 for an empty result, so
  /// this is false there rather than inviting a request for page 1 of nothing.
  bool get hasMore => page < totalPages;

  /// Decodes each row, keeping the counts. Saves every repository rebuilding a
  /// page just to change the item type.
  PageData<R> map<R>(R Function(T item) decode) => PageData(
    items: [for (final item in items) decode(item)],
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
  );

  PageData<T> append(PageData<T> next) => PageData(
    items: [...items, ...next.items],
    page: next.page,
    pageSize: next.pageSize,
    total: next.total,
    totalPages: next.totalPages,
  );
}
