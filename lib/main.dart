import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const AdheeraApp());
}

class AdheeraApp extends StatelessWidget {
  const AdheeraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adheera AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
        ),
      ),
      home: const AdheeraScreen(),
    );
  }
}

class AdheeraScreen extends StatefulWidget {
  const AdheeraScreen({super.key});

  @override
  State<AdheeraScreen> createState() => _AdheeraScreenState();
}

class _AdheeraScreenState extends State<AdheeraScreen> {
  late stt.SpeechToText _speech;
  late AudioPlayer _audioPlayer;

  bool _isListening = false;
  bool _isThinking = false;
  String _userText = "Mic par tap karke boliye...";
  String _adheeraReply = "Namaste Boss! Main Adheera hoon. Bataiye kya madad karun?";

  // 1. APNI NVIDIA KEY YAHAN DAALEIN:
  final String _nvidiaApiKey = "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";

  // 2. APNI DEEPGRAM KEY YAHAN DAALEIN:
  final String _deepgramApiKey = "fe6f00816fb142fc540cff404f21a7699397da87";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Deepgram Ultra-Realistic Male Voice Engine
  Future<void> _speakDeepgram(String text) async {
    try {
      final url = Uri.parse('https://api.deepgram.com/v1/speak?model=aura-arcas-en');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token $_deepgramApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      }
    } catch (_) {}
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            setState(() => _isListening = false);
            if (_userText.isNotEmpty && _userText != "Mic par tap karke boliye...") {
              _processCommand(_userText);
            }
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _userText = result.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // Koi bhi app launch karne ka master function
  Future<void> _launchTargetApp(String packageName, String appName, [String? webUrl]) async {
    setState(() => _adheeraReply = "$appName open kar raha hoon...");
    await _speakDeepgram("Opening $appName");
    try {
      await LaunchApp.openApp(androidPackageName: packageName, openStore: false);
    } catch (_) {
      if (webUrl != null) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  // Saari apps aur commands ka handler
  Future<void> _processCommand(String text) async {
    String lower = text.toLowerCase();

    // 1. WhatsApp
    if (lower.contains("whatsapp")) {
      await _launchTargetApp("com.whatsapp", "WhatsApp", "https://api.whatsapp.com/send");
      return;
    }
    // 2. YouTube
    if (lower.contains("youtube")) {
      await _launchTargetApp("com.google.android.youtube", "YouTube", "https://www.youtube.com");
      return;
    }
    // 3. Instagram
    if (lower.contains("instagram") || lower.contains("insta")) {
      await _launchTargetApp("com.instagram.android", "Instagram", "https://www.instagram.com");
      return;
    }
    // 4. Chrome / Google
    if (lower.contains("chrome") || lower.contains("browser") || lower.contains("google")) {
      await _launchTargetApp("com.android.chrome", "Chrome", "https://www.google.com");
      return;
    }
    // 5. Camera
    if (lower.contains("camera")) {
      await _launchTargetApp("com.android.camera", "Camera");
      return;
    }
    // 6. Calculator
    if (lower.contains("calculator") || lower.contains("hisab")) {
      await _launchTargetApp("com.google.android.calculator", "Calculator");
      return;
    }
    // 7. Settings
    if (lower.contains("setting") || lower.contains("settings")) {
      await _launchTargetApp("com.android.settings", "Settings");
      return;
    }
    // 8. Gallery / Photos
    if (lower.contains("gallery") || lower.contains("photos")) {
      await _launchTargetApp("com.google.android.apps.photos", "Gallery");
      return;
    }
    // 9. Spotify
    if (lower.contains("spotify") || lower.contains("music") || lower.contains("gana")) {
      await _launchTargetApp("com.spotify.music", "Spotify");
      return;
    }
    // 10. Facebook
    if (lower.contains("facebook")) {
      await _launchTargetApp("com.facebook.katana", "Facebook", "https://www.facebook.com");
      return;
    }

    // Baaki baaton ke liye NVIDIA AI
    await _askNvidia(text);
  }

  Future<void> _askNvidia(String prompt) async {
    setState(() => _isThinking = true);

    try {
      final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_nvidiaApiKey',
        },
        body: jsonEncode({
          "model": "meta/llama-3.2-90b-vision-instruct",
          "messages": [
            {
              "role": "system",
              "content": "Aapka naam Adheera hai. Aap ek loyal aur smart personal male AI assistant hain. User ke sawalon ka chhota, clear aur natural Hindi/English me answer dein."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 120,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = data['choices'][0]['message']['content'];

        setState(() {
          _adheeraReply = reply.trim();
        });

        await _speakDeepgram(reply);
      } else {
        setState(() {
          _adheeraReply = "Error (${response.statusCode}): ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _adheeraReply = "Network Error: $e";
      });
    } finally {
      setState(() => _isThinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADHEERA AI', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _userText,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _isThinking ? "Adheera soch raha hai..." : _adheeraReply,
                    style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _listen,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : const Color(0xFF38BDF8),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : const Color(0xFF38BDF8)).withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 45,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _isListening ? "Sun raha hoon..." : "Bolne ke liye Mic dabayein",
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
