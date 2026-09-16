import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';

class CloudinaryService {
  /// Uploads a file to Cloudinary and returns the secure URL.
  /// [category] can be 'images', 'videos', 'stories', or 'voice'.
  static Future<String> uploadMedia({
    required File file,
    required String category,
  }) async {
    final folder = 'spillcity/$category';

    // 1. Fetch the signature and credentials securely from the Edge Function
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('No authenticated user found');

    final sigResponse = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/functions/v1/cloudinary-signature'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'folder': folder}),
    );

    if (sigResponse.statusCode != 200) {
      throw Exception('Failed to get Cloudinary signature: ${sigResponse.body}');
    }

    final sigData = jsonDecode(sigResponse.body);
    final String signature = sigData['signature'];
    final String timestamp = sigData['timestamp'];
    final String apiKey = sigData['apiKey'];
    final String cloudName = sigData['cloudName'];

    // 2. Determine Cloudinary resource type
    final ext = p.extension(file.path).toLowerCase();
    final isVideoExtension = [
      '.mp4', '.mov', '.avi', '.mkv', '.flv', '.webm', '.3gp', '.wmv',
      '.mp3', '.wav', '.m4a', '.aac', '.ogg', '.wma'
    ].contains(ext);
    final isVideoOrVoice = category == 'videos' || category == 'voice' || isVideoExtension;
    final resourceType = isVideoOrVoice ? 'video' : 'image';

    // 3. Upload directly to Cloudinary using the secure signature
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp
      ..fields['signature'] = signature
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return data['secure_url'] as String;
    } else {
      throw Exception('Failed to upload file to Cloudinary: ${response.body}');
    }
  }
}
