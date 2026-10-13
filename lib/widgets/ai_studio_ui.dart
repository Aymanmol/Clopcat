import 'package:flutter/material.dart';
import '../services/ai_studio_service.dart';

class AIStudioUI extends StatefulWidget {
  const AIStudioUI({Key? key}) : super(key: key);

  @override
  _AIStudioUIState createState() => _AIStudioUIState();
}

class _AIStudioUIState extends State<AIStudioUI> {
  final TextEditingController _promptController = TextEditingController();
  final AIStudioService _aiService = AIStudioService();
  bool _isLoading = false;
  String _generatedScript = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('AI Studio - استوديو الذكاء الاصطناعي', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اكتب وصفاً للفيديو لتوليد سيناريو ذكي:',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'مثال: فيديو إعلاني قصير لمتجر عطور بأسلوب مشوق...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    fillColor: const Color(0xFF1E1E1E),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                    icon: const Icon(Icons.psychology, color: Colors.white),
                    label: const Text('توليد السيناريو التلقائي', style: TextStyle(fontSize: 16, color: Colors.white)),
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      // محاكاة الاتصال الآمن بالـ API السحابي للخدمة
                      await Future.delayed(const Duration(seconds: 2));
                      setState(() {
                        _isLoading = false;
                        _generatedScript = "المشهد الأول: لقطة مقربة لزجاجة العطر وتتساقط عليها قطرات الماء.\nالمشهد الثاني: صوت تعليق فخم يتحدث عن الأصالة والجاذبية العربيّة.";
                      });
                    },
                  ),
                ),
                if (_generatedScript.isNotEmpty) ...[
                  const SizedBox(height: 25),
                  const Text('السيناريو المقترح:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                    child: Text(_generatedScript, style: const TextStyle(color: Colors.white, height: 1.5)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
