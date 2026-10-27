import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Renders the HTML body of a post.
///
/// Post bodies use a small subset of HTML: paragraphs, line breaks, emphasis,
/// links, lists, quotes and the occasional image. Rendering that subset
/// directly keeps a full HTML engine out of the dependency tree; unknown
/// elements are rendered as their text content.
class PostBodyView extends StatefulWidget {
  const PostBodyView({
    super.key,
    required this.content,
    this.onOpenLink,
    this.resolveUrl,
  });

  /// HTML body of the post.
  final String content;

  /// Called when a link or an image is tapped. Nothing is tappable when null.
  final ValueChanged<Uri>? onOpenLink;

  /// Turns relative URLs in [content] into absolute ones.
  final String Function(String url)? resolveUrl;

  @override
  State<PostBodyView> createState() => _PostBodyViewState();
}

class _PostBodyViewState extends State<PostBodyView> {
  /// Vertical space between two blocks.
  static const double _blockGap = 10;

  /// Width reserved for a list marker, including the space after it.
  static const double _markerWidth = 28;

  /// Maximum height of an image embedded in the body.
  static const double _maxImageHeight = 320;

  static const String _mono = 'monospace';

  /// Elements whose content is never shown.
  static const Set<String> _ignoredTags = {
    'script',
    'style',
    'noscript',
    'head',
    'title',
    'meta',
    'link',
    'iframe',
    'object',
    'embed',
    'svg',
    'canvas',
    'video',
    'audio',
    'source',
  };

  /// Collapses the whitespace runs that HTML treats as a single space.
  static final RegExp _whitespace = RegExp(r'[ \t\r\n\f\v\u00a0]+');
  static final RegExp _leadingWhitespace = RegExp(r'^[ \t\r\n\f\v\u00a0]+');
  static final RegExp _trailingWhitespace = RegExp(r'[ \t\r\n\f\v\u00a0]+$');

  /// Recognizers created for links, disposed with the widget. They are kept for
  /// the widget's lifetime because the spans that hold them are rebuilt per
  /// frame.
  final List<TapGestureRecognizer> _recognizers = [];

  late dom.DocumentFragment _fragment;

  @override
  void initState() {
    super.initState();
    _fragment = html_parser.parseFragment(widget.content);
  }

  @override
  void didUpdateWidget(PostBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _fragment = html_parser.parseFragment(widget.content);
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TextStyle get _bodyStyle {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks(_fragment.nodes);
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  // ---------------------------------------------------------------------------
  // Block level
  // ---------------------------------------------------------------------------

  List<Widget> _blocks(
    List<dom.Node> nodes, {
    TextStyle? style,
    double indent = 0,
  }) {
    final baseStyle = style ?? _bodyStyle;
    final widgets = <Widget>[];
    var inline = <dom.Node>[];

    void flush() {
      if (inline.isEmpty) return;
      final block = _textBlock(inline, style: baseStyle, indent: indent);
      inline = <dom.Node>[];
      if (block != null) widgets.add(block);
    }

    for (final node in nodes) {
      if (node is! dom.Element) {
        // Text and comments join the current paragraph.
        if (node is dom.Text) inline.add(node);
        continue;
      }

      final tag = node.localName ?? '';
      if (_ignoredTags.contains(tag)) continue;

      switch (tag) {
        case 'br' || 'img':
          inline.add(node);

        case 'p' || 'figure' || 'figcaption' || 'address' || 'li':
          flush();
          final block = _textBlock(
            node.nodes,
            style: baseStyle,
            indent: indent,
          );
          if (block != null) {
            widgets.add(block);
          } else {
            widgets.addAll(
              _blocks(node.nodes, style: baseStyle, indent: indent),
            );
          }

        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          flush();
          widgets.add(_heading(node, indent: indent));

        case 'blockquote':
          flush();
          final quoteStyle = baseStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
          widgets.add(
            Padding(
              padding: EdgeInsets.only(left: indent, bottom: _blockGap),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _blocks(node.nodes, style: quoteStyle),
                ),
              ),
            ),
          );

        case 'ul' || 'ol':
          flush();
          widgets.add(
            _list(node, style: baseStyle, indent: indent, ordered: tag == 'ol'),
          );

        case 'pre':
          flush();
          widgets.add(_preformatted(node, indent: indent));

        case 'table':
          flush();
          widgets.add(_table(node, style: baseStyle, indent: indent));

        case 'hr':
          flush();
          widgets.add(
            Padding(
              padding: EdgeInsets.only(left: indent, bottom: _blockGap),
              child: const Divider(height: 1),
            ),
          );

        // Containers without their own spacing: flatten the children so nested
        // divs do not multiply the gaps between blocks.
        case 'div' ||
            'section' ||
            'article' ||
            'header' ||
            'footer' ||
            'main' ||
            'aside' ||
            'nav' ||
            'center' ||
            'body':
          flush();
          widgets.addAll(_blocks(node.nodes, style: baseStyle, indent: indent));

        default:
          inline.add(node);
      }
    }

    flush();
    return widgets;
  }

  Widget? _textBlock(
    List<dom.Node> nodes, {
    required TextStyle style,
    double indent = 0,
  }) {
    final span = _inline(nodes, style: style);
    if (span == null) return null;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: _blockGap),
      child: Text.rich(span, style: style),
    );
  }

  Widget _heading(dom.Element element, {double indent = 0}) {
    final theme = Theme.of(context);
    final level = int.tryParse((element.localName ?? 'h3').substring(1)) ?? 3;
    final size = switch (level) {
      1 => 26.0,
      2 => 22.0,
      3 => 19.0,
      4 => 17.0,
      5 => 15.5,
      _ => 14.5,
    };
    final style = theme.textTheme.titleMedium!.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      height: 1.3,
    );
    final span = _inline(element.nodes, style: style);
    if (span == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 6, bottom: 8),
      child: Text.rich(span, style: style),
    );
  }

  Widget _list(
    dom.Element element, {
    required TextStyle style,
    required bool ordered,
    double indent = 0,
  }) {
    var index = int.tryParse(element.attributes['start'] ?? '') ?? 1;
    final rows = <Widget>[];

    for (final node in element.nodes) {
      if (node is dom.Text) {
        if (node.text.trim().isEmpty) continue;
        final block = _textBlock([node], style: style);
        if (block != null) rows.add(block);
        continue;
      }
      if (node is! dom.Element) continue;

      if (node.localName == 'li') {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _markerWidth,
                child: Text(
                  ordered ? '${index++}.' : '•',
                  style: style,
                  textAlign: ordered ? TextAlign.right : TextAlign.left,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _blocks(node.nodes, style: style),
                ),
              ),
            ],
          ),
        );
      } else {
        rows.addAll(_blocks([node], style: style, indent: _markerWidth));
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: _blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _preformatted(dom.Element element, {double indent = 0}) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall!.copyWith(
      fontFamily: _mono,
      color: theme.colorScheme.onSurface,
      height: 1.4,
    );
    final text = element.text.replaceFirst(RegExp('^\n'), '').trimRight();
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: _blockGap),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(text, style: style, softWrap: false),
        ),
      ),
    );
  }

  Widget _table(
    dom.Element element, {
    required TextStyle style,
    double indent = 0,
  }) {
    final rows = element.querySelectorAll('tr');
    final widgets = <Widget>[];

    for (final row in rows) {
      final cells = row.children
          .where((cell) => cell.localName == 'td' || cell.localName == 'th')
          .toList();
      if (cells.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in cells)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _cell(
                      cell,
                      style: cell.localName == 'th'
                          ? style.copyWith(fontWeight: FontWeight.w700)
                          : style,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return _textBlock(element.nodes, style: style, indent: indent) ??
          const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: _blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _cell(dom.Element cell, {required TextStyle style}) {
    final span = _inline(cell.nodes, style: style);
    if (span == null) return const SizedBox.shrink();
    return Text.rich(span, style: style);
  }

  // ---------------------------------------------------------------------------
  // Inline level
  // ---------------------------------------------------------------------------

  InlineSpan? _inline(List<dom.Node> nodes, {required TextStyle style}) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      final span = _inlineNode(node, style: style);
      if (span != null) spans.add(span);
    }
    _trim(spans);
    if (spans.isEmpty) return null;
    return TextSpan(style: style, children: spans);
  }

  InlineSpan? _inlineNode(dom.Node node, {required TextStyle style}) {
    if (node is dom.Text) {
      final text = node.text.replaceAll(_whitespace, ' ');
      if (text.isEmpty) return null;
      return TextSpan(text: text);
    }
    if (node is! dom.Element) return null;

    final tag = node.localName ?? '';
    if (_ignoredTags.contains(tag)) return null;

    switch (tag) {
      case 'br':
        return const TextSpan(text: '\n');

      case 'img':
        return _imageSpan(node);

      case 'strong' || 'b':
        return _styled(node, style.copyWith(fontWeight: FontWeight.w700));

      case 'em' || 'i' || 'cite' || 'var':
        return _styled(node, style.copyWith(fontStyle: FontStyle.italic));

      case 'u' || 'ins':
        return _styled(
          node,
          style.copyWith(decoration: TextDecoration.underline),
        );

      case 's' || 'strike' || 'del':
        return _styled(
          node,
          style.copyWith(decoration: TextDecoration.lineThrough),
        );

      case 'mark':
        return _styled(
          node,
          style.copyWith(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.25),
          ),
        );

      case 'code' || 'kbd' || 'samp' || 'tt':
        return _styled(
          node,
          style.copyWith(
            fontFamily: _mono,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        );

      case 'a':
        return _linkSpan(node, style: style);

      case 'span' || 'small' || 'big' || 'font' || 'label' || 'time' || 'abbr':
        return _styled(node, style);

      default:
        // Unknown elements keep their text, without their blocks.
        return _styled(node, style);
    }
  }

  InlineSpan? _styled(dom.Element element, TextStyle style) {
    return _inline(element.nodes, style: style);
  }

  InlineSpan? _linkSpan(dom.Element element, {required TextStyle style}) {
    final theme = Theme.of(context);
    final linkStyle = style.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );
    final span = _inline(element.nodes, style: linkStyle);
    if (span == null) return null;

    final href = element.attributes['href'];
    final onOpenLink = widget.onOpenLink;
    final uri = href == null ? null : Uri.tryParse(_resolve(href));
    if (uri == null || onOpenLink == null) return span;

    final recognizer = TapGestureRecognizer()..onTap = () => onOpenLink(uri);
    _recognizers.add(recognizer);
    return _attachRecognizer(span, recognizer);
  }

  /// Attaches [recognizer] to every text span of [span], so links containing
  /// styled text are tappable as a whole.
  InlineSpan _attachRecognizer(InlineSpan span, GestureRecognizer recognizer) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: span.style,
      recognizer: span.text == null ? null : (span.recognizer ?? recognizer),
      mouseCursor: span.text == null ? null : SystemMouseCursors.click,
      children: span.children
          ?.map((child) => _attachRecognizer(child, recognizer))
          .toList(),
    );
  }

  InlineSpan? _imageSpan(dom.Element element) {
    final raw =
        element.attributes['src'] ?? element.attributes['data-src'] ?? '';
    if (raw.trim().isEmpty) return null;

    final url = _resolve(raw);
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final alt = element.attributes['alt']?.trim();
    Widget image = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxImageHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 220,
              height: 120,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _BrokenBodyImage(label: alt),
        ),
      ),
    );

    final onOpenLink = widget.onOpenLink;
    if (onOpenLink != null) {
      image = GestureDetector(
        onTap: () => onOpenLink(uri),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: image),
      );
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: image,
      ),
    );
  }

  String _resolve(String url) {
    final resolve = widget.resolveUrl;
    return resolve == null ? url : resolve(url);
  }

  /// Removes the whitespace that HTML adds around blocks.
  void _trim(List<InlineSpan> spans) {
    while (spans.isNotEmpty) {
      final first = spans.first;
      if (first is! TextSpan || first.text == null) break;
      final text = first.text!;
      final trimmed = text.replaceFirst(_leadingWhitespace, '');
      if (trimmed.isEmpty) {
        spans.removeAt(0);
        continue;
      }
      if (trimmed != text) {
        spans[0] = TextSpan(
          text: trimmed,
          style: first.style,
          recognizer: first.recognizer,
          mouseCursor: first.mouseCursor,
          children: first.children,
        );
      }
      break;
    }

    while (spans.isNotEmpty) {
      final last = spans.last;
      if (last is! TextSpan || last.text == null) break;
      final text = last.text!;
      final trimmed = text.replaceFirst(_trailingWhitespace, '');
      if (trimmed.isEmpty) {
        spans.removeLast();
        continue;
      }
      if (trimmed != text) {
        spans[spans.length - 1] = TextSpan(
          text: trimmed,
          style: last.style,
          recognizer: last.recognizer,
          mouseCursor: last.mouseCursor,
          children: last.children,
        );
      }
      break;
    }
  }
}

/// Placeholder for an image of the body that could not be loaded.
class _BrokenBodyImage extends StatelessWidget {
  const _BrokenBodyImage({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              label == null || label!.isEmpty
                  ? 'Image could not be loaded'
                  : label!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
