import 'dart:convert';
import 'dart:math' as math;
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
        scaffoldBackgroundColor: const Color(0xFF0D1322),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B6B),
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

class _AdheeraScreenState extends State<AdheeraScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final Battery _battery = Battery();
  late AnimationController _orbController;

  bool _isListening = false;
  bool _isThinking = false;
  String _userText = "Commands dene ke liye tap karein...";
  String _adheeraReply = "All systems online, Boss! Main Adheera hoon.";

  // ==============================================================
  // APNI KEYS YAHAN PASTE KAREIN:
  final String _openAiApiKey = "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";
  final String _groqApiKey = "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";
  final String _nvidiaApiKey = "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";
  final String _geminiApiKey = "AQ.Ab8RN6Jlec8yVV04Cc8Dxm09aYd0kQN47ct3FVLfS-jOUvkF9w";
  // ==============================================================

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    
    // Continuous 3D Orb Animation
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initJarvisVoice();
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _initJarvisVoice() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82);
    await _tts.setSpeechRate(0.50);

    Future.delayed(const Duration(milliseconds: 700), () {
      _speak("All systems online, Boss! Main Adheera hoon. Bataiye kya order hai?");
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
        _userText != "Commands dene ke liye tap karein..." && 
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

    // Hardware Controls
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

    // AI Engines
    await _askMultiAI(text);
  }

  Future<String?> _callOpenAI(String prompt) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": "You are Adheera, a personal male AI assistant like JARVIS. Address user as 'Boss'. Reply in short, natural Hinglish using Roman alphabet. Keep answers short and direct."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      }
    } catch (_) {}
    return null;
  }

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
              "content": "You are Adheera, an AI assistant like JARVIS. Address user as 'Boss'. Reply in short, confident Hinglish."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      }
    } catch (_) {}
    return null;
  }

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
              "content": "You are Adheera, an AI personal assistant like JARVIS. Address user as 'Boss'. Reply in short Hinglish."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      }
    } catch (_) {}
    return null;
  }

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
                {"text": "You are Adheera, an AI like JARVIS. Answer user as 'Boss' in short Hinglish: $prompt"}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['candidates'][0]['content']['parts'][0]['text'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _askMultiAI(String prompt) async {
    setState(() => _isThinking = true);
    String? reply;

    try {
      reply = await _callOpenAI(prompt);
      reply ??= await _callGroq(prompt);
      reply ??= await _callNvidia(prompt);
      reply ??= await _callGemini(prompt);
    } catch (_) {
    } finally {
      setState(() => _isThinking = false);
    }

    if (reply != null && reply.isNotEmpty) {
      setState(() {
        _adheeraReply = reply!.trim();
      });
      await _speak(_adheeraReply);
    } else {
      setState(() {
        _adheeraReply = "Boss, network response me delay hua. Kripya dobara boliye.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADHEERA // JARVIS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 18, color: Color(0xFFFF7675))),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            // User Text Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                _userText,
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ),
            
            const Spacer(),

            // ==========================================
            // VIDEO JAISA EXACT SWIRLING PARTICLE ORB (MEDIUM SIZE)
            // ==========================================
            GestureDetector(
              onTap: _listen,
              child: AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: SwirlingParticleOrbPainter(
                        animationValue: _orbController.value,
                        isListening: _isListening,
                        isThinking: _isThinking,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // Status Indicator Pill (Video jaisa)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isListening 
                      ? const Color(0xFFFF5252) 
                      : (_isThinking ? const Color(0xFFFAB1A0) : Colors.white12),
                ),
              ),
              child: Text(
                _isListening 
                    ? "• MIC ON — LISTENING..." 
                    : (_isThinking ? "• THINKING..." : "• TAP ORB TO SPEAK •"),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: _isListening ? const Color(0xFFFF5252) : const Color(0xFFFAB1A0),
                ),
              ),
            ),

            const Spacer(),

            // Adheera Response Card
            Container(
              width: double.infinity,
              height: 160,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFF7675).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7675).withOpacity(0.08),
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
                      const Text(
                        "ADHEERA RESPONSE", 
                        style: TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Color(0xFFFF7675), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _speak(_adheeraReply),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _isThinking ? "Processing command, Boss..." : _adheeraReply,
                        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3D SWIRLING PARTICLE ORB PAINTER (Video Style)
// ==========================================
class Point3D {
  final double x, y, z;
  final double baseColorRatio;
  const Point3D(this.x, this.y, this.z, this.baseColorRatio);
}

class SwirlingParticleOrbPainter extends CustomPainter {
  final double animationValue;
  final bool isListening;
  final bool isThinking;

  // Pre-calculated Fibonacci sphere points (Smooth performance)
  static final List<Point3D> _spherePoints = () {
    final list = <Point3D>[];
    const count = 260;
    const phi = 2.399963229728653; // Golden angle
    for (int i = 0; i < count; i++) {
      final y = 1.0 - (i / (count - 1.0)) * 2.0;
      final radius = math.sqrt(1.0 - y * y);
      final theta = phi * i;
      final x = math.cos(theta) * radius;
      final z = math.sin(theta) * radius;
      list.add(Point3D(x, y, z, i / count));
    }
    return list;
  }();

  SwirlingParticleOrbPainter({
    required this.animationValue,
    required this.isListening,
    required this.isThinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.40;

    // Commands speed & wave ripple multiplier
    double speedMultiplier = 1.0;
    double waveAmp = 0.04;

    if (isThinking) {
      speedMultiplier = 3.2;
      waveAmp = 0.12;
    } else if (isListening) {
      speedMultiplier = 2.4;
      waveAmp = 0.16;
    }

    final angleY = animationValue * 2 * math.pi * speedMultiplier;
    final angleX = math.sin(animationValue * 2 * math.pi) * 0.35;

    // Core Glowing Sphere (Video style center aura)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.35),
          const Color(0xFFFF7675).withOpacity(0.20),
          const Color(0xFFFD79A8).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.95));

    canvas.drawCircle(center, baseRadius * 0.95, glowPaint);

    // 3D Particles rotation & projection
    for (final pt in _spherePoints) {
      // Rotation Y
      final cosY = math.cos(angleY);
      final sinY = math.sin(angleY);
      final x1 = pt.x * cosY - pt.z * sinY;
      final z1 = pt.x * sinY + pt.z * cosY;

      // Rotation X
      final cosX = math.cos(angleX);
      final sinX = math.sin(angleX);
      final y1 = pt.y * cosX - z1 * sinX;
      final z2 = pt.y * sinX + z1 * cosX;

      // Dynamic Wave on Speech / Commands
      final wave = 1.0 + waveAmp * math.sin(animationValue * 10 + pt.x * 4 + pt.y * 3);
      final r = baseRadius * wave;

      final screenX = 
