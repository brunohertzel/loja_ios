class StoreBanner {
  const StoreBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.link,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? link;

  factory StoreBanner.fromJson(Map<String, dynamic> json) => StoreBanner(
    id: _s(json['id'], ''),
    title: _s(json['title'] ?? json['titulo'], 'Oferta'),
    subtitle: _nullable(json['subtitle'] ?? json['subtitulo']),
    imageUrl: _nullable(
      json['image_url'] ?? json['imagem_url'] ?? json['imagem'],
    ),
    link: _nullable(json['link'] ?? json['url']),
  );
}

class StoreCategory {
  const StoreCategory({required this.id, required this.name, this.imageUrl});
  final String id;
  final String name;
  final String? imageUrl;

  factory StoreCategory.fromJson(Map<String, dynamic> json) => StoreCategory(
    id: _s(json['id'] ?? json['codigo'], ''),
    name: _s(json['name'] ?? json['nome'] ?? json['descricao'], 'Categoria'),
    imageUrl: _nullable(
      json['image_url'] ?? json['imagem_url'] ?? json['imagem'],
    ),
  );
}

class QuantityRules {
  const QuantityRules({
    required this.customerType,
    required this.unit,
    required this.defaultVisual,
    required this.defaultReal,
    required this.step,
    required this.minimum,
    required this.decimals,
    required this.hasQuantityVariation,
  });

  final String customerType;
  final String unit;
  final double defaultVisual;
  final double defaultReal;
  final double step;
  final double minimum;
  final int decimals;
  final bool hasQuantityVariation;

  bool get isB2b => customerType.toUpperCase() == 'B2B';

  factory QuantityRules.fromJson(
    Map<String, dynamic> json, {
    String unit = 'UN',
  }) => QuantityRules(
    customerType: _s(json['customer_type'], 'B2C').toUpperCase(),
    unit: _s(json['unit'], unit),
    defaultVisual: _d(json['default_visual'], fallback: 1),
    defaultReal: _d(json['default_real'], fallback: 1),
    step: _d(json['step'], fallback: 1),
    minimum: _d(json['minimum'], fallback: 1),
    decimals: _i(json['decimals']),
    hasQuantityVariation: _b(json['has_quantity_variation'], false),
  );

  Map<String, dynamic> toJson() => {
    'customer_type': customerType,
    'unit': unit,
    'default_visual': defaultVisual,
    'default_real': defaultReal,
    'step': step,
    'minimum': minimum,
    'decimals': decimals,
    'has_quantity_variation': hasQuantityVariation,
  };
}

class StoreCampaign {
  const StoreCampaign({
    required this.id,
    required this.name,
    required this.type,
    required this.offerPrice,
    required this.minimumQuantity,
    required this.paidQuantity,
    this.startsAt,
    this.endsAt,
    this.kind = 'STANDARD',
  });

  final int id;
  final String name;
  final String type;
  final double offerPrice;
  final double minimumQuantity;
  final double paidQuantity;
  final String? startsAt;
  final String? endsAt;
  final String kind;

  factory StoreCampaign.fromJson(Map<String, dynamic> json) => StoreCampaign(
    id: _i(json['id']),
    name: _s(json['name'] ?? json['nome'], 'Promoção'),
    type: _s(json['type'] ?? json['tipo'], 'SIMPLES').toUpperCase(),
    offerPrice: _d(json['offer_price'] ?? json['preco_oferta']),
    minimumQuantity: _d(
      json['minimum_quantity'] ?? json['qtde_minima_ativar'],
      fallback: 1,
    ),
    paidQuantity: _d(
      json['paid_quantity'] ?? json['qtde_preco_normal'],
      fallback: 1,
    ),
    startsAt: _nullable(json['starts_at'] ?? json['data_inicial']),
    endsAt: _nullable(json['ends_at'] ?? json['data_final']),
    kind: _s(json['kind'] ?? json['tipo_oferta'], 'STANDARD').toUpperCase(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'offer_price': offerPrice,
    'minimum_quantity': minimumQuantity,
    'paid_quantity': paidQuantity,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'kind': kind,
  };
}

class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    required this.observationText,
    this.numberMin,
    this.numberMax,
    this.numberStep = 1,
    this.numberUnit,
    this.affectsQuantity = false,
    this.quantityMultiplier,
    this.quantityText,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String observationText;
  final double? numberMin;
  final double? numberMax;
  final double numberStep;
  final String? numberUnit;
  final bool affectsQuantity;
  final double? quantityMultiplier;
  final String? quantityText;
  final bool isDefault;

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
    id: _i(json['id']),
    name: _s(json['name'] ?? json['descricao'], 'Opção'),
    observationText: _s(
      json['observation_text'] ?? json['valor_obs'] ?? json['name'],
      '',
    ),
    numberMin: _nullableDouble(json['number_min'] ?? json['numero_min']),
    numberMax: _nullableDouble(json['number_max'] ?? json['numero_max']),
    numberStep: _d(json['number_step'] ?? json['numero_step'], fallback: 1),
    numberUnit: _nullable(json['number_unit'] ?? json['numero_unidade']),
    affectsQuantity: _b(
      json['affects_quantity'] ?? json['afeta_quantidade'],
      false,
    ),
    quantityMultiplier: _nullableDouble(
      json['quantity_multiplier'] ?? json['multiplicador_quantidade'],
    ),
    quantityText: _nullable(json['quantity_text'] ?? json['texto_quantidade']),
    isDefault: _b(json['default'] ?? json['padrao'], false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'observation_text': observationText,
    'number_min': numberMin,
    'number_max': numberMax,
    'number_step': numberStep,
    'number_unit': numberUnit,
    'affects_quantity': affectsQuantity,
    'quantity_multiplier': quantityMultiplier,
    'quantity_text': quantityText,
    'default': isDefault,
  };
}

class ProductOptionBlock {
  const ProductOptionBlock({
    required this.id,
    required this.name,
    required this.type,
    required this.isRequired,
    required this.options,
    this.icon,
  });

  final int id;
  final String name;
  final String type;
  final bool isRequired;
  final String? icon;
  final List<ProductOption> options;

  factory ProductOptionBlock.fromJson(Map<String, dynamic> json) =>
      ProductOptionBlock(
        id: _i(json['id']),
        name: _s(json['name'] ?? json['titulo_loja'], 'Opção'),
        type: _s(json['type'] ?? json['tipo_selecao'], 'radio').toLowerCase(),
        isRequired: _b(json['required'] ?? json['obrigatorio'], false),
        icon: _nullable(json['icon'] ?? json['icone_fa']),
        options: _list(
          json['options'] ?? json['variacoes'],
        ).map(ProductOption.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'required': isRequired,
    'icon': icon,
    'options': options.map((e) => e.toJson()).toList(),
  };
}

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.price,
    this.oldPrice,
    this.imageUrl,
    this.description,
    this.fullDescription,
    this.technicalInfo,
    this.technicalInfoHtml,
    this.recommendations = const [],
    this.unit,
    this.categoryId,
    this.code,
    this.barcode,
    this.brand,
    this.department,
    this.sponsored = false,
    this.priceDisplayMode = 'PRECO_CHEIO',
    this.fractionPrice,
    this.fractionLabel,
    this.videoUrl,
    this.available = true,
    this.favorite = false,
    this.step = 1,
    this.gallery = const [],
    this.optionBlocks = const [],
    this.quantityRules,
    this.campaign,
    this.freeFreightDelivery = false,
    this.freeFreightWholesale = false,
  });

  final String id;
  final String name;
  final double price;
  final double? oldPrice;
  final String? imageUrl;
  final String? description;
  final String? fullDescription;
  final String? technicalInfo;
  final String? technicalInfoHtml;
  final List<StoreProduct> recommendations;
  final String? unit;
  final String? categoryId;
  final String? code;
  final String? barcode;
  final String? brand;
  final String? department;
  final bool sponsored;
  final String priceDisplayMode;
  final double? fractionPrice;
  final String? fractionLabel;
  final String? videoUrl;
  final bool available;
  final bool favorite;
  final double step;
  final List<String> gallery;
  final List<ProductOptionBlock> optionBlocks;
  final QuantityRules? quantityRules;
  final StoreCampaign? campaign;
  final bool freeFreightDelivery;
  final bool freeFreightWholesale;

  double get basePrice => oldPrice != null && oldPrice! > 0 ? oldPrice! : price;
  bool get hasOffer => oldPrice != null && oldPrice! > price;
  bool get needsConfiguration => optionBlocks.isNotEmpty;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    final unit = _nullable(
      json['unit'] ?? json['unidade'] ?? json['unidade_codigo'],
    );
    final qMap = _map(json['quantity_rules']);
    final camp = _map(json['campaign']);
    final galleries = <String>[];
    final rawGallery = json['gallery'];
    if (rawGallery is List) {
      for (final item in rawGallery) {
        final value = _nullable(item);
        if (value != null) galleries.add(value);
      }
    }
    return StoreProduct(
      id: _s(json['id'] ?? json['produto_id'] ?? json['codigo'], ''),
      name: _s(
        json['name'] ??
            json['nome'] ??
            json['descricao_site'] ??
            json['descricao'],
        'Produto',
      ),
      price: _d(json['price'] ?? json['preco'] ?? json['preco_venda']),
      oldPrice: _nullableDouble(
        json['old_price'] ?? json['preco_de'] ?? json['preco_normal'],
      ),
      imageUrl: _nullable(
        json['image_url'] ??
            json['imagem_url'] ??
            json['imagem'] ??
            json['foto'],
      ),
      description: _nullable(
        json['description'] ??
            json['descricao_detalhada'] ??
            json['descricao_site'],
      ),
      fullDescription: _nullable(
        json['full_description'] ?? json['descricao_completa'],
      ),
      technicalInfo: _nullable(json['technical_info'] ?? json['ficha_tecnica']),
      technicalInfoHtml: _nullable(
        json['technical_info_html'] ?? json['ficha_tecnica_html'],
      ),
      recommendations: _list(
        json['recommendations'] ??
            json['recomendacoes'] ??
            json['produtos_sugeridos'],
      ).map(StoreProduct.fromJson).toList(),
      unit: unit,
      categoryId: _nullable(
        json['category_id'] ?? json['categoria_id'] ?? json['departamento_id'],
      ),
      code: _nullable(json['code'] ?? json['codigo'] ?? json['cod_erp']),
      barcode: _nullable(json['barcode'] ?? json['codigo_barras']),
      brand: _nullable(json['brand'] ?? json['marca']),
      department: _nullable(json['department'] ?? json['departamento']),
      sponsored: _b(json['sponsored'] ?? json['patrocinado'], false),
      priceDisplayMode: _s(
        _map(json['price_display'])['mode'] ?? json['price_display_mode'],
        'PRECO_CHEIO',
      ).toUpperCase(),
      fractionPrice: _nullableDouble(
        _map(json['price_display'])['fraction_price'] ?? json['fraction_price'],
      ),
      fractionLabel: _nullable(
        _map(json['price_display'])['fraction_label'] ?? json['fraction_label'],
      ),
      videoUrl: _nullable(json['video_url']),
      available: _b(
        json['available'] ?? json['disponivel'] ?? json['ativo'],
        true,
      ),
      favorite: _b(json['favorite'] ?? json['favorito'], false),
      step: _d(json['step'] ?? json['incremento'] ?? 1, fallback: 1),
      gallery: galleries,
      optionBlocks: _list(
        json['option_blocks'] ?? json['opcionais'],
      ).map(ProductOptionBlock.fromJson).toList(),
      quantityRules: qMap.isNotEmpty
          ? QuantityRules.fromJson(qMap, unit: unit ?? 'UN')
          : null,
      campaign: camp.isNotEmpty ? StoreCampaign.fromJson(camp) : null,
      freeFreightDelivery: _b(json['free_freight_delivery'], false),
      freeFreightWholesale: _b(json['free_freight_wholesale'], false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'old_price': oldPrice,
    'image_url': imageUrl,
    'description': description,
    'full_description': fullDescription,
    'technical_info': technicalInfo,
    'technical_info_html': technicalInfoHtml,
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
    'unit': unit,
    'category_id': categoryId,
    'code': code,
    'barcode': barcode,
    'brand': brand,
    'department': department,
    'sponsored': sponsored,
    'price_display': {
      'mode': priceDisplayMode,
      'fraction_price': fractionPrice,
      'fraction_label': fractionLabel,
    },
    'video_url': videoUrl,
    'available': available,
    'favorite': favorite,
    'step': step,
    'gallery': gallery,
    'option_blocks': optionBlocks.map((e) => e.toJson()).toList(),
    'quantity_rules': quantityRules?.toJson(),
    'campaign': campaign?.toJson(),
    'free_freight_delivery': freeFreightDelivery,
    'free_freight_wholesale': freeFreightWholesale,
  };
}

class CampaignPriceResult {
  const CampaignPriceResult({
    required this.subtotal,
    required this.effectiveUnitPrice,
    required this.applied,
    this.message,
  });
  final double subtotal;
  final double effectiveUnitPrice;
  final bool applied;
  final String? message;
}

CampaignPriceResult calculateCampaign(
  StoreProduct product,
  double realQuantity,
) {
  final base = product.basePrice;
  final campaign = product.campaign;
  if (campaign == null || realQuantity <= 0 || base <= 0) {
    return CampaignPriceResult(
      subtotal: base * realQuantity,
      effectiveUnitPrice: base,
      applied: false,
    );
  }
  final type = campaign.type.toUpperCase();
  if (type == 'SIMPLES' &&
      campaign.offerPrice > 0 &&
      campaign.offerPrice < base) {
    return CampaignPriceResult(
      subtotal: campaign.offerPrice * realQuantity,
      effectiveUnitPrice: campaign.offerPrice,
      applied: true,
      message: 'Oferta aplicada.',
    );
  }
  if (type == 'QTDE_MINIMA') {
    if (realQuantity >= campaign.minimumQuantity &&
        campaign.offerPrice > 0 &&
        campaign.offerPrice < base) {
      return CampaignPriceResult(
        subtotal: campaign.offerPrice * realQuantity,
        effectiveUnitPrice: campaign.offerPrice,
        applied: true,
        message: 'Preço promocional ativado.',
      );
    }
    final missing = (campaign.minimumQuantity - realQuantity)
        .clamp(0, double.infinity)
        .toDouble();
    return CampaignPriceResult(
      subtotal: base * realQuantity,
      effectiveUnitPrice: base,
      applied: false,
      message:
          'Faltam ${formatQuantity(missing, 3)} ${product.unit ?? ''} para ativar a promoção.',
    );
  }
  if (type == 'LEVE_X_PAGUE_Y' && campaign.minimumQuantity > 0) {
    final blocks = (realQuantity / campaign.minimumQuantity).floor();
    final rest = realQuantity - (blocks * campaign.minimumQuantity);
    final subtotal = (blocks * campaign.paidQuantity * base) + (rest * base);
    return CampaignPriceResult(
      subtotal: subtotal,
      effectiveUnitPrice: realQuantity > 0 ? subtotal / realQuantity : base,
      applied: blocks > 0,
      message: blocks > 0
          ? 'Leve ${formatQuantity(campaign.minimumQuantity, 3)} e pague ${formatQuantity(campaign.paidQuantity, 3)} aplicado.'
          : 'Adicione mais ${formatQuantity(campaign.minimumQuantity - realQuantity, 3)} ${product.unit ?? ''} para ativar a promoção.',
    );
  }
  return CampaignPriceResult(
    subtotal: base * realQuantity,
    effectiveUnitPrice: base,
    applied: false,
  );
}

String formatQuantity(double value, int decimals) {
  if (decimals <= 0 || value == value.roundToDouble())
    return value.toInt().toString();
  var text = value
      .toStringAsFixed(decimals)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return text.replaceAll('.', ',');
}

enum StoreProductSort {
  standard,
  az,
  za,
  priceAsc,
  priceDesc,
  departmentAsc,
  departmentDesc,
}

extension StoreProductSortX on StoreProductSort {
  String get apiValue => switch (this) {
    StoreProductSort.az => 'AZ',
    StoreProductSort.za => 'ZA',
    StoreProductSort.priceAsc => 'PRECO_ASC',
    StoreProductSort.priceDesc => 'PRECO_DESC',
    StoreProductSort.departmentAsc => 'DEP_ASC',
    StoreProductSort.departmentDesc => 'DEP_DESC',
    _ => 'PADRAO',
  };
  String get label => switch (this) {
    StoreProductSort.az => 'A-Z',
    StoreProductSort.za => 'Z-A',
    StoreProductSort.priceAsc => 'Preço: menor → maior',
    StoreProductSort.priceDesc => 'Preço: maior → menor',
    StoreProductSort.departmentAsc => 'Departamento: A-Z',
    StoreProductSort.departmentDesc => 'Departamento: Z-A',
    _ => 'Padrão: ofertas e favoritos',
  };
}

class StoreSponsoredCampaign {
  const StoreSponsoredCampaign({
    required this.id,
    required this.name,
    required this.products,
    this.description,
    this.bannerUrl,
    this.sponsorName,
    this.sponsorLogoUrl,
    this.heroImageUrl,
    this.campaignUrl,
    this.skinId,
    this.source,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.borderColor,
    this.textColor,
    this.accentColor,
    this.visualAssets = const [],
    this.backgroundAssets = const [],
  });
  final String id;
  final String name;
  final String? description;
  final String? bannerUrl;
  final String? sponsorName;
  final String? sponsorLogoUrl;
  final String? heroImageUrl;
  final String? campaignUrl;
  final String? skinId;
  final String? source;
  final String? backgroundColor;
  final String? backgroundImageUrl;
  final String? borderColor;
  final String? textColor;
  final String? accentColor;
  final List<String> visualAssets;
  final List<String> backgroundAssets;
  final List<StoreProduct> products;

  factory StoreSponsoredCampaign.fromJson(
    Map<String, dynamic> json,
  ) => StoreSponsoredCampaign(
    id: _s(json['id'] ?? json['campaign_id'], ''),
    name: _s(json['name'] ?? json['nome'], 'Campanhas em destaque'),
    description: _nullable(json['description'] ?? json['descricao']),
    bannerUrl: _nullable(
      json['banner_url'] ?? json['imagem_url'] ?? json['banner'],
    ),
    sponsorName: _nullable(json['sponsor_name'] ?? json['patrocinador_nome']),
    sponsorLogoUrl: _nullable(
      json['sponsor_logo_url'] ?? json['patrocinador_logo_url'],
    ),
    heroImageUrl: _nullable(
      json['hero_image_url'] ??
          json['campaign_image_url'] ??
          json['imagem_principal'] ??
          json['banner_url'],
    ),
    campaignUrl: _nullable(json['campaign_url'] ?? json['url_campanha']),
    skinId: _nullable(json['skin_id']),
    source: _nullable(json['source']),
    backgroundColor: _nullable(json['background_color'] ?? json['cor_fundo']),
    backgroundImageUrl: _nullable(
      json['background_image_url'] ??
          json['background_url'] ??
          json['imagem_fundo'],
    ),
    borderColor: _nullable(json['border_color'] ?? json['cor_borda']),
    textColor: _nullable(json['text_color'] ?? json['cor_texto']),
    accentColor: _nullable(
      json['accent_color'] ?? json['cor_destaque'] ?? json['primary_color'],
    ),
    visualAssets: _stringList(
      json['visual_assets'] ?? json['asset_candidates'],
    ),
    backgroundAssets: _stringList(
      json['background_assets'] ?? json['wallpaper_assets'],
    ),
    products: _list(
      json['products'] ?? json['produtos'],
    ).map(StoreProduct.fromJson).toList(),
  );
}

class StoreHomeData {
  const StoreHomeData({
    required this.banners,
    required this.categories,
    required this.offers,
    required this.sponsored,
    required this.sponsoredCampaigns,
    required this.products,
  });
  final List<StoreBanner> banners;
  final List<StoreCategory> categories;
  final List<StoreProduct> offers;
  final List<StoreProduct> sponsored;
  final List<StoreSponsoredCampaign> sponsoredCampaigns;
  final List<StoreProduct> products;

  factory StoreHomeData.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']).isNotEmpty ? _map(json['data']) : json;
    return StoreHomeData(
      banners: _list(data['banners']).map(StoreBanner.fromJson).toList(),
      categories: _list(
        data['categories'] ?? data['categorias'],
      ).map(StoreCategory.fromJson).toList(),
      offers: _list(
        data['offers'] ?? data['ofertas'],
      ).map(StoreProduct.fromJson).toList(),
      sponsored: _list(
        data['sponsored'] ?? data['patrocinados'],
      ).map(StoreProduct.fromJson).toList(),
      sponsoredCampaigns: _list(
        data['sponsored_campaigns'] ?? data['campanhas_patrocinadas'],
      ).map(StoreSponsoredCampaign.fromJson).toList(),
      products: _list(
        data['products'] ?? data['produtos'] ?? data['featured'],
      ).map(StoreProduct.fromJson).toList(),
    );
  }
}

Map<String, dynamic> mapValue(dynamic value) => _map(value);
List<Map<String, dynamic>> listValue(dynamic value) => _list(value);

double numberValue(dynamic value, {double fallback = 0}) =>
    _d(value, fallback: fallback);
bool boolValue(dynamic value, {bool fallback = false}) => _b(value, fallback);
String stringValue(dynamic value, {String fallback = ''}) =>
    _s(value, fallback);
String? nullableString(dynamic value) => _nullable(value);

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  final out = <String>[];
  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isNotEmpty && !out.contains(text)) out.add(text);
  }
  return out;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map)
    return value.map((key, value) => MapEntry(key.toString(), value));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_map).where((e) => e.isNotEmpty).toList();
}

String _s(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _d(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  final text = value?.toString().replaceAll(',', '.').trim() ?? '';
  return double.tryParse(text) ?? fallback;
}

double? _nullableDouble(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return _d(value);
}

int _i(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _b(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim() ?? '';
  if (['1', 'true', 'sim', 's', 'yes'].contains(text)) return true;
  if (['0', 'false', 'nao', 'não', 'n', 'no'].contains(text)) return false;
  return fallback;
}
