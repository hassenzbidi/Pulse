import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class DiscussionScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherName;
  final String otherRole; // 'doctor' | 'patient'

  const DiscussionScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherName,
    required this.otherRole,
  });

  @override
  State<DiscussionScreen> createState() =>
      _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  List   _messages  = [];
  bool   _isLoading = true;
  bool   _isSending = false;
  Timer? _timer;

  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker     = ImagePicker();

  String get _roleLabel {
    switch (widget.otherRole.toLowerCase()) {
      case 'doctor':  return 'Médecin';
      case 'patient': return 'Patient';
      default:        return widget.otherRole;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages(initial: true);
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool initial = false}) async {
    try {
      final res = await ApiClient.dio.get(
        '/chat/${widget.currentUserId}/${widget.otherUserId}',
      );
      final msgs = res.data['messages'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _messages  = msgs;
        _isLoading = false;
      });
      _scrollToBottom(force: initial);
      _markRead();
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _markRead() async {
    try {
      await ApiClient.dio.patch(
        '/chat/read/${widget.otherUserId}/${widget.currentUserId}',
      );
    } catch (_) {}
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (force || pos.pixels >= pos.maxScrollExtent - 80) {
        _scrollCtrl.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() { _isSending = true; });
    _msgCtrl.clear();
    try {
      await ApiClient.dio.post('/chat/send', data: {
        'sender_id':   widget.currentUserId,
        'receiver_id': widget.otherUserId,
        'content':     text,
      });
      await _loadMessages(initial: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'envoi : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _isSending = false; });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primary),
              ),
              title: const Text('Caméra',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                )),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primary),
              ),
              title: const Text('Galerie',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                )),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source:       source,
        imageQuality: 70,
        maxWidth:     800,
      );
      if (file == null) return;

      final bytes        = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() { _isSending = true; });
      try {
        await ApiClient.dio.post('/chat/send', data: {
          'sender_id':    widget.currentUserId,
          'receiver_id':  widget.otherUserId,
          'content':      '',
          'message_type': 'image',
          'image_base64': base64String,
        });
        await _loadMessages(initial: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur d\'envoi : $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() { _isSending = false; });
      }
    } catch (_) {
      // Annulé ou permission refusée
    }
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.otherName.isNotEmpty
        ? widget.otherName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _roleLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                size: 40, color: AppTheme.textGray),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun message pour l\'instant.',
              style: TextStyle(
                color: AppTheme.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Commencez la conversation !',
              style: TextStyle(
                color: AppTheme.textGray,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(Map msg) {
    final bool isMine = msg['sender_id']?.toString()
        == widget.currentUserId.toString();
    final isImage = msg['message_type'] == 'image';
    final content = msg['content']?.toString() ?? '';
    final time    = _formatTime(
        msg['created_at']?.toString() ?? '');
    final isRead  = msg['is_read'] == true;

    final timeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: isMine
                ? Colors.white.withOpacity(0.75)
                : AppTheme.textGray,
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 12,
            color: isRead
                ? Colors.white
                : Colors.white.withOpacity(0.65),
          ),
        ],
      ],
    );

    Widget bubbleContent;
    if (isImage) {
      final raw = msg['image_base64']?.toString() ?? '';
      Widget imageWidget;
      if (raw.isNotEmpty) {
        try {
          imageWidget = Image.memory(
            base64Decode(raw),
            width: 200, height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _brokenImage(),
          );
        } catch (_) {
          imageWidget = _brokenImage();
        }
      } else {
        imageWidget = _brokenImage();
      }
      bubbleContent = Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget,
          ),
          const SizedBox(height: 4),
          timeRow,
        ],
      );
    } else {
      bubbleContent = Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isMine ? Colors.white : Colors.black,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 3),
          timeRow,
        ],
      );
    }

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2, bottom: 2,
          left:  isMine ? 72 : 0,
          right: isMine ? 0 : 72,
        ),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: bubbleContent,
      ),
    );
  }

  Widget _brokenImage() => Container(
    width: 200, height: 150,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.broken_image,
      color: Colors.grey, size: 40),
  );

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 16),
      color: const Color(0xFFF0F2F5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton image
          IconButton(
            onPressed: _isSending ? null : _showImageSourceSheet,
            icon: const Icon(Icons.image_outlined),
            color: AppTheme.textGray,
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 12),
            constraints: const BoxConstraints(),
          ),
          // TextField
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton envoyer
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
