import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:torch_light/torch_light.dart';
import 'package:battery_plus/battery_plus.dart';

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
  late FlutterTts _tts;
  final Battery _battery = Battery();

  bool _isListening = false;
  bool _isThinking = false;
  String _userText = "Mic par tap karke boliye...";
  String _adheeraReply = "Namaste Boss! Main Adheera hoon. Bataiye kya kaam karna hai?";

  // APNI NVIDIA KEY YAHAN DAALEIN:
  final String _nvidiaApiKey = "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";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTtsEngine();
  }

  Future<void> _initTtsEngine() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82); // Confident deep male tone
    await _tts.setSpeechRate(0.48); // Natural human talking speed

    // App open hone ke 1 second baad bolkar start karega
    Future.delayed(const Duration(milliseconds: 1000), () {
      _speak("Hello Boss! Main Adheera hoon. Bataiye kya kaam karna hai?");
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
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

  Future<void> _launchTargetApp(String packageName, String appName, [String? webUrl]) async {
    setState(() => _adheeraReply = "$appName open kar raha hoon...");
    await _speak("Opening $appName");
    try {
      await LaunchApp.openApp(androidPackageName: packageName, openStore: false);
    } catch (_) {
      if (webUrl != null) {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _processCommand(String text) async {
    String lower = text.toLowerCase();

    // 1. Flashlight ON
    if (lower.contains("torch on") || lower.contains("flashlight on") || lower.contains("light on") || lower.contains("torch jalao")) {
      try {
        await TorchLight.enableTorch();
        setState(() => _adheeraReply = "Flashlight ON kar diya hai.");
        await _speak("Flashlight on kar diya hai");
      } catch (e) {
        setState(() => _adheeraReply = "Torch on karne me dikkat aayi.");
      }
      return;
    }

    // 2. Flashlight OFF
    if (lower.contains("torch off") || lower.contains("flashlight off") || lower.contains("light off") || lower.contains("torch band")) {
      try {
        await TorchLight.disableTorch();
        setState(() => _adheeraReply = "Flashlight OFF kar diya hai.");
        await _speak("Flashlight band kar diya hai");
      } catch (e) {
        setState(() => _adheeraReply = "Torch band karne me dikkat aayi.");
      }
      return;
    }

    // 3. Battery Percentage Check
    if (lower.contains("battery") || lower.contains("charging") || lower.contains("charge kitna")) {
      try {
        final level = await _battery.batteryLevel;
        String msg = "Boss, phone me $level percent battery bachi hai.";
        setState(() => _adheeraReply = msg);
        await _speak(msg);
      } catch (e) {
        setState(() => _adheeraReply = "Battery check nahi ho paayi.");
      }
      return;
    }

    // 4. Apps Opening
    if (lower.contains("whatsapp")) {
      await _launchTargetApp("com.whatsapp", "WhatsApp", "https://api.whatsapp.com/send");
      return;
    }
    if (lower.contains("youtube")) {
      await _launchTargetApp("com.google.android.youtube", "YouTube", "https://www.youtube.com");
      return;
    }
    if (lower.contains("instagram") || lower.contains("insta")) {
      await _launchTargetApp("com.instagram.android", "Instagram", "https://www.instagram.com");
      return;
    }
    if (lower.contains("chrome") || lower.contains("browser") || lower.contains("google")) {
      await _launchTargetApp("com.android.chrome", "Chrome", "https://www.google.com");
      return;
    }
    if (lower.contains("camera")) {
      await _launchTargetApp("com.android.camera", "Camera");
      return;
    }
    if (lower.contains("calculator") || lower.contains("hisab")) {
      await _launchTargetApp("com.google.android.calculator", "Calculator");
      return;
    }
    if (lower.contains("setting") || lower.contains("settings")) {
      await _launchTargetApp("com.android.settings", "Settings");
      return;
    }
    if (lower.contains("gallery") || lower.contains("photos")) {
      await _launchTargetApp("com.google.android.apps.photos", "Gallery");
      return;
    }
    if (lower.contains("spotify") || lower.contains("music") || lower.contains("gana")) {
      await _launchTargetApp("com.spotify.music", "Spotify");
      return;
    }
    if (lower.contains("facebook")) {
      await _launchTargetApp("com.facebook.katana", "Facebook", "https://www.facebook.com");
      return;
    }

    // --- NVIDIA AI BRAIN ---
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
              "content": "You are Adheera, a powerful male personal AI assistant like Jarvis. Always reply in clean Hindi or Hinglish using the Roman alphabet (e.g. 'Haan Boss, main bilkul theek hoon'). Do NOT use Devanagari script. Keep answers confident, direct, and respectful."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = data['choices'][0]['message']['content'];

        setState(() {
          _adheeraReply = reply.trim();
        });

        await _speak(reply);
      } else {
        setState(() {
          _adheeraReply = "NVIDIA Error (${response.statusCode}): ${response.body}";
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("ADHEERA", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF38BDF8)),
                          onPressed: () => _speak(_adheeraReply),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _isThinking ? "Adheera soch raha hai..." : _adheeraReply,
                          style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.4),
                        ),
                      ),
                    ),
                  ],
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
