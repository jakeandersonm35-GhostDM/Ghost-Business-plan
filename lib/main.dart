import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import 'services/ai_service.dart';
import 'services/edge_tts_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GhostBusinessApp());
}

class GhostBusinessApp extends StatelessWidget {
  const GhostBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghost Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF6366F1),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E293B), elevation: 0),
      ),
      home: const GhostDashboard(),
    );
  }
}

class GhostDashboard extends StatefulWidget {
  const GhostDashboard({super.key});

  @override
  State<GhostDashboard> createState() => _GhostDashboardState();
}

class _GhostDashboardState extends State<GhostDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghost Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigoAccent,
          tabs: const [
            Tab(icon: Icon(Icons.web), text: "Web Agency"),
            Tab(icon: Icon(Icons.video_library), text: "Content Creator"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          WebAgencyTab(),
          ContentCreatorTab(),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: WEB AGENCY
// ==========================================
class WebAgencyTab extends StatefulWidget {
  const WebAgencyTab({super.key});

  @override
  State<WebAgencyTab> createState() => _WebAgencyTabState();
}

class _WebAgencyTabState extends State<WebAgencyTab> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _status = "Ready to build.";
  bool _isLoading = false;
  String? _generatedHtmlPath;
  WebViewController? _webViewController;

  Future<void> _contactMeOnWhatsApp(String message) async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    phone = phone.replaceAll(RegExp(r'[^0-9]'), ''); 
    final Uri whatsappUri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _status = "WhatsApp error.");
    }
  }

  Future<void> _buildWebsite(String businessType) async {
    setState(() {
      _isLoading = true;
      _status = "Ghost is writing code for: $businessType...";
      _generatedHtmlPath = null;
      _webViewController = null;
    });

    await EdgeTtsService.instance.speak("Right away sir. Drafting a website for the $businessType.");

    try {
      final htmlCode = await AiService.instance.generateResponse(
        "You are Ghost, an expert web developer. Write a complete, beautiful, single-file HTML/CSS website for a $businessType. Use modern styling. Do not include markdown formatting, just output raw HTML."
      );

      final cleanHtml = htmlCode.replaceAll('```html', '').replaceAll('```', '');
      final directory = await getApplicationDocumentsDirectory();
      final folder = Directory('${directory.path}/GhostWebsites/$businessType');
      await folder.create(recursive: true);
      final file = File('${folder.path}/index.html');
      await file.writeAsString(cleanHtml);

      setState(() {
        _generatedHtmlPath = file.path;
        _webViewController = WebViewController()..loadFile(file.path);
        _status = "Website built! Preview below.";
        _isLoading = false;
      });

      await EdgeTtsService.instance.speak("Website complete, sir.");
    } catch (e) {
      setState(() { _status = "Error: $e"; _isLoading = false; });
      await EdgeTtsService.instance.speak("I encountered an error, sir.");
    }
  }

  Future<void> _zipAndShare() async {
    if (_generatedHtmlPath == null) return;
    final file = File(_generatedHtmlPath!);
    final zipper = ZipFileEncoder();
    final zipPath = '${file.parent.path}/website.zip';
    zipper.create(zipPath);
    await zipper.addDirectory(file.parent);
    zipper.close();
    await Share.shareXFiles([XFile(zipPath)], text: 'Here is your new website preview!');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Your WhatsApp Number (e.g., 27821234567)",
              filled: true, fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            decoration: InputDecoration(
              labelText: "Client Business (e.g., Plumber in NY)",
              filled: true, fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () {
              if (_promptController.text.isNotEmpty) _buildWebsite(_promptController.text);
            },
            icon: const Icon(Icons.build),
            label: Text(_isLoading ? "Building..." : "Build Website"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: Colors.greenAccent), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          
          if (_webViewController != null) ...[
            SizedBox(
              height: 300,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                child: WebViewWidget(controller: _webViewController!),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _zipAndShare,
                    icon: const Icon(Icons.share),
                    label: const Text("Send Client"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _contactMeOnWhatsApp("Hey Boss, I just finished the website for '${_promptController.text}'.");
                    },
                    icon: const Icon(Icons.message),
                    label: const Text("WhatsApp Me"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: CONTENT CREATOR (YOUTUBE)
// ==========================================
class ContentCreatorTab extends StatefulWidget {
  const ContentCreatorTab({super.key});

  @override
  State<ContentCreatorTab> createState() => _ContentCreatorTabState();
}

class _ContentCreatorTabState extends State<ContentCreatorTab> {
  final TextEditingController _topicController = TextEditingController();
  String _generatedContent = "";
  bool _isLoading = false;

  Future<void> _generateContent(String topic) async {
    setState(() {
      _isLoading = true;
      _generatedContent = "";
    });

    await EdgeTtsService.instance.speak("Drafting your content strategy for $topic, sir.");

    try {
      final prompt = '''
      You are a YouTube Content Strategist. 
      Topic: $topic.
      Provide:
      1. A catchy Video Title.
      2. A 3-sentence Video Description.
      3. A brief 3-point script outline.
      Keep it professional and engaging.
      ''';
      
      final result = await AiService.instance.generateResponse(prompt);
      
      setState(() {
        _generatedContent = result;
        _isLoading = false;
      });

      await EdgeTtsService.instance.speak("Content generated, sir.");
    } catch (e) {
      setState(() {
        _generatedContent = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              labelText: "Video Topic (e.g., 'How to use AI in business')",
              filled: true, fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () {
              if (_topicController.text.isNotEmpty) _generateContent(_topicController.text);
            },
            icon: const Icon(Icons.video_call),
            label: Text(_isLoading ? "Writing..." : "Generate YouTube Content"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                child: Text(_generatedContent, style: const TextStyle(fontSize: 15, height: 1.5)),
              ),
            ),
          ),
          if (_generatedContent.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedContent));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard!")));
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy Content"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ]
        ],
      ),
    );
  }
}