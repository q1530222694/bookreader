import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 搜索引擎枚举：多引擎支持，用户可在 UI 上选择。
///
/// - [baidu]：百度图片（移动端 wisesearchresult 接口，效果最好，书籍封面匹配度最高）。
/// - [bing]：微软 Bing 图片搜索（cn.bing.com，效果一般，对中文书籍封面识别度低）。
/// - [google]：Google 图片搜索（未实现：Google 全面拦截非浏览器请求，无 API Key 不可用）。
enum ImageSearchEngine {
  baidu,
  bing,
  google;

  /// 从 Settings/UI 状态值反序列化（未知值兜底为 baidu）。
  static ImageSearchEngine fromName(String? name) {
    switch (name) {
      case 'bing':
        return ImageSearchEngine.bing;
      case 'google':
        return ImageSearchEngine.google;
      case 'baidu':
      default:
        return ImageSearchEngine.baidu;
    }
  }
}

/// 网络图片搜索服务（纯逻辑，无 UI 依赖，可独立复用）。
///
/// 为「修改封面 - 网络图片搜索」来源提供多引擎支持：
/// - [search]：按关键词 + 引擎调用对应后端，返回图片地址列表。
/// - [downloadImage]：按图片地址下载字节，供替换封面落盘。
///
/// **设计要点**：
/// - **百度移动端最佳**：`m.baidu.com/sf/vsearch/image/search/wisesearchresult` 移动端接口
///   对中文书籍封面识别度极高（如搜"人生财富靠康波"直接返回当当网/抖音/京东的书籍封面），
///   而桌面 `image.baidu.com/search/acjson` 已被全面反爬封禁。
/// - **Bing 兜底**：HTML 解析（`murl&quot;:&quot;URL`）实现，对部分中文书名匹配度较差。
/// - **Google 未实现**：Google 图片搜索对非浏览器返回空响应（需 JS 执行），需 API Key 才能接入。
/// - **强制直连**：`HttpClient.findProxy = (_) => 'DIRECT'` 绕过本机代理。
/// - **稳健不崩溃**：网络/解析失败一律返回空列表或 null，由 UI 提示。
class BaiduImageSearchService {
  BaiduImageSearchService._();

  /// 默认返回图片数量上限。
  static const int _defaultCount = 30;

  /// Chrome 浏览器 UA：用于 Bing/通用下载。
  static const String _userAgentChrome =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Safari 移动端 UA：用于百度移动端接口（移动端验证较宽松）。
  static const String _userAgentMobileSafari =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';

  /// 按关键词 + 引擎搜索图片，返回图片地址列表（最多 [count] 张）。
  ///
  /// - Baidu 引擎：直接用书名搜索，匹配度最高（无需加"书籍封面"后缀，会过滤相关书籍）。
  /// - Bing 引擎：自动追加"书籍封面"后缀以提升相关性（对部分书名提升 2-3x）。
  /// - Google 引擎：未实现，返回空列表（UI 提示"暂不可用"）。
  static Future<List<String>> search(
    String keyword, {
    int count = _defaultCount,
    ImageSearchEngine engine = ImageSearchEngine.baidu,
  }) async {
    switch (engine) {
      case ImageSearchEngine.baidu:
        return _searchBaidu(keyword, count);
      case ImageSearchEngine.bing:
        // Bing 中文搜索对纯书名匹配度差，追加"书籍封面"后缀。
        return _searchBing('$keyword 书籍封面', count);
      case ImageSearchEngine.google:
        // Google 图片搜索对非浏览器返回空响应/需 JS 执行；此处返回空由 UI 提示。
        return const [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Baidu 移动端（wisesearchresult）
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<String>> _searchBaidu(String keyword, int count) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];

    HttpClient? client;
    try {
      final uri = Uri.https(
        'm.baidu.com',
        '/sf/vsearch/image/search/wisesearchresult',
        {
          'word': query,
          't': 'wise',
          // pn/rn 翻页与单页条数（不显式传时默认首页 30 条）。
        },
      );
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 12);

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgentMobileSafari);
      request.headers.set('Accept', 'application/json, text/plain, */*');
      request.headers.set('Accept-Language', 'zh-CN,zh;q=0.9');
      request.headers.set('Referer', 'https://m.baidu.com/');

      final response = await request.close();
      if (response.statusCode != 200) return const [];

      final bytes = await _readAll(response);
      final text = utf8.decode(bytes, allowMalformed: true);
      return _parseBaiduObjurls(text).take(count).toList();
    } catch (_) {
      return const [];
    } finally {
      client?.close(force: true);
    }
  }

  /// 从百度移动端 JSON 响应中提取图片原始地址。
  ///
  /// 响应 JSON 结构：`{"linkData": [{"objurl": "...", "thumbnailUrl": "...", "title": "...", ...}, ...], ...}`
  /// - 优先取 `objurl`（原图，可直接下载）；
  /// - 兜底取 `thumbnailUrl`（百度自有 CDN，可靠性高）。
  /// 解析失败/JSON 异常返回空列表（不抛错）。
  static List<String> _parseBaiduObjurls(String jsonText) {
    final seen = <String>{};
    final urls = <String>[];

    Map<String, dynamic> root;
    try {
      root = json.decode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return const [];
    }

    final linkData = root['linkData'];
    if (linkData is! List) return const [];

    for (final item in linkData) {
      if (item is! Map) continue;
      // 优先 objurl，降级 thumbnailUrl。
      final candidates = <String?>[
        item['objurl'] as String?,
        item['thumbnailUrl'] as String?,
      ];
      for (final c in candidates) {
        if (c == null || c.isEmpty) continue;
        // 过滤 gimg2.baidu.com 转发壳（部分 objurl 需经过此壳跳转，但当前端不总是能下载成功）。
        // 不在这里过滤——thumbnailUrl 通常是 baidu.com 自有 CDN，可下。
        if (!c.startsWith('http')) continue;
        if (seen.add(c)) {
          urls.add(c);
          break; // 已取到一个，跳到下一条
        }
      }
    }
    return urls;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bing（HTML 解析）
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<String>> _searchBing(String keyword, int count) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];

    HttpClient? client;
    try {
      final uri = Uri.https(
        'cn.bing.com',
        '/images/search',
        {
          'q': query,
          'first': '1',
          'qft': '',
        },
      );
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 12);

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgentChrome);
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
      request.headers.set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');

      final response = await request.close();
      if (response.statusCode != 200) return const [];

      final bytes = await _readAll(response);
      final text = utf8.decode(bytes, allowMalformed: true);
      return _parseBingMurls(text).take(count).toList();
    } catch (_) {
      return const [];
    } finally {
      client?.close(force: true);
    }
  }

  /// 从 Bing 搜索结果 HTML 中提取图片原始地址（`murl`）。
  static List<String> _parseBingMurls(String html) {
    final seen = <String>{};
    final urls = <String>[];

    final regex = RegExp(r'murl&quot;:&quot;([^&]+)');
    for (final match in regex.allMatches(html)) {
      var raw = match.group(1);
      if (raw == null || raw.isEmpty || raw == 'null') continue;

      var url = raw
          .replaceAll(r'\/', '/')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '');

      if (url.isEmpty || url == 'null' || !url.startsWith('http')) continue;
      if (url.contains('/th?id=')) continue;

      if (seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 下载
  // ─────────────────────────────────────────────────────────────────────────

  /// 下载图片字节（用于把选中的网络封面保存到本地）。
  ///
  /// 自动识别来源域名设置对应 Referer：百度图片 CDN 需 m.baidu.com Referer，
  /// 其余通用。失败返回 null（地址失效 / 被拦截 / 跨域限制），由 UI 提示而非崩溃。
  static Future<Uint8List?> downloadImage(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 15);
      // dart:io 的 HttpClient 默认跟随最多 5 次重定向，覆盖百度 CDN/图床等跳转链。

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', _userAgentMobileSafari);
      // 根据来源设置 Referer：百度图床需 m.baidu.com；其他按 host 推断。
      final referer = _refererForHost(uri.host);
      if (referer != null) request.headers.set('Referer', referer);

      final response = await request.close();
      if (response.statusCode != 200) return null;

      // Content-Type 必须是图片才返回（避免被 200 错误页面或 HTML 误导）。
      final ct = response.headers.value('content-type')?.toLowerCase() ?? '';
      if (!ct.startsWith('image/')) return null;

      return await _readAll(response);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// 根据 host 推断 Referer，覆盖主要 CDN/电商图床。
  static String? _refererForHost(String host) {
    if (host.contains('baidu.com')) return 'https://m.baidu.com/';
    if (host.contains('360buyimg.com')) return 'https://item.jd.com/';
    if (host.contains('alicdn.com')) return 'https://item.taobao.com/';
    if (host.contains('douyinpic.com') || host.contains('douyin.com')) {
      return 'https://www.douyin.com/';
    }
    if (host.contains('canva.cn')) return 'https://www.canva.cn/';
    if (host.contains('cn.bing.com')) return 'https://cn.bing.com/';
    return null; // 其它源不设 Referer，让服务端走默认策略。
  }

  /// 读取响应流的全部字节。
  static Future<Uint8List> _readAll(Stream<List<int>> stream) async {
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
