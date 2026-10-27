import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/external_links.dart';
import '../../../../../core/kemono_server.dart';
import '../../../../../data/models/post.dart';
import 'post_body_view.dart';

/// Shows the details of [post] as a dialog.
///
/// Post listings usually omit the body, so [loadDetails] is called to fetch the
/// full post when it is missing.
///
/// [openUrl] is injectable for tests; by default the post is opened in the
/// platform browser.
Future<void> showPostDetails(
  BuildContext context, {
  required Post post,
  required KemonoServer server,
  UrlOpener openUrl = openExternalUrl,
  Future<Post?> Function()? loadDetails,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PostDetailsDialog(
      post: post,
      server: server,
      openUrl: openUrl,
      loadDetails: loadDetails,
    ),
  );
}

/// Dialog showing the full title and the rendered body of a post, with a
/// button that opens the post on the server's website.
class PostDetailsDialog extends StatefulWidget {
  const PostDetailsDialog({
    super.key,
    required this.post,
    required this.server,
    this.openUrl = openExternalUrl,
    this.loadDetails,
  });

  final Post post;
  final KemonoServer server;
  final UrlOpener openUrl;

  /// Fetches the full post, used when [post] has no body.
  final Future<Post?> Function()? loadDetails;

  @override
  State<PostDetailsDialog> createState() => _PostDetailsDialogState();
}

class _PostDetailsDialogState extends State<PostDetailsDialog> {
  Post? _loaded;
  bool _isLoading = false;
  bool _failed = false;

  Post get _post => _loaded ?? widget.post;

  @override
  void initState() {
    super.initState();
    if (_body(_post).isEmpty) unawaited(_load());
  }

  static String _body(Post post) => post.content?.trim() ?? '';

  Future<void> _load() async {
    final loadDetails = widget.loadDetails;
    if (loadDetails == null) return;

    setState(() {
      _isLoading = true;
      _failed = false;
    });

    Post? post;
    var failed = false;
    try {
      post = await loadDetails();
      failed = post == null;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;

    setState(() {
      _loaded = post;
      _isLoading = false;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = _post;
    final title = post.title?.trim() ?? '';
    final content = _body(post);
    final postUrl = widget.server.postUrl(
      postId: post.id,
      service: post.service,
      creatorId: post.user,
    );

    final metaParts = <String>[
      if (post.service != null && post.service!.isNotEmpty) post.service!,
      if (post.user != null && post.user!.isNotEmpty) post.user!,
      if (post.publishedDate != null) _formatDate(post.publishedDate!),
    ];

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.isEmpty ? 'Untitled post' : title),
          if (metaParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              metaParts.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _buildContent(context, content),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: postUrl == null
              ? null
              : () => unawaited(_openPost(context, postUrl)),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open post'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, String content) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Loading post…', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load the post body.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => unawaited(_load()),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    if (content.isEmpty) {
      return Text(
        'This post has no text.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return PostBodyView(
      content: content,
      resolveUrl: widget.server.resolveBodyUrl,
      onOpenLink: (uri) => unawaited(widget.openUrl(uri)),
    );
  }

  Future<void> _openPost(BuildContext context, Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await widget.openUrl(url);
    if (opened) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the post in the browser.')),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
