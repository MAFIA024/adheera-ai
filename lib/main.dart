import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
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
  late FlutterTts _tts;

  bool _isListening = false;
  bool _isThinking = false;
  String _userText = "Mic par tap karke boliye...";
  String _adheeraReply = "Namaste! Main Adheera hoon. Main aapki kya madad kar sakti hoon?";

  // APNI NVIDIA KEY YAHAN DAALEIN:
  final String _nvidiaApiKey = "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";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initVoiceSettings();
  }

  Future<void> _initVoiceSettings() async {
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
  }

  Future<void> _speak(String text) async {
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

  // Pehle check karega ki koi direct command hai ya baat karni hai
  Future<void> _processCommand(String text) async {
    String lower = text.toLowerCase();

    // 1. YouTube Command
    if (lower.contains("youtube")) {
      setState(() => _adheeraReply = "YouTube open kar rahi hoon...");
      await _speak("YouTube open kar rahi hoon");
      final uri = Uri.parse("https://www.youtube.com");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 2. WhatsApp Command
    if (lower.contains("whatsapp")) {
      setState(() => _adheeraReply = "WhatsApp open kar rahi hoon...");
      await _speak("WhatsApp open kar rahi hoon");
      final uri = Uri.parse("whatsapp://send");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 3. Baaki baaton ke liye NVIDIA AI se poochega
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
              "content": "Aapka naam Adheera hai. Aap ek pyari, smart aur loyal personal AI assistant hain. User ke sawalon ka chhota, accurate aur sweet Hindi/Hinglish me jawab dein."
            },
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
          "max_tokens": 150,
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
          _adheeraReply = "Server Error (${response.statusCode}): ${response.body}";
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
                    _isThinking ? "Adheera soch rahi hai..." : _adheeraReply,
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
              _isListening ? "Sun rahi hoon..." : "Bolne ke liye Mic dabayein",
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
