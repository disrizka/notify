import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
// GLOBAL: Image cache — bertahan selama app hidup, tidak reset saat screen
// dibuka/ditutup. Key = URL gambar, Value = bytes gambar.
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, Uint8List> _imageCache = {};

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Fullscreen Image Viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? token;
  const _FullscreenImageViewer({required this.imageUrl, this.token});

  get fileUrl => null;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    debugPrint('=== INIT STATE called for: ${widget.fileUrl}');
    _loadImage();
  }

  Future<void> _loadImage() async {
    debugPrint('=== _loadImage called: ${widget.fileUrl}');
    debugPrint('=== cache has key: ${_imageCache.containsKey(widget.fileUrl)}');
    debugPrint('=== _bytes is null: ${_bytes == null}');
    if (_imageCache.containsKey(widget.fileUrl)) {
      if (mounted)
        setState(() {
          _bytes = _imageCache[widget.fileUrl];
          _loading = false;
          _error = false;
        });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final client = http.Client();
      final res = await client
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              'Cache-Control': 'no-cache',
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 20));
      client.close();

      if (!mounted) return;

      // ── TAMBAH DEBUG INI ──────────────────────────────────
      debugPrint('=== IMAGE DEBUG ===');
      debugPrint('URL: ${widget.fileUrl}');
      debugPrint('Status: ${res.statusCode}');
      debugPrint('Content-Type: ${res.headers['content-type']}');
      debugPrint('Bytes received: ${res.bodyBytes.length}');
      debugPrint('First bytes: ${res.bodyBytes.take(4).toList()}');
      if (res.bodyBytes.length < 1000) {
        debugPrint('Body (teks): ${res.body}'); // kalau kecil, tampilkan isinya
      }
      // ──────────────────────────────────────────────────────

      if (res.statusCode == 200) {
        _imageCache[widget.fileUrl] = res.bodyBytes;
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (e) {
      debugPrint('ERROR load image: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final uri = Uri.parse(widget.imageUrl);
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Center(
        child:
            _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : _error || _bytes == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 64,
                    ),
                    TextButton(
                      onPressed: _loadImage,
                      child: const Text(
                        'Coba Lagi',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                )
                : InteractiveViewer(
                  child: Image.memory(_bytes!, fit: BoxFit.contain),
                ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Image Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _ImageBubble extends StatefulWidget {
  final String fileUrl;
  final VoidCallback onTap;
  final String? token;

  // Hapus const, dan hapus body constructor
  _ImageBubble({
    super.key,
    required this.fileUrl,
    required this.onTap,
    this.token,
  }) {
    print('=== _ImageBubble CONSTRUCTED: $fileUrl');
  }

  @override
  State<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<_ImageBubble> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Cek cache GLOBAL — jika sudah ada, langsung tampilkan tanpa request
    if (_imageCache.containsKey(widget.fileUrl)) {
      if (mounted)
        setState(() {
          _bytes = _imageCache[widget.fileUrl];
          _loading = false;
          _error = false;
        });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final client = http.Client();
      final res = await client
          .get(
            Uri.parse(widget.fileUrl),
            headers: {
              'Cache-Control': 'no-cache',
              if (widget.token != null)
                'Authorization': 'Bearer ${widget.token}',
            },
          )
          .timeout(const Duration(seconds: 20));
      client.close();

      if (!mounted) return;
      if (res.statusCode == 200) {
        _imageCache[widget.fileUrl] = res.bodyBytes; // simpan ke cache GLOBAL
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 220,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error || _bytes == null) {
      return GestureDetector(
        onTap: _loadImage,
        child: Container(
          width: 220,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 32),
              SizedBox(height: 4),
              Text(
                'Ketuk untuk muat ulang',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(_bytes!, width: 220, fit: BoxFit.cover),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Video Bubble
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
    _ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: const {'Connection': 'keep-alive'},
      )
      ..initialize()
          .then((_) {
            if (mounted) setState(() => _initialized = true);
          })
          .catchError((e) {
            if (mounted) setState(() => _hasError = true);
          });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(widget.url);
          if (await canLaunchUrl(uri))
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Container(
          width: 200,
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
                  width: 200,
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
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
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
          color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
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
                      color: isMe ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: isMe ? Colors.white70 : Colors.grey,
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
  final String url;
  final bool isMe;
  final VoidCallback onOpenExternal;

  const _AudioBubble({
    required this.url,
    required this.isMe,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenExternal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
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
// ChatScreen utama
// ─────────────────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  List _messages = [];
  List _members = [];
  Timer? _pollingTimer;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _token;
  int? _myId;
  Map? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final token = await _storage.read(key: 'auth_token');
    final userIdStr = await _storage.read(key: 'user_id');
    if (!mounted) return;
    setState(() {
      _token = token;
      _myId = userIdStr != null ? int.tryParse(userIdStr) : null;
    });
    if (_token != null) {
      await _fetchChatHistory();
      _fetchMembers();
      // Polling setiap 10 detik — lebih longgar agar tidak tabrakan dengan load gambar
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchChatHistory(),
      );
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    if (_token == null || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/users'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (mounted && res.statusCode == 200)
        setState(() => _members = json.decode(res.body));
    } catch (_) {}
  }

  Future<void> _fetchChatHistory() async {
    if (_token == null || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _messages = json.decode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('fetch chat error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _FullscreenImageViewer(imageUrl: imageUrl, token: _token),
      ),
    );
  }

  Future<void> _openMedia(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final String fullUrl = '${Api.baseUrl}/$filePath';
    final kind = detectFileKind(filePath);
    if (kind == FileKind.image) {
      _openImageFullscreen(fullUrl);
    } else {
      try {
        final uri = Uri.parse(fullUrl);
        if (await canLaunchUrl(uri))
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('openMedia error: $e');
      }
    }
  }

  Future<void> _pickMedia(String type) async {
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
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
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
      if (result != null) _uploadMedia(File(result.files.single.path!), 'file');
    }
  }

  Future<void> _uploadMedia(File file, String type) async {
    if (mounted) setState(() => _isUploading = true);
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
      req.fields['message'] = _messageController.text;
      if (_replyingTo != null)
        req.fields['parent_id'] = _replyingTo!['id'].toString();
      req.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (res.statusCode == 201) {
        _messageController.clear();
        setState(() => _replyingTo = null);
        await Future.delayed(const Duration(milliseconds: 1500));
        await _fetchChatHistory();
        _scrollToBottom();
      } else {
        _showSnackBar('Gagal upload: ${res.statusCode}', isError: true);
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
          'type': 'text',
          'parent_id': parentId,
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

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _jumpToMessage(int parentId) {
    final index = _messages.indexWhere((m) => m['id'] == parentId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 120.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  void _showMembersDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.people, color: Colors.indigo),
                SizedBox(width: 10),
                Text('Anggota Jonusa'),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  _members.isEmpty
                      ? const Center(child: Text('Memuat...'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final u = _members[i];
                          final isMe = u['id'] == _myId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(
                                u['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.indigo),
                              ),
                            ),
                            title: Text(u['name'] + (isMe ? ' (Anda)' : '')),
                            subtitle: Text(u['email'] ?? '-'),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showMembersDialog,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chat Internal Jonusa',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _members.isEmpty
                    ? 'Anggota: Memuat...'
                    : 'Anggota: ${_members.length} Orang',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(
              color: Colors.indigo,
              backgroundColor: Color(0xFFE8EAF6),
            ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _fetchChatHistory,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 20,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final chat = _messages[i];
                          final isMe = chat['user_id'] == _myId;
                          return GestureDetector(
                            onLongPress:
                                () => setState(() => _replyingTo = chat),
                            child: _buildBubble(chat, isMe),
                          );
                        },
                      ),
                    ),
          ),
          _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildBubble(dynamic chat, bool isMe) {
    final type = chat['type'] as String? ?? 'text';
    final filePath = chat['file_path'] as String?;

    final String fileUrl =
        (filePath != null && filePath.isNotEmpty)
            ? '${Api.baseUrl.trim()}/storage/${filePath.trim()}?v=${DateTime.now().millisecondsSinceEpoch}'
            : '';

    debugPrint('=== BUBBLE DEBUG ===');
    debugPrint('type: $type');
    debugPrint('filePath: $filePath');
    debugPrint('fileUrl: $fileUrl');

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
                chat['user']?['name'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.indigo,
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
                  color: isMe ? const Color(0xFF1A237E) : Colors.white,
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
                    if (chat['parent'] != null)
                      GestureDetector(
                        onTap: () => _jumpToMessage(chat['parent_id']),
                        child: _buildReplyQuote(chat, isMe),
                      ),

                    // ── GAMBAR — key pakai chat ID agar tidak rebuild saat polling
                    if (type == 'image' && fileUrl.isNotEmpty)
                      _ImageBubble(
                        // HAPUS key dulu untuk test
                        fileUrl: fileUrl,
                        token: _token,
                        onTap: () => _openImageFullscreen(fileUrl),
                      ),

                    if (type == 'video' && fileUrl.isNotEmpty)
                      _VideoBubble(url: fileUrl),

                    if ((type == 'audio' || type == 'voice') &&
                        fileUrl.isNotEmpty)
                      _AudioBubble(
                        url: fileUrl,
                        isMe: isMe,
                        onOpenExternal: () => _openMedia(filePath),
                      ),

                    if (type == 'file' && filePath != null)
                      _FileBubble(
                        filePath: filePath,
                        isMe: isMe,
                        onTap: () => _openMedia(filePath),
                      ),

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

  Widget _buildInputSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF3F4FF),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Membalas ${_replyingTo!['user']['name']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
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
                    color: Colors.indigo,
                    size: 28,
                  ),
                  onPressed: _showPickerMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
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
                    color: Colors.indigo,
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

  void _showPickerMenu() {
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
                    _attachItem(
                      Icons.image_rounded,
                      'Gambar',
                      const Color(0xFF7C4DFF),
                      () {
                        Navigator.pop(context);
                        _pickMedia('image');
                      },
                    ),
                    _attachItem(
                      Icons.videocam_rounded,
                      'Video',
                      const Color(0xFFE53935),
                      () {
                        Navigator.pop(context);
                        _pickMedia('video');
                      },
                    ),
                    _attachItem(
                      Icons.audiotrack_rounded,
                      'Audio',
                      const Color(0xFF6A1B9A),
                      () {
                        Navigator.pop(context);
                        _pickMedia('audio');
                      },
                    ),
                    _attachItem(
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

  Widget _attachItem(
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
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
