import '../shared/models/app_models.dart';
import 'qolip_search_engine.dart';

export 'qolip_search_engine.dart';

final _locationDocuments = Expando<QolipSearchDocument>();
QolipSearchDocument qolipLocationSearchDocument(QolipLocationEntry item) =>
    _locationDocuments[item] ??= QolipSearchDocument([
      item.itemName,
      item.itemCode,
      item.qolipCode,
      '${item.size}',
      item.block,
      item.warehouse,
      item.locationLabel,
    ]);

bool qolipLocationSearchMatches(String query, QolipLocationEntry item) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(qolipLocationSearchDocument(item));

final _productDocuments = Expando<QolipSearchDocument>();
QolipSearchDocument qolipProductSearchDocument(QolipProduct product) =>
    _productDocuments[product] ??= QolipSearchDocument([
      product.name,
      product.code,
      product.itemGroup,
      product.qolipCode,
      if (product.qolipSize > 0) '${product.qolipSize}',
      ...product.customerNames,
    ]);

bool qolipProductSearchMatches(String query, QolipProduct product) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(qolipProductSearchDocument(product));

final _checkoutDocuments = Expando<QolipSearchDocument>();
QolipSearchDocument qolipCheckoutSearchDocument(QolipCheckoutEntry checkout) =>
    _checkoutDocuments[checkout] ??= QolipSearchDocument([
      checkout.issuedToName,
      checkout.itemName,
      checkout.itemCode,
      checkout.qolipCode,
      checkout.block,
      checkout.warehouse,
      checkout.locationLabel,
      '${checkout.size}',
    ]);

bool qolipCheckoutSearchMatches(String query, QolipCheckoutEntry checkout) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(qolipCheckoutSearchDocument(checkout));

final _blockDocuments = Expando<QolipSearchDocument>();
QolipSearchDocument qolipBlockSearchDocument(QolipBlock block) =>
    _blockDocuments[block] ??=
        QolipSearchDocument([block.name, block.warehouse]);

bool qolipBlockSearchMatches(String query, QolipBlock block) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(qolipBlockSearchDocument(block));

final _workerDocuments = Expando<QolipSearchDocument>();
QolipSearchDocument qolipWorkerSearchDocument(QolipWorkerOption worker) =>
    _workerDocuments[worker] ??=
        QolipSearchDocument([worker.name, worker.level]);

bool qolipWorkerSearchMatches(String query, QolipWorkerOption worker) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(qolipWorkerSearchDocument(worker));

String? _lastQuery;
QolipSearchQuery? _lastPreparedQuery;
QolipSearchQuery _preparedQuery(String query) {
  if (_lastQuery != query) {
    _lastQuery = query;
    _lastPreparedQuery = QolipSearchQuery(query);
  }
  return _lastPreparedQuery!;
}

bool qolipSearchMatches(String query, Iterable<String> values) =>
    query.trim().isEmpty ||
    _preparedQuery(query).matches(QolipSearchDocument(values));
