import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sapa_jonusa/api/api.dart' as Api;
import 'package:url_launcher/url_launcher.dart';


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
  List _members = []; // Simpan daftar anggota di sini
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
    String? token = await _storage.read(key: 'auth_token');
    String? userIdStr = await _storage.read(key: 'user_id');

    setState(() {
      _token = token;
      _myId = userIdStr != null ? int.parse(userIdStr) : null;
    });

    if (_token != null) {
      _fetchChatHistory();
      _fetchMembers(); // Ambil data anggota saat pertama kali masuk
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

  // --- FUNGSI BARU: AMBIL DAFTAR ANGGOTA ---
  Future<void> _fetchMembers() async {
    try {
      print("--- MENGAMBIL DAFTAR ANGGOTA ---");
      final response = await http.get(
        Uri.parse("${Api.baseUrl}/api/users"),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      print("Status Anggota: ${response.statusCode}");

      if (response.statusCode == 200) {
        setState(() {
          _members = json.decode(response.body);
        });
        print("Berhasil muat ${_members.length} anggota");
      } else {
        print("Gagal muat anggota: ${response.body}");
      }
    } catch (e) {
      print("Error fetch members: $e");
    }
  }

  // --- FUNGSI BARU: TAMPILKAN DIALOG ANGGOTA ---
  void _showMembersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.people, color: Colors.indigo),
                SizedBox(width: 10),
                Text("Anggota Jonusa", style: TextStyle(fontSize: 18)),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            content: Container(
              width: double.maxFinite,
              child:
                  _members.isEmpty
                      ? Center(child: Text("Memuat daftar anggota..."))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          var user = _members[index];
                          bool isMe = user['id'] == _myId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(
                                user['name'][0].toUpperCase(),
                                style: TextStyle(color: Colors.indigo),
                              ),
                            ),
                            title: Text(user['name'] + (isMe ? " (Anda)" : "")),
                            subtitle: Text(user['email'] ?? "-"),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Tutup"),
              ),
            ],
          ),
    );
  }

  // --- FUNGSI UNTUK MEMBUKA FILE / URL ---
  Future<void> _openMedia(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final String fullUrl = "${Api.baseUrl}/storage/$filePath";
    final Uri url = Uri.parse(fullUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar(
          "Tidak bisa membuka file. Pastikan ada aplikasi pendukung.",
        );
      }
    } catch (e) {
      _showSnackBar("Gagal memproses file: $e");
    }
  }

  void _jumpToMessage(int parentId) {
    int index = _messages.indexWhere((m) => m['id'] == parentId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 120.0,
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
      debugPrint("Error chat history: $e");
    }
  }

  Future<void> _pickMedia(String type) async {
    if (type == 'image') {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (file != null) _uploadMedia(File(file.path), 'image');
    } else if (type == 'video') {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) _uploadMedia(File(file.path), 'video');
    } else if (type == 'file') {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) _uploadMedia(File(result.files.single.path!), 'file');
    }
  }

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
      request.fields['message'] =
          _messageController.text.isEmpty ? "" : _messageController.text;
      if (_replyingTo != null)
        request.fields['parent_id'] = _replyingTo!['id'].toString();
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 40),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _messageController.clear();
        setState(() => _replyingTo = null);
        _fetchChatHistory();
        _scrollToBottom();
      } else {
        _showSnackBar("Gagal upload: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Terjadi kesalahan: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _token == null) return;
    String msg = _messageController.text;
    int? parentId = _replyingTo != null ? _replyingTo!['id'] : null;
    _messageController.clear();
    setState(() => _replyingTo = null);
    try {
      final response = await http.post(
        Uri.parse("${Api.baseUrl}/api/chats"),
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
      if (response.statusCode == 201) {
        _fetchChatHistory();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error kirim pesan: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // AREA JUDUL YANG BISA DIKLIK
        title: GestureDetector(
          onTap: _showMembersDialog, // Klik bagian atas untuk lihat anggota
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Chat Internal Jonusa",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _members.isEmpty
                    ? "Anggota: Memuat..."
                    : "Anggota: ${_members.length} Orang",
                style: TextStyle(color: Colors.grey, fontSize: 10),
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
          if (_isUploading) const LinearProgressIndicator(color: Colors.indigo),
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
                        bool isMe = chat['user_id'] == _myId;
                        return GestureDetector(
                          onLongPress: () => setState(() => _replyingTo = chat),
                          child: _buildBubble(chat, isMe),
                        );
                      },
                    ),
          ),
          _buildInputSection(),
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
                color: Colors.blue,
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
                  color: isMe ? Colors.indigo : Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
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
                      GestureDetector(
                        onTap: () => _openMedia(chat['file_path']),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            "${Api.baseUrl}/storage/${chat['file_path']}",
                            errorBuilder:
                                (c, e, s) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ),

                    if (chat['type'] == 'file')
                      InkWell(
                        onTap: () => _openMedia(chat['file_path']),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.insert_drive_file, size: 20),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Buka Lampiran File",
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (chat['message'] != null && chat['message'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: chat['type'] != 'text' ? 8 : 0,
                        ),
                        child: Text(
                          chat['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
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
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[350],
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

  Widget _buildInputSection() {
    return Column(
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.reply, size: 20, color: Colors.indigo),
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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.indigo),
                onPressed: () => _showPickerMenu(),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Tulis pesan...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.indigo),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPickerMenu() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Gambar'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia('image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia('video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Dokumen'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia('file');
                },
              ),
            ],
          ),
    );
  }
}
