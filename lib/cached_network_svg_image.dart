library cached_network_svg_image;

import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedNetworkSVGImage extends StatefulWidget {
  CachedNetworkSVGImage(
    String url, {
    Key? key,
    String? cacheKey,
    Widget? placeholder,
    Widget? errorWidget,
    double? width,
    double? height,
    Map<String, String>? headers,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool matchTextDirection = false,
    bool allowDrawingOutsideViewBox = false,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    SvgTheme theme = const SvgTheme(),
    Duration fadeDuration = const Duration(milliseconds: 300),
    ColorFilter? colorFilter,
    ColorMapper? colorMapper,
    WidgetBuilder? placeholderBuilder,
    BaseCacheManager? cacheManager,
  })  : _url = url,
        _cacheKey = cacheKey,
        _placeholder = placeholder,
        _errorWidget = errorWidget,
        _width = width,
        _height = height,
        _headers = headers,
        _fit = fit,
        _alignment = alignment,
        _matchTextDirection = matchTextDirection,
        _allowDrawingOutsideViewBox = allowDrawingOutsideViewBox,
        _semanticsLabel = semanticsLabel,
        _excludeFromSemantics = excludeFromSemantics,
        _theme = theme,
        _fadeDuration = fadeDuration,
        _colorFilter = colorFilter,
        _placeholderBuilder = placeholderBuilder,
        _cacheManager = cacheManager ?? DefaultCacheManager(),
        _colorMapper = colorMapper,
        super(key: key ?? ValueKey(url));

  final String _url;
  final String? _cacheKey;
  final Widget? _placeholder;
  final Widget? _errorWidget;
  final double? _width;
  final double? _height;
  final Map<String, String>? _headers;
  final BoxFit _fit;
  final AlignmentGeometry _alignment;
  final bool _matchTextDirection;
  final bool _allowDrawingOutsideViewBox;
  final String? _semanticsLabel;
  final bool _excludeFromSemantics;
  final SvgTheme _theme;
  final Duration _fadeDuration;
  final ColorFilter? _colorFilter;
  final WidgetBuilder? _placeholderBuilder;
  final BaseCacheManager _cacheManager;
  final ColorMapper? _colorMapper;
  @override
  State<CachedNetworkSVGImage> createState() => _CachedNetworkSVGImageState();

  static Future<void> preCache(
    String imageUrl, {
    String? cacheKey,
    BaseCacheManager? cacheManager,
  }) {
    final key = cacheKey ?? _generateKeyFromUrl(imageUrl);
    cacheManager ??= DefaultCacheManager();
    return cacheManager.downloadFile(key);
  }

  static Future<void> clearCacheForUrl(
    String imageUrl, {
    String? cacheKey,
    BaseCacheManager? cacheManager,
  }) {
    final key = cacheKey ?? _generateKeyFromUrl(imageUrl);
    cacheManager ??= DefaultCacheManager();
    return cacheManager.removeFile(key);
  }

  static Future<void> clearCache({BaseCacheManager? cacheManager}) {
    cacheManager ??= DefaultCacheManager();
    return cacheManager.emptyCache();
  }

  static String _generateKeyFromUrl(String url) => url.split('?').first;
}

class _CachedNetworkSVGImageState extends State<CachedNetworkSVGImage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isError = false;
  File? _imageFile;
  late String _cacheKey;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  Future<void>? _loadImageFuture;

  @override
  void initState() {
    super.initState();
    _cacheKey = widget._cacheKey ??
        CachedNetworkSVGImage._generateKeyFromUrl(widget._url);
    _controller = AnimationController(
      vsync: this,
      duration: widget._fadeDuration,
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);
    _loadImageFuture = _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _setToLoadingAfter15MsIfNeeded();

      FileInfo? fileInfo =
          await widget._cacheManager.getFileFromMemory(_cacheKey);

      if (fileInfo?.file == null || !(await fileInfo!.file.exists())) {
        final file = await widget._cacheManager.getSingleFile(
          widget._url,
          key: _cacheKey,
          headers: widget._headers ?? {},
        );
        fileInfo = FileInfo(
          file,
          FileSource.Online,
          DateTime.now(),
          _cacheKey,
        );
      }

      if (!mounted) return;

      _imageFile = fileInfo.file;
      _isLoading = false;

      _setState();
      _controller.forward();
    } catch (e, stackTrace) {
      log(
        'CachedNetworkSVGImage 로딩 실패',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      _isError = true;
      _isLoading = false;
      _setState();
    }
  }

  void _setToLoadingAfter15MsIfNeeded() => Future.delayed(
        const Duration(milliseconds: 15),
        () {
          if (!_isLoading && _imageFile == null && !_isError) {
            _isLoading = true;
            _setState();
          }
        },
      );

  void _setState() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _loadImageFuture?.ignore();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget._width,
      height: widget._height,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (_isLoading) return _buildPlaceholderWidget();

    if (_isError) return _buildErrorWidget();

    return FadeTransition(
      opacity: _animation,
      child: _buildSVGImage(),
    );
  }

  Widget _buildPlaceholderWidget() =>
      Center(child: widget._placeholder ?? const SizedBox());

  Widget _buildErrorWidget() =>
      Center(child: widget._errorWidget ?? const SizedBox());

  Widget _buildSVGImage() {
    if (_imageFile == null) return const SizedBox();

    return SvgPicture(
      SvgFileLoader(
        _imageFile!,
        theme: widget._theme,
        colorMapper: widget._colorMapper,
      ),
      fit: widget._fit,
      width: widget._width,
      height: widget._height,
      alignment: widget._alignment,
      matchTextDirection: widget._matchTextDirection,
      allowDrawingOutsideViewBox: widget._allowDrawingOutsideViewBox,
      semanticsLabel: widget._semanticsLabel,
      excludeFromSemantics: widget._excludeFromSemantics,
      colorFilter: widget._colorFilter,
      placeholderBuilder: widget._placeholderBuilder,
    );
  }
}
