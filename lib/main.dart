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
        scaffoldBackgroundColor: const Color(0xFF070B14),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF)),
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
  bool _isSpeaking = false;
  bool _companionMode = true; // Continuous hands-free talk
  String _userText = "Baat shuru karne ke liye Mic dabayein...";
  String _adheeraReply = "All systems online, Boss! Main Adheera hoon.";

  // ==============================================================
  // APNI KEYS YAHAN PASTE KAREIN (LINES 46-49):
  final String _groqApiKey = "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";           // Groq (Primary 0.2s)
  final String _openAiApiKey = "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";   // OpenAI Fallback
  final String _nvidiaApiKey = "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";     // NVIDIA Fallback
  final String _geminiApiKey = "AQ.Ab8RN6Jlec8yVV04Cc8Dxm09aYd0kQN47ct3FVLfS-jOUvkF9w";    // Gemini Fallback
  // ==============================================================

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _initVoiceAndHandlers();
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _initVoiceAndHandlers() async {
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82);
    await _tts.setSpeechRate(0.52);

    // REAL-TIME AUTO LOOP: Jaise hi Adheera bolna band karega, Mic apne aap open ho jayega!
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_companionMode) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!_isListening && !_isThinking) _startListening();
          });
        }
      }
    });

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      _speak("All systems online, Boss! Main Adheera hoon. Bataiye kya order hai?");
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (_isSpeaking) await _tts.stop();

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

      // 800ms Super-Fast silence detection (Zero waiting)
      _speech.listen(
        onResult: (result) => setState(() => _userText = result.recognizedWords),
        pauseFor: const Duration(milliseconds: 800),
        listenFor: const Duration(seconds: 12),
      );
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
    _triggerCommand();
  }

  void _triggerCommand() {
    if (_userText.isNotEmpty &&
        _userText != "Baat shuru karne ke liye Mic dabayein..." &&
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

    // Hardware Commands
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

    // Apps
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

    await _askFastAI(text);
  }

  // Real-time Ultra Fast Groq Pipeline (0.15s)
  Future<String?> _callGroq(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_groqApiKey'},
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system",
              "content": "You are Adheera, an ultra-fast real-time AI companion like JARVIS. Speak in natural conversational Hinglish using Roman alphabet. Keep replies very short (1 punchy sentence, max 15 words) so it speaks instantly. Address user as 'Boss'."
            },
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 60,
          "temperature": 0.6,
        }),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'];
    } catch (_) {}
    return null;
  }

  Future<String?> _callOpenAI(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_openAiApiKey'},
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": "You are Adheera, an AI companion. Answer as 'Boss' in 1 short Hinglish sentence."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 60,
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
            {"role": "system", "content": "You are Adheera. Answer as 'Boss' in 1 short Hinglish sentence."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 60,
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
          "contents": [{"parts": [{"text": "Answer as 'Boss' in 1 short Hinglish sentence: $prompt"}]}]
        }),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes))['candidates'][0]['content']['parts'][0]['text'];
    } catch (_) {}
    return null;
  }

  Future<void> _askFastAI(String prompt) async {
    setState(() => _isThinking = true);
    String? reply;
    try {
      reply = await _callGroq(prompt);
      reply ??= await _callOpenAI(prompt);
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
      setState(() => _adheeraReply = "Boss, network me thoda delay hua. Kripya dobara boliye.");
      await _speak("Boss, dobara boliye.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ADHEERA // COMPANION',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 17, color: Color(0xFF00E5FF)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _companionMode ? Icons.headset_mic : Icons.headset_off,
              color: _companionMode ? const Color(0xFF00E5FF) : Colors.white24,
            ),
            tooltip: "Auto-Companion Mode",
            onPressed: () {
              setState(() => _companionMode = !_companionMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, color: Color(0xFF00E5FF), size: 24),
            onPressed: () => _speak(_adheeraReply),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                _userText,
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ),

            const Spacer(),

            // 100% PERFECT ROUND DENSE RAINBOW ORB (Sphere Remains Round)
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) => SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: PerfectlyRoundRainbowOrbPainter(
                    animValue: _orbController.value,
                    isListening: _isListening,
                    isThinking: _isThinking,
                    isSpeaking: _isSpeaking,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              _isListening
                  ? "• LISTENING..."
                  : (_isThinking
                      ? "• THINKING..."
                      : (_isSpeaking ? "• ADHEERA SPEAKING..." : "• COMPANION READY •")),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: _isListening
                    ? const Color(0xFFFF5252)
                    : (_isThinking ? const Color(0xFF00E5FF) : (_isSpeaking ? const Color(0xFF00FF88) : Colors.white38)),
              ),
            ),

            const Spacer(),

            // Mic / Stop Button
            GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : const Color(0xFF00E5FF),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 42,
                  color: _isListening ? Colors.white : const Color(0xFF070B14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _companionMode
                  ? "Auto-Conversation ON (Hands-Free Talk)"
                  : "Tap Mic to Speak",
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

// 100% PERFECT ROUND RAINBOW ORB (Voice-responsive shimmer without distortion)
class DenseOrbPoint {
  final double x, y, z;
  final double hue;
  const DenseOrbPoint(this.x, this.y, this.z, this.hue);
}

class PerfectlyRoundRainbowOrbPainter extends CustomPainter {
  final double animValue;
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;

  static final List<DenseOrbPoint> _points = () {
    final list = <DenseOrbPoint>[];
    const count = 1200;
    const phi = 2.399963229728653;
    for (int i = 0; i < count; i++) {
      final y = 1.0 - (i / (count - 1.0)) * 2.0;
      final r = math.sqrt(math.max(0.0, 1.0 - y * y));
      final theta = phi * i;
      final x = math.cos(theta) * r;
      final z = math.sin(theta) * r;

      final angle = math.atan2(y, x);
      final normalizedHue = ((angle + math.pi) / (2 * math.pi) * 360.0);
      list.add(DenseOrbPoint(x, y, z, normalizedHue));
    }
    return list;
  }();

  PerfectlyRoundRainbowOrbPainter({
    required this.animValue,
    required this.isListening,
    required this.isThinking,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.44;

    double pulse = 1.0;
    double speed = 1.0;
    double colorSpeed = 60.0;

    if (isThinking) {
      speed = 3.6;
      colorSpeed = 160.0;
      pulse = 1.0 + 0.03 * math.sin(animValue * 14 * math.pi);
    } else if (isListening) {
      speed = 2.8;
      colorSpeed = 120.0;
      pulse = 1.0 + 0.04 * math.sin(animValue * 18 * math.pi);
    } else if (isSpeaking) {
      speed = 2.4;
      colorSpeed = 100.0;
      pulse = 1.0 + 0.03 * math.sin(animValue * 12 * math.pi);
    }

    final r = baseRadius * pulse; // Strictly spherical
    final rotY = animValue * 2 * math.pi * speed;
    final rotX = 0.15 * math.sin(animValue * 2 * math.pi);

    final cosY = math.cos(rotY), sinY = math.sin(rotY);
    final cosX = math.cos(rotX), sinX = math.sin(rotX);

    for (final pt in _points) {
      final x1 = pt.x * cosY - pt.z * sinY;
      final z1 = pt.x * sinY + pt.z * cosY;
      final y1 = pt.y * cosX - z1 * sinX;
      final z2 = pt.y * sinX + z1 * cosX;

      final sx = center.dx + x1 * r;
      final sy = center.dy + y1 * r;

      final depth = ((z2 + 1.1) / 2.2).clamp(0.15, 1.0);
      
      double dotRadius = 0.8 + depth * 1.3;
      if (isListening || isSpeaking) {
        dotRadius += 0.22 * math.sin(animValue * 22 + pt.x * 6);
      }

      final hue = (pt.hue + animValue * colorSpeed) % 360;
      final color = HSVColor.fromAHSV(
        (depth * 0.85 + 0.15).clamp(0.2, 1.0),
        hue,
        0.88,
        0.98,
      ).toColor();

      canvas.drawCircle(Offset(sx, sy), dotRadius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant PerfectlyRoundRainbowOrbPainter old) =>
      old.animValue != animValue ||
      old.isListening != isListening ||
      old.isThinking != isThinking ||
      old.isSpeaking != isSpeaking;
}
