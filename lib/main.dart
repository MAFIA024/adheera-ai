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
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: AdheeraScreen()));

class AdheeraScreen extends StatefulWidget {
  const AdheeraScreen({super.key});
  @override
  State<AdheeraScreen> createState() => _AdheeraScreenState();
}

class _AdheeraScreenState extends State<AdheeraScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final Battery _battery = Battery();
  late AnimationController _orbCtrl;
  SharedPreferences? _prefs;

  final String _backendUrl = "https://adheera-backend2.vercel.app/api/chat";

  bool _isSpeechInitialized = false;
  bool _isListening = false, _isThinking = false, _isSpeaking = false, _companion = false;
  String _userText = "Commands dene ke liye Mic dabayein...", _adheeraReply = "All systems online, Boss!";
  String _spokenWords = "";
  Map<String, String> _mem = {};

  // PHONE KI SABHI POPULAR APPS KA DATABASE
  final Map<String, String> _appPackages = {
    "whatsapp": "com.whatsapp",
    "youtube": "com.google.android.youtube",
    "instagram": "com.instagram.android",
    "insta": "com.instagram.android",
    "facebook": "com.facebook.katana",
    "chrome": "com.android.chrome",
    "browser": "com.android.chrome",
    "google": "com.google.android.googlequicksearchbox",
    "camera": "com.android.camera",
    "calculator": "com.google.android.calculator",
    "hisab": "com.google.android.calculator",
    "settings": "com.android.settings",
    "setting": "com.android.settings",
    "gallery": "com.google.android.apps.photos",
    "photos": "com.google.android.apps.photos",
    "photo": "com.google.android.apps.photos",
    "spotify": "com.spotify.music",
    "music": "com.spotify.music",
    "gana": "com.spotify.music",
    "telegram": "org.telegram.messenger",
    "snapchat": "com.snapchat.android",
    "snap": "com.snapchat.android",
    "paytm": "net.one97.paytm",
    "phonepe": "com.phonepe.app",
    "gpay": "com.google.android.apps.nbu.paisa.user",
    "google pay": "com.google.android.apps.nbu.paisa.user",
    "amazon": "in.amazon.mShop.android.shopping",
    "flipkart": "com.flipkart.android",
    "playstore": "com.android.vending",
    "play store": "com.android.vending",
    "gmail": "com.google.android.gm",
    "mail": "com.google.android.gm",
    "maps": "com.google.android.apps.maps",
    "map": "com.google.android.apps.maps",
    "clock": "com.google.android.deskclock",
    "alarm": "com.google.android.deskclock",
    "contacts": "com.google.android.contacts",
    "dialer": "com.google.android.dialer",
    "phone": "com.google.android.dialer",
    "call": "com.google.android.dialer",
    "messages": "com.google.android.apps.messaging",
    "message": "com.google.android.apps.messaging",
    "free fire": "com.dts.freefireth",
    "bgmi": "com.pubg.imobile",
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _initApp();
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs?.getString('adheera_mem');
    if (s != null) {
      try { _mem = Map<String, String>.from(jsonDecode(s)); } catch (_) {}
    }

    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82);
    await _tts.setSpeechRate(0.52);

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_companion) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!_isListening && !_isThinking) _startListen();
          });
        }
      }
    });
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _initSpeechEngine();
    Future.delayed(const Duration(milliseconds: 800), () => _speak("All systems online, Boss! Main ready hoon."));
  }

  Future<void> _initSpeechEngine() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if ((status == "done" || status == "notListening") && _isListening) {
            setState(() => _isListening = false);
            _trigger();
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {}
  }

  Future<void> _saveMem(String k, String v) async {
    _mem[k.trim()] = v.trim();
    await _prefs?.setString('adheera_mem', jsonEncode(_mem));
  }

  Future<void> _speak(String t) async {
    if (t.isEmpty) return;
    await _tts.stop();
    await _tts.speak(t);
  }

  Future<void> _startListen() async {
    if (_isSpeaking) await _tts.stop();
    if (!_isSpeechInitialized) await _initSpeechEngine();
    if (!_isSpeechInitialized) return;

    _spokenWords = "";
    setState(() {
      _isListening = true;
      _userText = "Sun raha hoon, boliye Boss...";
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenWords = result.recognizedWords;
            _userText = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
      );
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListen() async {
    setState(() => _isListening = false);
    await _speech.stop();
    _trigger();
  }

  void _trigger() {
    String finalCmd = _spokenWords.trim();
    if (finalCmd.isNotEmpty) {
      _agentAction(finalCmd);
    } else {
      setState(() => _userText = "Kuch sunai nahi diya, dobara boliye.");
    }
  }

  // UNIVERSAL APP LAUNCHER
  Future<bool> _tryLaunchAppByName(String appKey) async {
    String? pkg = _appPackages[appKey];
    if (pkg != null) {
      String msg = "$appKey open kar raha hoon, Boss.";
      setState(() => _adheeraReply = msg);
      await _speak(msg);
      try {
        await LaunchApp.openApp(androidPackageName: pkg, openStore: false);
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _agentAction(String text) async {
    String l = text.toLowerCase();

    // 1. Hardware Commands
    if (l.contains("torch on") || l.contains("flashlight on") || l.contains("light on") || l.contains("torch jalao")) {
      try { 
        await TorchLight.enableTorch(); 
        setState(() => _adheeraReply = "Flashlight on kar di, Boss.");
        await _speak("Flashlight on kar di, Boss."); 
      } catch (_) {}
      return;
    }
    if (l.contains("torch off") || l.contains("flashlight off") || l.contains("light off") || l.contains("torch band")) {
      try { 
        await TorchLight.disableTorch(); 
        setState(() => _adheeraReply = "Flashlight band kar di, Boss.");
        await _speak("Flashlight band kar di, Boss."); 
      } catch (_) {}
      return;
    }
    if (l.contains("battery") || l.contains("charging") || l.contains("charge kitna")) {
      try { 
        int lvl = await _battery.batteryLevel; 
        String msg = "Battery status $lvl percent hai, Boss.";
        setState(() => _adheeraReply = msg);
        await _speak(msg); 
      } catch (_) {}
      return;
    }

    // 2. Google Search
    if (l.startsWith("search") || l.contains("google search") || l.contains("search karo")) {
      String q = text.replaceAll(RegExp(r'(search|google search|search karo)', caseSensitive: false), '').trim();
      if (q.isNotEmpty) {
        setState(() => _adheeraReply = "Google par search kar raha hoon, Boss.");
        await _speak("Google par search kar raha hoon, Boss.");
        await launchUrl(Uri.parse("https://www.google.com/search?q=${Uri.encodeComponent(q)}"), mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 3. UNIVERSAL APPS CHECK: Database me check karega
    for (String key in _appPackages.keys) {
      if (l.contains(key)) {
        bool launched = await _tryLaunchAppByName(key);
        if (launched) return;
      }
    }

    // 4. Agar generic bole "open <xyz>" ya "<xyz> kholo"
    final openMatch = RegExp(r'(open|kholo|chalao)\s+([a-zA-Z0-9]+)').firstMatch(l);
    if (openMatch != null) {
      String target = openMatch.group(2) ?? "";
      if (target.isNotEmpty) {
        bool launched = await _tryLaunchAppByName(target);
        if (launched) return;
      }
    }

    // 5. Baaki sab baaton ke liye Vercel Server se poochega
    await _askBackend(text);
  }

  Future<void> _askBackend(String prompt) async {
    setState(() => _isThinking = true);

    String memoryContext = _mem.isEmpty
        ? "None"
        : _mem.entries.map((e) => "${e.key}: ${e.value}").join(", ");

    try {
      final res = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "prompt": prompt,
          "memory": memoryContext,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        String reply = data['reply'] ?? "";

        // Memory Auto-Save check
        final m = RegExp(r'\[MEM:\s*([^=]+)=([^\]]+)\]').firstMatch(reply);
        if (m != null) {
          await _saveMem(m.group(1)!, m.group(2)!);
          reply = reply.replaceAll(m.group(0)!, '').trim();
        }

        setState(() => _adheeraReply = reply.trim());
        await _speak(_adheeraReply);
      } else {
        setState(() => _adheeraReply = "Server Error (${res.statusCode})");
        await _speak("Boss, server me dikkat hui.");
      }
    } catch (_) {
      setState(() => _adheeraReply = "Boss, connection me thoda delay hua. Dobara boliye.");
      await _speak("Boss, connection delay hua. Dobara boliye.");
    } finally {
      setState(() => _isThinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text('ADHEERA // JARVIS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16, color: Color(0xFF00E5FF))),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_companion ? Icons.headset_mic : Icons.headset_off, color: _companion ? const Color(0xFF00E5FF) : Colors.white24),
            onPressed: () => setState(() => _companion = !_companion),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up, color: Color(0xFF00E5FF)),
            onPressed: () => _speak(_adheeraReply),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF101726), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
              child: Text(_userText, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
            const Spacer(),
            // 100% PERFECT ROUND DENSE RAINBOW ORB
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => SizedBox(
                width: 210,
                height: 210,
                child: CustomPaint(painter: CompactRoundOrbPainter(anim: _orbCtrl.value, listen: _isListening, think: _isThinking, speak: _isSpeaking)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isListening ? "• LISTENING..." : (_isThinking ? "• REASONING..." : (_isSpeaking ? "• SPEAKING..." : "• SYSTEM READY •")),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2, color: _isListening ? const Color(0xFFFF5252) : const Color(0xFF00E5FF)),
            ),
            const Spacer(),
            // STABLE MIC BUTTON
            GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopListen();
                } else {
                  _startListen();
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : const Color(0xFF00E5FF),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 40, color: _isListening ? Colors.white : const Color(0xFF070B14)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isListening ? "Bol kar dobara tap karein to SEND" : (_companion ? "Auto-Companion Mode ON" : "Tap Mic to Speak"),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

// 100% ROUND COMPACT ORB PAINTER
class DensePoint {
  final double x, y, z, hue;
  const DensePoint(this.x, this.y, this.z, this.hue);
}

class CompactRoundOrbPainter extends CustomPainter {
  final double anim;
  final bool listen, think, speak;

  static final List<DensePoint> _pts = List.generate(800, (i) {
    final y = 1.0 - (i / 799.0) * 2.0;
    final r = math.sqrt(math.max(0.0, 1.0 - y * y));
    final theta = 2.399963 * i;
    final x = math.cos(theta) * r, z = math.sin(theta) * r;
    return DensePoint(x, y, z, ((math.atan2(y, x) + math.pi) / (2 * math.pi) * 360));
  });

  CompactRoundOrbPainter({required this.anim, required this.listen, required this.think, required this.speak});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.44;
    final pulse = 1.0 + (listen ? 0.04 * math.sin(anim * 18 * math.pi) : (think ? 0.03 * math.sin(anim * 14 * math.pi) : 0.0));
    final r = baseR * pulse;
    final spd = think ? 3.6 : (listen ? 2.8 : 1.0);
    final cSpd = think ? 160.0 : (listen ? 120.0 : 60.0);
    final aY = anim * 2 * math.pi * spd, aX = 0.15 * math.sin(anim * 2 * math.pi);
    final cosY = math.cos(aY), sinY = math.sin(aY);
    final cosX = math.cos(aX), sinX = math.sin(aX);

    for (final p in _pts) {
      final x1 = p.x * cosY - p.z * sinY;
      final z1 = p.x * sinY + p.z * cosY;
      final y1 = p.y * cosX - z1 * sinX;
      final z2 = p.y * sinX + z1 * cosX;
      final depth = ((z2 + 1.1) / 2.2).clamp(0.15, 1.0);
      final dotR = 0.8 + depth * 1.3 + ((listen || speak) ? 0.2 * math.sin(anim * 22 + p.x * 6) : 0.0);
      final hue = (p.hue + anim * cSpd) % 360;
      final col = HSVColor.fromAHSV((depth * 0.85 + 0.15).clamp(0.2, 1.0), hue, 0.88, 0.98).toColor();
      canvas.drawCircle(Offset(center.dx + x1 * r, center.dy + y1 * r), dotR, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(covariant CompactRoundOrbPainter old) => true;
}
