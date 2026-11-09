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
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
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
  String _adheeraReply = "All systems online, Boss! Multi-AI engine connected.";

  // ==========================================
  // APNI KEYS YAHAN PASTE KAREIN:
  final String _groqApiKey = "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";
  final String _nvidiaApiKey = "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";
  final String _geminiApiKey = "AQ.Ab8RN6Jlec8yVV04Cc8Dxm09aYd0kQN47ct3FVLfS-jOUvkF9w";
  // ==========================================

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initJarvisVoice();
  }

  Future<void> _initJarvisVoice() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82);
    await _tts.setSpeechRate(0.50);

    Future.delayed(const Duration(milliseconds: 800), () {
      _speak("All systems online, Boss! Multi-AI engine active. Bataiye kya order hai?");
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  // Fast Instant Mic Control
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            if (_isListening) {
              setState(() => _isListening = false);
              _triggerCommand();
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _userText = "Sun raha hoon, boliye Boss...";
        });

        _speech.listen(
          onResult: (result) {
            setState(() {
              _userText = result.recognizedWords;
            });
          },
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 15),
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      _triggerCommand();
    }
  }

  void _triggerCommand() {
    if (_userText.isNotEmpty && 
        _userText != "Mic par tap karke boliye..." && 
        _userText != "Sun raha hoon, boliye Boss...") {
      _processCommand(_userText);
    }
  }

  Future<void> _launchTargetApp(String packageName, String appName, [String? webUrl]) async {
    String msg = "$appName open kar raha hoon, Boss.";
    setState(() => _adheeraReply = msg);
    await _speak(msg);
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

    // Flashlight & Battery
    if (lower.contains("torch on") || lower.contains("flashlight on") || lower.contains("light on") || lower.contains("torch jalao")) {
      try {
        await TorchLight.enableTorch();
        String msg = "Flashlight activate kar di hai, Boss.";
        setState(() => _adheeraReply = msg);
        await _speak(msg);
      } catch (_) {
        setState(() => _adheeraReply = "Torch on karne me dikkat aayi.");
      }
      return;
    }

    if (lower.contains("torch off") || lower.contains("flashlight off") || lower.contains("light off") || lower.contains("torch band")) {
      try {
        await TorchLight.disableTorch();
        String msg = "Flashlight band kar di hai, Boss.";
        setState(() => _adheeraReply = msg);
        await _speak(msg);
      } catch (_) {
        setState(() => _adheeraReply = "Torch band karne me dikkat aayi.");
      }
      return;
    }

    if (lower.contains("battery") || lower.contains("charging") || lower.contains("charge kitna")) {
      try {
        final level = await _battery.batteryLevel;
        String msg = "Boss, battery status $level percent par hai.";
        setState(() => _adheeraReply = msg);
        await _speak(msg);
      } catch (_) {
        setState(() => _adheeraReply = "Battery check nahi ho paayi.");
      }
      return;
    }

    // Apps Opening
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

    // --- MULTI-AI AUTO FALLBACK PIPELINE ---
    await _askMultiAI(text);
  }

  // 1. Primary: Groq (Duniya ka sabse fast engine)
  Future<String?> _callGroq(String prompt) async {
    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": "You are Adheera, a personal male AI assistant modeled directly after Tony Stark's JARVIS. Highly intelligent, loyal, calm. Always address user as 'Boss' or 'Sir'. Reply in crisp, natural Hinglish using the Roman alphabet (e.g. 'Haan Boss, main check karta hoon'). Never use Devanagari Hindi characters. Keep answers short (1-2 sentences), confident, and instant."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      }
    } catch (_) {}
    return null;
  }

  // 2. Fallback: NVIDIA NIM
  Future<String?> _callNvidia(String prompt) async {
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
              "content": "You are Adheera, a personal male AI assistant modeled after JARVIS. Address user as 'Boss'. Reply in short, confident Hinglish using the Roman alphabet."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      }
    } catch (_) {}
    return null;
  }

  // 3. Fallback: Google Gemini
  Future<String?> _callGemini(String prompt) async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "You are Adheera, an AI personal assistant like JARVIS. Answer the user as 'Boss' in short, natural Hinglish using English alphabet: $prompt"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['candidates'][0]['content']['parts'][0]['text'];
      }
    } catch (_) {}
    return null;
  }

  // Master Fallback Controller
  Future<void> _askMultiAI(String prompt) async {
    setState(() => _isThinking = true);

    // Pehle Groq try karega (0.2s ultra fast)
    String? reply = await _callGroq(prompt);

    // Agar Groq me dikkat aayi toh NVIDIA se puchega
    reply ??= await _callNvidia(prompt);

    // Agar dono fail huye toh Google Gemini se puchega
    reply ??= await _callGemini(prompt);

    if (reply != null) {
      setState(() {
        _adheeraReply = reply!.trim();
      });
      await _speak(_adheeraReply);
    } else {
      setState(() {
        _adheeraReply = "Boss, sabhi AI engines busy hain. Kripya check karein.";
      });
    }

    setState(() => _isThinking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADHEERA // JARVIS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 18, color: Color(0xFF00E5FF))),
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
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 18),
                            SizedBox(width: 5),
                            Text("TRIPLE-AI CORE", style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF00E5FF), size: 22),
                          onPressed: () => _speak(_adheeraReply),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _isThinking ? "Consulting AI Core, Boss..." : _adheeraReply,
                          style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.5, letterSpacing: 0.3),
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
                  color: _isListening ? Colors.redAccent : const Color(0xFF00E5FF),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 45,
                  color: _isListening ? Colors.white : const Color(0xFF0B132B),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _isListening ? "Bol kar dobara tap karein to SEND" : "Tap to Speak",
              style: const TextStyle(color: Colors.white60, letterSpacing: 1),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
