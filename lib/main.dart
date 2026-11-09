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

void main() => runApp(const AdheeraApp());

class AdheeraApp extends StatelessWidget {
  const AdheeraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adheera AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1322),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF6B6B)),
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
  // APNI KEYS YAHAN PASTE KAREIN (LINES 46-49):
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
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _initVoice();
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
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
          onResult: (result) => setState(() => _userText = result.recognizedWords),
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

  Future<void> _launchApp(String pkg, String name, [String? url]) async {
    String msg = "$name open kar raha hoon, Boss.";
    setState(() => _adheeraReply = msg);
    await _speak(msg);
    try {
      await LaunchApp.openApp(androidPackageName: pkg, openStore: false);
    } catch (_) {
      if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _processCommand(String text) async {
    String lower = text.toLowerCase();

    if (lower.contains("torch on") || lower.contains("flashlight on") || lower.contains("light on") || lower.contains("torch jalao")) {
      try {
        await TorchLight.enableTorch();
        setState(() => _adheeraReply = "Flashlight activate kar di hai, Boss.");
        await _speak("Flashlight activate kar di hai, Boss.");
      } catch (_) {}
      return;
    }
    if (lower.contains("torch off") || lower.contains("flashlight off") || lower.contains("light off") || lower.contains("torch band")) {
      try {
        await TorchLight.disableTorch();
        setState(() => _adheeraReply = "Flashlight band kar di hai, Boss.");
        await _speak("Flashlight band kar di hai, Boss.");
      } catch (_) {}
      return;
    }
    if (lower.contains("battery") || lower.contains("charging") || lower.contains("charge kitna")) {
      try {
        final level = await _battery.batteryLevel;
        String msg = "Boss, battery status $level percent par hai.";
        setState(() => _adheeraReply = msg);
        await _speak(msg);
      } catch (_) {}
      return;
    }

    if (lower.contains("whatsapp")) return _launchApp("com.whatsapp", "WhatsApp", "https://api.whatsapp.com/send");
    if (lower.contains("youtube")) return _launchApp("com.google.android.youtube", "YouTube", "https://www.youtube.com");
    if (lower.contains("instagram") || lower.contains("insta")) return _launchApp("com.instagram.android", "Instagram", "https://www.instagram.com");
    if (lower.contains("chrome") || lower.contains("browser") || lower.contains("google")) return _launchApp("com.android.chrome", "Chrome", "https://www.google.com");
    if (lower.contains("camera")) return _launchApp("com.android.camera", "Camera");
    if (lower.contains("calculator") || lower.contains("hisab")) return _launchApp("com.google.android.calculator", "Calculator");
    if (lower.contains("setting")) return _launchApp("com.android.settings", "Settings");
    if (lower.contains("gallery") || lower.contains("photos")) return _launchApp("com.google.android.apps.photos", "Gallery");
    if (lower.contains("spotify") || lower.contains("music")) return _launchApp("com.spotify.music", "Spotify");
    if (lower.contains("facebook")) return _launchApp("com.facebook.katana", "Facebook", "https://www.facebook.com");

    await _askMultiAI(text);
  }

  Future<String?> _callOpenAI(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_openAiApiKey'},
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": "You are Adheera, a personal male AI assistant like JARVIS. Address user as 'Boss'. Reply in short, natural Hinglish using Roman alphabet. Keep answers short (1-2 sentences)."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'];
    } catch (_) {}
    return null;
  }

  Future<String?> _callGroq(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_groqApiKey'},
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": "You are Adheera, an AI assistant like JARVIS. Address user as 'Boss'. Reply in short, confident Hinglish."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'];
    } catch (_) {}
    return null;
  }

  Future<String?> _callNvidia(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_nvidiaApiKey'},
        body: jsonEncode({
          "model": "meta/llama-3.2-90b-vision-instruct",
          "messages": [
            {"role": "system", "content": "You are Adheera, an AI assistant like JARVIS. Address user as 'Boss'. Reply in short Hinglish."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 100,
        }),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'];
    } catch (_) {}
    return null;
  }

  Future<String?> _callGemini(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": "You are Adheera, an AI like JARVIS. Answer user as 'Boss' in short Hinglish: $prompt"}]}]
        }),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['candidates'][0]['content']['parts'][0]['text'];
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
      setState(() => _adheeraReply = reply!.trim());
      await _speak(_adheeraReply);
    } else {
      setState(() => _adheeraReply = "Boss, network response me delay hua. Kripya dobara boliye.");
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF161F33), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
              child: Text(_userText, style: const TextStyle(fontSize: 15, color: Colors.white70)),
            ),
            const Spacer(),
            // 3D VIDEO SWIRLING PARTICLE ORB (MEDIUM SIZE)
            GestureDetector(
              onTap: _listen,
              child: AnimatedBuilder(
                animation: _orbController,
                builder: (context, _) => SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: SwirlingParticleOrbPainter(
                      animValue: _orbController.value,
                      isListening: _isListening,
                      isThinking: _isThinking,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            // Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isListening ? const Color(0xFFFF5252) : (_isThinking ? const Color(0xFFFAB1A0) : Colors.white12)),
              ),
              child: Text(
                _isListening ? "• MIC ON — LISTENING..." : (_isThinking ? "• THINKING..." : "• TAP ORB TO SPEAK •"),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: _isListening ? const Color(0xFFFF5252) : const Color(0xFFFAB1A0)),
              ),
            ),
            const Spacer(),
            // Response Card
            Container(
              width: double.infinity,
              height: 150,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161F33),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFF7675).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ADHEERA RESPONSE", style: TextStyle(color: Color(0xFFFF7675), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
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
                      child: Text(_isThinking ? "Processing command, Boss..." : _adheeraReply, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)),
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

// 3D Particle Structure
class ParticlePoint {
  final double x, y, z, ratio;
  const ParticlePoint(this.x, this.y, this.z, this.ratio);
}

class SwirlingParticleOrbPainter extends CustomPainter {
  final double animValue;
  final bool isListening;
  final bool isThinking;

  static final List<ParticlePoint> _pts = List.generate(220, (i) {
    final y = 1.0 - (i / 219.0) * 2.0;
    final r = math.sqrt(math.max(0.0, 1.0 - y * y));
    final theta = 2.399963 * i;
    return ParticlePoint(math.cos(theta) * r, y, math.sin(theta) * r, i / 220.0);
  });

  SwirlingParticleOrbPainter({required this.animValue, required this.isListening, required this.isThinking});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.40;
    final speed = isThinking ? 3.2 : (isListening ? 2.4 : 1.0);
    final waveAmp = isThinking ? 0.12 : (isListening ? 0.16 : 0.04);
    final aY = animValue * 2 * math.pi * speed;
    final aX = math.sin(animValue * 2 * math.pi) * 0.35;

    // Glowing core
    canvas.drawCircle(
      center,
      baseR * 0.95,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.35),
            const Color(0xFFFF7675).withOpacity(0.20),
            const Color(0xFFFD79A8).withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: baseR * 0.95)),
    );

    final cosY = math.cos(aY), sinY = math.sin(aY);
    final cosX = math.cos(aX), sinX = math.sin(aX);

    for (final p in _pts) {
      final x1 = p.x * cosY - p.z * sinY;
      final z1 = p.x * sinY + p.z * cosY;
      final y1 = p.y * cosX - z1 * sinX;
      final z2 = p.y * sinX + z1 * cosX;

      final wave = 1.0 + waveAmp * math.sin(animValue * 10 + p.x * 4 + p.y * 3);
      final r = baseR * wave;
      final sx = center.dx + x1 * r;
      final sy = center.dy + y1 * r;
      final depth = ((z2 + 1.2) / 2.4).clamp(0.15, 1.0);

      final color = Color.lerp(
        const Color(0xFFFFEAA7),
        const Color(0xFFFF4757),
        (p.ratio * 0.7 + depth * 0.3).clamp(0.0, 1.0),
      )!.withOpacity((depth * 0.85 + 0.15).clamp(0.25, 1.0));

      canvas.drawCircle(Offset(sx, sy), 1.4 + depth * 2.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant SwirlingParticleOrbPainter old) =>
      old.animValue != animValue || old.isListening != isListening || old.isThinking != isThinking;
}
