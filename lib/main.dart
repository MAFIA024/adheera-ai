import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
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
  late AudioPlayer _player;
  final Battery _battery = Battery();
  late AnimationController _orbCtrl;
  SharedPreferences? _prefs;

  final String _backendUrl = "https://adheera-backend2.vercel.app/api/chat";

  // ==============================================================
  // APNI ELEVENLABS KEY YAHAN PASTE KAREIN (LINE 35):
  final String _elevenLabsKey = "sk_cd8b6f68e954e965db548a7cdefbc8cf7be09b1ce8412e6e";
  // Adam Voice ID (Top-tier deep confident male voice):
  final String _voiceId = "pNInz6obpgDQGcFmaJgB";
  // ==============================================================

  bool _isSpeechInitialized = false;
  bool _isListening = false, _isThinking = false, _isSpeaking = false, _companion = false;
  String _userText = "Commands dene ke liye Mic dabayein...", _adheeraReply = "All systems online, Boss!";
  String _spokenWords = "";
  Map<String, String> _mem = {};

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
    "amazon": "in.amazon.mShop.android.shopping",
    "flipkart": "com.flipkart.android",
    "playstore": "com.android.vending",
    "gmail": "com.google.android.gm",
    "maps": "com.google.android.apps.maps",
    "dialer": "com.google.android.dialer",
    "phone": "com.google.android.dialer",
    "call": "com.google.android.dialer",
    "messages": "com.google.android.apps.messaging",
    "free fire": "com.dts.freefireth",
    "bgmi": "com.pubg.imobile",
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _player = AudioPlayer();
    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _initApp();
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs?.getString('adheera_mem');
    if (s != null) {
      try { _mem = Map<String, String>.from(jsonDecode(s)); } catch (_) {}
    }

    // Native fallback voice setup
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(0.82);
    await _tts.setSpeechRate(0.52);

    // Audio complete loop
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_companion) Future.delayed(const Duration(milliseconds: 400), () => !_isListening && !_isThinking ? _startListen() : null);
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_companion) Future.delayed(const Duration(milliseconds: 400), () => !_isListening && !_isThinking ? _startListen() : null);
      }
    });

    _initSpeechEngine();
    Future.delayed(const Duration(milliseconds: 800), () => _speak("All systems online, Boss! ElevenLabs human voice ready hai."));
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
        onError: (_) => mounted ? setState(() => _isListening = false) : null,
      );
    } catch (_) {}
  }

  Future<void> _saveMem(String k, String v) async {
    _mem[k.trim()] = v.trim();
    await _prefs?.setString('adheera_mem', jsonEncode(_mem));
  }

  // ELEVENLABS REAL HUMAN VOICE ENGINE (With Smart Native Fallback)
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    setState(() => _isSpeaking = true);

    bool playedElevenLabs = false;

    // 1. ElevenLabs Call
    if (_elevenLabsKey.isNotEmpty && !_elevenLabsKey.contains("YAHAN")) {
      try {
        final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId');
        final res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'xi-api-key': _elevenLabsKey.trim(),
          },
          body: jsonEncode({
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {
              "stability": 0.50,
              "similarity_boost": 0.80
            }
          }),
        ).timeout(const Duration(seconds: 7));

        if (res.statusCode == 200) {
          await _player.stop();
          await _player.play(BytesSource(res.bodyBytes));
          playedElevenLabs = true;
        }
      } catch (_) {}
    }

    // 2. Fallback to Native TTS if ElevenLabs has any issue or limit
    if (!playedElevenLabs) {
      await _tts.stop();
      await _tts.speak(text);
    }
  }

  Future<void> _startListen() async {
    if (_isSpeaking) {
      await _player.stop();
      await _tts.stop();
      setState(() => _isSpeaking = false);
    }
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

    // 3. Universal App Launcher
    for (String key in _appPackages.keys) {
      if (l.contains(key)) {
        bool launched = await _tryLaunchAppByName(key);
        if (launched) return;
      }
    }

    // 4. Backend AI Call
    await _askBackend(text);
  }

  Future<void> _askBackend(String prompt) async {
    setState(() => _isThinking = true);

    String memoryContext = _mem.isEmpty ? "None" : _mem.entries.map((e) => "${e.key}: ${e.value}").join(", ");

    try {
      final res = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"prompt": prompt, "memory": memoryContext}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        String reply = data['reply'] ?? "";

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

            // IRON MAN KINETIC ACTION ORB
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => SizedBox(
                width: 215,
                height: 215,
                child: CustomPaint(
                  painter: JarvisKineticOrbPainter(
                    anim: _orbCtrl.value,
                    listen: _isListening,
                    think: _isThinking,
                    speak: _isSpeaking,
                  ),
                ),
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

// IRON MAN JARVIS KINETIC ACTION ORB
class DensePoint {
  final double x, y, z, hue;
  const DensePoint(this.x, this.y, this.z, this.hue);
}

class JarvisKineticOrbPainter extends CustomPainter {
  final double anim;
  final bool listen, think, speak;

  static final List<DensePoint> _pts = List.generate(850, (i) {
    final y = 1.0 - (i / 849.0) * 2.0;
    final r = math.sqrt(math.max(0.0, 1.0 - y * y));
    final theta = 2.399963 * i;
    final x = math.cos(theta) * r, z = math.sin(theta) * r;
    return DensePoint(x, y, z, ((math.atan2(y, x) + math.pi) / (2 * math.pi) * 360));
  });

  JarvisKineticOrbPainter({required this.anim, required this.listen, required this.think, required this.speak});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.44;

    final bool active = listen || think || speak;
    final double spd = think ? 4.2 : (listen ? 3.4 : (speak ? 2.8 : 1.1));
    final double cSpd = active ? 150.0 : 55.0;
    final double pulse = 1.0 + (active ? 0.05 * math.sin(anim * 16 * math.pi) : 0.0);

    final double aY = anim * 2 * math.pi * spd;
    final double aX = 0.16 * math.sin(anim * 2 * math.pi);
    final cosY = math.cos(aY), sinY = math.sin(aY);
    final cosX = math.cos(aX), sinX = math.sin(aX);

    for (final p in _pts) {
      final x1 = p.x * cosY - p.z * sinY;
      final z1 = p.x * sinY + p.z * cosY;
      final y1 = p.y * cosX - z1 * sinX;
      final z2 = p.y * sinX + z1 * cosX;

      final double waveFreq = active ? (0.045 * math.sin(p.y * 10.0 - anim * 22.0)) : 0.0;
      final double r = baseR * (pulse + waveFreq);

      final sx = center.dx + x1 * r;
      final sy = center.dy + y1 * r;
      final depth = ((z2 + 1.15) / 2.3).clamp(0.12, 1.0);

      double dotR = 0.85 + depth * 1.35;
      if (active) {
        dotR += 0.35 * math.sin(anim * 28.0 + p.hue * 0.15);
      }

      final hue = (p.hue + anim * cSpd) % 360;
      final col = HSVColor.fromAHSV((depth * 0.88 + 0.12).clamp(0.2, 1.0), hue, 0.88, 0.98).toColor();

      canvas.drawCircle(Offset(sx, sy), dotR, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(covariant JarvisKineticOrbPainter old) => true;
}
