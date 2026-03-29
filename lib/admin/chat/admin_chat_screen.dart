import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:notify/api/api.dart' as Api;

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
    String? token = await _storage.read(key: 'auth_token');
    String? userIdStr = await _storage.read(key: 'user_id');
    setState(() {
      _token = token;
      _myId = userIdStr;
    });
    if (_token != null) {
      _fetchChatHistory();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 3),
        (timer) => _fetchChatHistory(),
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

  // --- FUNGSI PILIH MEDIA ---
  Future<void> _pickMedia(String type) async {
    try {
      if (type == 'image') {
        final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
        );
        if (file != null) _uploadMedia(File(file.path), 'image');
      } else if (type == 'video') {
        final XFile? file = await _picker.pickVideo(
          source: ImageSource.gallery,
        );
        if (file != null) _uploadMedia(File(file.path), 'video');
      } else if (type == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null)
          _uploadMedia(File(result.files.single.path!), 'file');
      }
    } catch (e) {
      _showSnackBar("Gagal memilih media: $e", isError: true);
    }
  }

  // --- FUNGSI UPLOAD ---
  Future<void> _uploadMedia(File file, String type) async {
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Api.baseUrl}/api/chats"),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });

      request.fields['type'] = type;
      if (_messageController.text.isNotEmpty)
        request.fields['message'] = _messageController.text;
      if (_replyingTo != null)
        request.fields['parent_id'] = _replyingTo!['id'].toString();

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _messageController.clear();
        setState(() => _replyingTo = null);
        _fetchChatHistory();
        _scrollToBottom();
      } else {
        debugPrint("Upload Gagal: ${response.body}");
        _showSnackBar("Server Error (${response.statusCode})", isError: true);
      }
    } on TimeoutException catch (_) {
      _showSnackBar("Koneksi Timeout. Coba lagi.", isError: true);
    } catch (e) {
      _showSnackBar("Kesalahan: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

  // --- FUNGSI JUMP & FETCH ---
  void _jumpToMessage(int parentId) {
    int index = _messages.indexWhere((m) => m['id'] == parentId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 110.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  Future<void> _fetchChatHistory() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse("${Api.baseUrl}/api/chats"),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _messages = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Admin Chat: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _token == null) return;
    String tempMsg = _messageController.text;
    int? parentId = _replyingTo != null ? _replyingTo!['id'] : null;
    _messageController.clear();
    setState(() => _replyingTo = null);
    try {
      await http.post(
        Uri.parse("${Api.baseUrl}/api/chats"),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'message': tempMsg,
          'parent_id': parentId,
          'type': 'text',
        }),
      );
      _fetchChatHistory();
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error Kirim Admin: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- FITUR 1: LIHAT ANGGOTA GRUP ---
  void _showMembers() async {
    try {
      final response = await http.get(
        Uri.parse('${Api.baseUrl}/api/users'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List users = json.decode(response.body);
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (context) => Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Anggota Grup",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(user['name'][0].toUpperCase()),
                            ),
                            title: Text(user['name']),
                            subtitle: Text(
                              user['division']?['name'] ?? 'Staff',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengambil anggota: $e");
      _showSnackBar("Gagal memuat anggota", isError: true);
    }
  }

  // --- FITUR 2: LIHAT MEDIA & LAMPIRAN ---
  void _showMediaGallery() {
    List mediaMessages =
        _messages.where((m) => m['file_path'] != null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Media & Lampiran",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child:
                            mediaMessages.isEmpty
                                ? const Center(child: Text("Tidak ada media"))
                                : GridView.builder(
                                  controller: scrollController,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                  itemCount: mediaMessages.length,
                                  itemBuilder: (context, index) {
                                    final msg = mediaMessages[index];
                                    final isImage = msg['file_path']
                                        .toString()
                                        .contains(RegExp(r'jpg|jpeg|png'));

                                    return GestureDetector(
                                      onTap: () {
                                        // Logika buka file (gunakan url_launcher atau viewer)
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child:
                                            isImage
                                                ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    "${Api.baseUrl}/storage/${msg['file_path']}",
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (c, e, s) => const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.red,
                                                        ),
                                                  ),
                                                )
                                                : const Icon(
                                                  Icons.insert_drive_file,
                                                  color: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Admin Chat Panel",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'members') _showMembers();
              if (value == 'media') _showMediaGallery();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 20),
                        SizedBox(width: 8),
                        Text("Anggota"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'media',
                    child: Row(
                      children: [
                        Icon(Icons.perm_media, size: 20),
                        SizedBox(width: 8),
                        Text("Media & Lampiran"),
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
                      itemBuilder: (context, index) {
                        var chat = _messages[index];
                        bool isMe =
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

  Widget _buildBubble(dynamic chat, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              "  ${chat['user']['name']}",
              style: const TextStyle(
                fontSize: 10,
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF0D47A1) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(15),
                    topRight: const Radius.circular(15),
                    bottomLeft:
                        isMe
                            ? const Radius.circular(15)
                            : const Radius.circular(0),
                    bottomRight:
                        isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
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
                    if (chat['type'] == 'image')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            "${Api.baseUrl}/storage/${chat['file_path']}",
                            errorBuilder:
                                (c, e, s) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.red,
                                ),
                          ),
                        ),
                      ),
                    if (chat['type'] == 'file')
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.insert_drive_file),
                            SizedBox(width: 8),
                            Text(
                              "Lampiran File",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      chat['message'] ?? "",
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            " ${DateFormat('HH:mm').format(DateTime.parse(chat['created_at']).toLocal())}",
            style: const TextStyle(fontSize: 8, color: Colors.grey),
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
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
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
            chat['parent']['message'] ?? "Media",
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

  Widget _buildInputArea() {
    return Column(
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Icon(Icons.reply, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Membalas ${_replyingTo!['user']['name']}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: Color(0xFF0D47A1),
                ),
                onPressed: _showAttachmentMenu,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Tulis pesan...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF0D47A1)),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentItem(Icons.image, "Gambar", Colors.purple, () {
                  Navigator.pop(context);
                  _pickMedia('image');
                }),
                _attachmentItem(Icons.videocam, "Video", Colors.red, () {
                  Navigator.pop(context);
                  _pickMedia('video');
                }),
                _attachmentItem(
                  Icons.insert_drive_file,
                  "Dokumen",
                  Colors.blue,
                  () {
                    Navigator.pop(context);
                    _pickMedia('file');
                  },
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
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
