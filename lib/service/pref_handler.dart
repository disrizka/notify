import 'package:shared_preferences/shared_preferences.dart';

class PreferenceHandler {
  static const String _id = 'idUser';
  static const String _lookWelcoming = 'lookWelcoming';
  static const String _token = 'token';

  // Simpan user ID
  static Future<void> saveId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_id, id);
  }

  // Simpan token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_token, token);
  }

  // Simpan flag sudah lihat welcome
  static Future<void> saveLookWelcoming(bool look) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lookWelcoming, look);
  }

  // Ambil token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_token);
  }

  // Ambil user ID
  static Future<int?> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_id);
  }

  // Ambil flag welcoming
  static Future<bool> getLookWelcoming() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lookWelcoming) ?? false;
  }

  // Hapus ID
  static Future<void> removeId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_id);
  }

  // Hapus token
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_token);
  }
}
