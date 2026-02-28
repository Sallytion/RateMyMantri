/// Represents one entry in the `sections` array from GET /api/home/sections.
class HomeSection {
  final String id;
  final String type;
  final bool visible;
  final int order;
  final String title;
  final String icon;
  final String? bannerImageUrl;
  final String? webviewUrl;
  final String? webviewTitle;

  const HomeSection({
    required this.id,
    required this.type,
    required this.visible,
    required this.order,
    required this.title,
    required this.icon,
    this.bannerImageUrl,
    this.webviewUrl,
    this.webviewTitle,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      visible: json['visible'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      bannerImageUrl: json['banner_image_url'] as String?,
      webviewUrl: json['webview_url'] as String?,
      webviewTitle: json['webview_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'visible': visible,
        'order': order,
        'title': title,
        'icon': icon,
        if (bannerImageUrl != null) 'banner_image_url': bannerImageUrl,
        if (webviewUrl != null) 'webview_url': webviewUrl,
        if (webviewTitle != null) 'webview_title': webviewTitle,
      };

  /// Whether this section has all the fields required for `webview_banner` type.
  bool get isComplete =>
      id.isNotEmpty &&
      type.isNotEmpty &&
      title.isNotEmpty &&
      (type != 'webview_banner' ||
          (bannerImageUrl != null &&
              bannerImageUrl!.isNotEmpty &&
              webviewUrl != null &&
              webviewUrl!.isNotEmpty &&
              webviewTitle != null &&
              webviewTitle!.isNotEmpty));
}
