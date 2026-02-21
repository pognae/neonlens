import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize(); // AdMob 초기화
  runApp(const NeonLensApp());
}

class NeonLensApp extends StatelessWidget {
  const NeonLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeonLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // 다크모드 배경
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainScannerScreen(),
    );
  }
}

class MainScannerScreen extends StatefulWidget {
  const MainScannerScreen({super.key});

  @override
  State<MainScannerScreen> createState() => _MainScannerScreenState();
}

class _MainScannerScreenState extends State<MainScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  // OCR 처리 로직
  Future<void> _processImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isProcessing = true);

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean); // 한글+영어 지원
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      textRecognizer.close();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (recognizedText.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('텍스트를 찾을 수 없습니다.')),
        );
        return;
      }

      // 결과 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(extractedText: recognizedText.text),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 네온 효과 (Glow Effect)
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8E2DE2).withOpacity(0.3),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8E2DE2).withOpacity(0.3), blurRadius: 100, spreadRadius: 100)
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 타이틀 (Gradient Text)
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4FACFE), Color(0xFF8E2DE2)],
                    ).createShader(bounds),
                    child: Text(
                      'NeonLens',
                      style: GoogleFonts.montserrat(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('빛의 속도로 텍스트를 스캔하세요', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 60),

                  // 메인 스캔 버튼 (Neon Button)
                  _isProcessing
                      ? const CircularProgressIndicator(color: Color(0xFF4FACFE))
                      : GestureDetector(
                          onTap: () => _showImageSourceActionSheet(context),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4FACFE), Color(0xFF8E2DE2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4FACFE).withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: const Icon(Icons.document_scanner, size: 60, color: Colors.white),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 카메라 or 갤러리 선택 팝업
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4FACFE)),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF8E2DE2)),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _processImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String extractedText;
  const ResultScreen({super.key, required this.extractedText});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TextEditingController _controller;
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // 테스트용 전면 광고 ID (안드로이드) - 출시 시 실제 ID로 변경 필수!
  final String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.extractedText);
    _loadInterstitialAd(); // 진입 시점에 광고 미리 로드 (심사 통과 및 UX 최적화 팁)
  }

  @override
  void dispose() {
    _controller.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('광고 로드 실패: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 텍스트 복사 및 광고 송출 후 홈으로 이동
  void _copyAndComplete() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    HapticFeedback.heavyImpact(); // 프리미엄 햅틱 피드백

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('텍스트가 복사되었습니다!'), backgroundColor: Color(0xFF8E2DE2)),
    );

    if (_isAdLoaded && _interstitialAd != null) {
      // 광고 닫힐 때 홈으로 돌아가기
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          Navigator.pop(context);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          Navigator.pop(context);
        },
      );
      _interstitialAd!.show();
    } else {
      // 광고 로드 안 됐으면 그냥 홈으로
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추출 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF4FACFE).withOpacity(0.5),
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8E2DE2).withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 복사하기 버튼 (Secondary Neon Gradient)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _copyAndComplete,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFC6767), Color(0xFFEC008C)], // 오렌지-핑크 네온
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      '텍스트 복사 및 완료',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}