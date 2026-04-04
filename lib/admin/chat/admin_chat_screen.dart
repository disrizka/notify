import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// ─────────────────────────────────────────────
// Helper: deteksi tipe file dari path/ekstensi
// ─────────────────────────────────────────────
enum FileKind { image, video, audio, pdf, doc, spreadsheet, other }

FileKind detectFileKind(String? path) {
  if (path == null || path.isEmpty) return FileKind.other;
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext))
    return FileKind.image;
  if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext))
    return FileKind.video;
  if (['mp3', 'aac', 'wav', 'ogg', 'm4a', 'opus'].contains(ext))
    return FileKind.audio;
  if (ext == 'pdf') return FileKind.pdf;
  if (['doc', 'docx'].contains(ext)) return FileKind.doc;
  if (['xls', 'xlsx', 'csv'].contains(ext)) return FileKind.spreadsheet;
  return FileKind.other;
}

IconData fileIcon(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return Icons.picture_as_pdf_rounded;
    case FileKind.doc:
      return Icons.description_rounded;
    case FileKind.spreadsheet:
      return Icons.table_chart_rounded;
    case FileKind.audio:
      return Icons.audio_file_rounded;
    case FileKind.video:
      return Icons.video_file_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color fileColor(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return const Color(0xFFE53935);
    case FileKind.doc:
      return const Color(0xFF1565C0);
    case FileKind.spreadsheet:
      return const Color(0xFF2E7D32);
    case FileKind.audio:
      return const Color(0xFF6A1B9A);
    case FileKind.video:
      return const Color(0xFFE65100);
    default:
      return const Color(0xFF546E7A);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Fullscreen Image Viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            tooltip: 'Buka di browser',
            onPressed: () async {
              final uri = Uri.parse(imageUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder:
                (_, child, progress) =>
                    progress == null
                        ? child
                        : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
            errorBuilder:
                (_, __, ___) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey,
                      size: 64,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Gambar gagal dimuat',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Video Player inline dengan error handling
// ─────────────────────────────────────────────────────────────────────────────
class _VideoBubble extends StatefulWidget {
  final String url;
  const _VideoBubble({required this.url});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) setState(() => _initialized = true);
          })
          .catchError((e) {
            if (mounted) setState(() => _hasError = true);
          });
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state → fallback buka di browser
    if (_hasError) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(widget.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: 210,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white54,
                size: 40,
              ),
              SizedBox(height: 6),
              Text(
                'Ketuk untuk membuka video',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!_initialized) return;
        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _initialized
                ? AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                )
                : Container(
                  width: 210,
                  height: 120,
                  color: Colors.black87,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            if (_initialized && !_ctrl.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            // Progress bar
            if (_initialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: File / Dokumen Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _FileBubble extends StatelessWidget {
  final String filePath;
  final bool isMe;
  final VoidCallback onTap;

  const _FileBubble({
    required this.filePath,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kind = detectFileKind(filePath);
    final name = p.basename(filePath);
    final color = fileColor(kind);
    final icon = fileIcon(kind);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ketuk untuk membuka',
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: isMe ? Colors.white60 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Audio Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _AudioBubble extends StatelessWidget {
  final bool isMe;
  final VoidCallback onTap;

  const _AudioBubble({required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF6A1B9A),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesan Suara',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Ketuk untuk membuka',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AdminChatScreen
// ─────────────────────────────────────────────────────────────────────────────
class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  List _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _token;
  String? _myId;
  Map? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final token = await _storage.read(key: 'auth_token');
    final userIdStr = await _storage.read(key: 'user_id');
    setState(() {
      _token = token;
      _myId = userIdStr;
    });
    if (_token != null) {
      _fetchChatHistory();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _fetchChatHistory(),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatHistory() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        setState(() {
          _messages = json.decode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin chat error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUKA GAMBAR FULLSCREEN DI DALAM APP ────────────────────────────────────
  void _openImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  // ── BUKA FILE/VIDEO/AUDIO VIA URL LAUNCHER ─────────────────────────────────
  Future<void> _openMedia(String? filePath) async {
    if (filePath == null) return;
    final url = Uri.parse('${Api.baseUrl}/storage/$filePath');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      _showSnackBar('Gagal membuka file: $e', isError: true);
    }
  }

  Future<void> _pickMedia(String type) async {
    try {
      if (type == 'image') {
        final f = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
        if (f != null) _uploadMedia(File(f.path), 'image');
      } else if (type == 'video') {
        final f = await _picker.pickVideo(source: ImageSource.gallery);
        if (f != null) _uploadMedia(File(f.path), 'video');
      } else if (type == 'audio') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
        );
        if (result != null)
          _uploadMedia(File(result.files.single.path!), 'audio');
      } else if (type == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'csv',
            'txt',
            'ppt',
            'pptx',
            'zip',
          ],
        );
        if (result != null)
          _uploadMedia(File(result.files.single.path!), 'file');
      }
    } catch (e) {
      _showSnackBar('Gagal memilih: $e', isError: true);
    }
  }

  Future<void> _uploadMedia(File file, String type) async {
    setState(() => _isUploading = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${Api.baseUrl}/api/chats'),
      );
      req.headers.addAll({
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });
      req.fields['type'] = type;
      if (_messageController.text.isNotEmpty)
        req.fields['message'] = _messageController.text;
      if (_replyingTo != null)
        req.fields['parent_id'] = _replyingTo!['id'].toString();
      req.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 201) {
        _messageController.clear();
        setState(() => _replyingTo = null);
        _fetchChatHistory();
        _scrollToBottom();
      } else {
        _showSnackBar('Upload gagal (${res.statusCode})', isError: true);
      }
    } on TimeoutException {
      _showSnackBar('Koneksi timeout, coba lagi.', isError: true);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _token == null) return;
    final msg = _messageController.text.trim();
    final parentId = _replyingTo?['id'];
    _messageController.clear();
    setState(() => _replyingTo = null);
    try {
      await http.post(
        Uri.parse('${Api.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'message': msg,
          'parent_id': parentId,
          'type': 'text',
        }),
      );
      _fetchChatHistory();
      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToMessage(int parentId) {
    final index = _messages.indexWhere((m) => m['id'] == parentId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 110.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMembers() async {
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/users'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final List users = json.decode(res.body);
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (_) => Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anggota Grup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(u['name'][0].toUpperCase()),
                            ),
                            title: Text(u['name']),
                            subtitle: Text(u['division']?['name'] ?? 'Staff'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        );
      }
    } catch (_) {
      _showSnackBar('Gagal memuat anggota', isError: true);
    }
  }

  void _showMediaGallery() {
    final mediaMessages =
        _messages.where((m) => m['file_path'] != null).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            expand: false,
            builder:
                (_, sc) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Media & Lampiran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child:
                            mediaMessages.isEmpty
                                ? const Center(child: Text('Tidak ada media'))
                                : GridView.builder(
                                  controller: sc,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                  itemCount: mediaMessages.length,
                                  itemBuilder: (_, i) {
                                    final msg = mediaMessages[i];
                                    final kind = detectFileKind(
                                      msg['file_path'] as String?,
                                    );
                                    final fileUrl =
                                        '${Api.baseUrl}/storage/${msg['file_path']}';
                                    return GestureDetector(
                                      onTap: () {
                                        if (kind == FileKind.image) {
                                          _openImageFullscreen(fileUrl);
                                        } else {
                                          _openMedia(
                                            msg['file_path'] as String?,
                                          );
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child:
                                            kind == FileKind.image
                                                ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    fileUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color: Colors.red,
                                                            ),
                                                  ),
                                                )
                                                : Center(
                                                  child: Icon(
                                                    fileIcon(kind),
                                                    color: fileColor(kind),
                                                    size: 32,
                                                  ),
                                                ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Admin Chat Panel',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'members') _showMembers();
              if (v == 'media') _showMediaGallery();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 20),
                        SizedBox(width: 8),
                        Text('Anggota'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'media',
                    child: Row(
                      children: [
                        Icon(Icons.perm_media, size: 20),
                        SizedBox(width: 8),
                        Text('Media & Lampiran'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(color: Colors.orange),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 20,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final chat = _messages[i];
                        final isMe =
                            chat['user_id'].toString() == _myId.toString();
                        return GestureDetector(
                          onLongPress: () => setState(() => _replyingTo = chat),
                          child: _buildBubble(chat, isMe),
                        );
                      },
                    ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── BUBBLE ─────────────────────────────────────────────────────────────────
  Widget _buildBubble(dynamic chat, bool isMe) {
    final type = chat['type'] as String? ?? 'text';
    final filePath = chat['file_path'] as String?;
    final fileUrl =
        filePath != null ? '${Api.baseUrl}/storage/$filePath' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                chat['user']['name'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: EdgeInsets.all(
                  type == 'image' || type == 'video' ? 6 : 12,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF0D47A1) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply quote
                    if (chat['parent'] != null)
                      GestureDetector(
                        onTap: () => _jumpToMessage(chat['parent_id']),
                        child: _buildReplyQuote(chat, isMe),
                      ),

                    // ── GAMBAR → buka fullscreen di dalam app ─────────────
                    if (type == 'image' && fileUrl != null)
                      GestureDetector(
                        onTap: () => _openImageFullscreen(fileUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            fileUrl,
                            width: 210,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : Container(
                                          width: 210,
                                          height: 130,
                                          alignment: Alignment.center,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        ),
                            errorBuilder:
                                (_, __, ___) => Container(
                                  width: 210,
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                          ),
                        ),
                      ),

                    // ── VIDEO → inline player dengan error handling ────────
                    if (type == 'video' && fileUrl != null)
                      _VideoBubble(url: fileUrl),

                    // ── AUDIO ─────────────────────────────────────────────
                    if ((type == 'audio' || type == 'voice') &&
                        filePath != null)
                      _AudioBubble(
                        isMe: isMe,
                        onTap: () => _openMedia(filePath),
                      ),

                    // ── FILE / DOKUMEN ────────────────────────────────────
                    if (type == 'file' && filePath != null)
                      _FileBubble(
                        filePath: filePath,
                        isMe: isMe,
                        onTap: () => _openMedia(filePath),
                      ),

                    // ── TEKS ──────────────────────────────────────────────
                    if (chat['message'] != null &&
                        (chat['message'] as String).isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: type != 'text' ? 8 : 0),
                        child: Text(
                          chat['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              DateFormat(
                'HH:mm',
              ).format(DateTime.parse(chat['created_at']).toLocal()),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(dynamic chat, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : Colors.indigo,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat['parent']['user']['name'],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.indigo,
            ),
          ),
          Text(
            chat['parent']['message']?.isNotEmpty == true
                ? chat['parent']['message']
                : '📎 Media',
            style: TextStyle(
              fontSize: 10,
              color: isMe ? Colors.white70 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── INPUT ──────────────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: Color(0xFF0D47A1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Membalas ${_replyingTo!['user']['name']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: Color(0xFF0D47A1),
                    size: 28,
                  ),
                  onPressed: _showAttachmentMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF0D47A1),
                    size: 26,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lampiran',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attachmentItem(
                      Icons.image_rounded,
                      'Gambar',
                      const Color(0xFF7C4DFF),
                      () {
                        Navigator.pop(context);
                        _pickMedia('image');
                      },
                    ),
                    _attachmentItem(
                      Icons.videocam_rounded,
                      'Video',
                      const Color(0xFFE53935),
                      () {
                        Navigator.pop(context);
                        _pickMedia('video');
                      },
                    ),
                    _attachmentItem(
                      Icons.audiotrack_rounded,
                      'Audio',
                      const Color(0xFF6A1B9A),
                      () {
                        Navigator.pop(context);
                        _pickMedia('audio');
                      },
                    ),
                    _attachmentItem(
                      Icons.folder_rounded,
                      'Dokumen',
                      const Color(0xFF1565C0),
                      () {
                        Navigator.pop(context);
                        _pickMedia('file');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _attachmentItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
