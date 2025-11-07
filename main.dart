import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ChinesePracticeApp());
}

class ChinesePracticeApp extends StatelessWidget {
  const ChinesePracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chinese Practice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const PracticePage(),
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  List<Map<String, String>> vocab = [];
  Map<String, String>? currentWord;
  String clueType = '';
  String clue = '';
  String correctAnswer = '';
  String feedback = '';
  bool hasSubmitted = false;
  bool isFinished = false;

  final TextEditingController controller = TextEditingController();
  final Map<TextEditingController, VoidCallback> _internalListeners = {};
  FocusNode? _autoFocusNode;

  int totalWords = 0;
  int correctCount = 0;
  int attemptedCount = 0;

  List<Map<String, String>> wrongAnswers = [];

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  /// Get the local file for caching
  Future<File> getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vocab.json');
  }

  /// Save JSON locally
  Future<void> saveJsonLocally(String jsonString) async {
    final file = await getLocalFile();
    await file.writeAsString(jsonString);
  }

  /// Read JSON from local cache
  Future<String?> readJsonFromLocal() async {
    try {
      final file = await getLocalFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  /// Load words from GitHub or fallback to local cache
  Future<void> loadWords() async {
    final url = Uri.parse(
        'https://raw.githubusercontent.com/Hekkta/LearnChinese/main/vocab.json'); 
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonString = response.body;
        await saveJsonLocally(jsonString);
        final List<dynamic> data = json.decode(jsonString);
        setState(() {
          vocab = data.map((e) => Map<String, String>.from(e)).toList();
          totalWords = vocab.length;
          correctCount = 0;
          attemptedCount = 0;
          wrongAnswers.clear();
          isFinished = false;
          nextQuestion();
        });
        return;
      }
    } catch (e) {
      print('Could not fetch from GitHub: $e');
    }

    // fallback to local cache
    final cached = await readJsonFromLocal();
    if (cached != null) {
      final List<dynamic> data = json.decode(cached);
      setState(() {
        vocab = data.map((e) => Map<String, String>.from(e)).toList();
        totalWords = vocab.length;
        correctCount = 0;
        attemptedCount = 0;
        wrongAnswers.clear();
        isFinished = false;
        nextQuestion();
      });
    } else {
      setState(() {
        isFinished = true;
        feedback = 'Could not load vocabulary. Check internet connection.';
      });
    }
  }

  void nextQuestion() {
    final random = Random();

    if (vocab.isEmpty) {
      setState(() {
        isFinished = true;
        clue = '';
        clueType = '';
        feedback = '';
        hasSubmitted = true;
        currentWord = null;
      });
      return;
    }

    final word = vocab[random.nextInt(vocab.length)];
    final choice = random.nextInt(2);

    setState(() {
      currentWord = word;
      feedback = '';
      hasSubmitted = false;
      controller.clear();

      if (choice == 0) {
        clueType = 'English';
        clue = word['english']!;
        correctAnswer = word['pinyin']!;
      } else {
        clueType = 'Chinese (Pinyin)';
        clue = word['pinyin']!;
        correctAnswer = word['english']!;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFocusNode?.requestFocus();
    });
  }

  void removeCurrentWord() {
    if (currentWord != null) {
      vocab.remove(currentWord);
    }
  }

  void checkAnswer(String input) {
    final user = input.trim().toLowerCase();
    final answer = correctAnswer.trim().toLowerCase();

    setState(() {
      hasSubmitted = true;
      attemptedCount++;

      if (user == answer) {
        correctCount++;
        feedback = '✅ Correct!';
      } else {
        feedback =
            '❌ Correct answer: ${currentWord!['english']} (${currentWord!['pinyin']} / ${currentWord!['hanzi']})';
        wrongAnswers.add(currentWord!);
      }
    });
  }

  /// Remove tone marks for autocomplete
  String normalizePinyin(String input) {
    const Map<String, String> toneMap = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
      'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
      'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
      'ǖ': 'ü', 'ǘ': 'ü', 'ǚ': 'ü', 'ǜ': 'ü',
    };
    return input
        .split('')
        .map((c) => toneMap[c] ?? c)
        .join()
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    if (vocab.isEmpty && currentWord == null && !isFinished) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chinese Practice - Results')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$correctCount/$attemptedCount correct',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '$totalWords total words',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Review Incorrect Words',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: wrongAnswers.isEmpty
                    ? const Center(
                        child: Text(
                          '🎉 Amazing! You got all words correct!',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: wrongAnswers.length,
                        itemBuilder: (context, index) {
                          final word = wrongAnswers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(
                                word['english']!,
                                style: const TextStyle(fontSize: 18),
                              ),
                              subtitle: Text(
                                word['pinyin']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: loadWords,
                child: const Text('Restart Practice'),
              ),
            ],
          ),
        ),
      );
    }

    final List<String> suggestions = (clueType == 'English')
        ? vocab.map((w) => w['pinyin']!).toList()
        : vocab.map((w) => w['english']!).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Chinese Practice')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$correctCount/$attemptedCount correct',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '$totalWords total words',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                clueType.isNotEmpty
                    ? 'What is the correct answer for this $clueType word?'
                    : '',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                clue,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue value) {
                  if (value.text.isEmpty) return const Iterable<String>.empty();
                  final input = normalizePinyin(value.text);
                  return suggestions.where(
                      (option) => normalizePinyin(option).startsWith(input));
                },
                fieldViewBuilder:
                    (context, textEditingController, focusNode, onSubmit) {
                  _autoFocusNode = focusNode;

                  if (controller.text.isEmpty &&
                      textEditingController.text.isNotEmpty) {
                    textEditingController.clear();
                  }

                  if (!_internalListeners.containsKey(textEditingController)) {
                    VoidCallback listener = () {
                      if (controller.text != textEditingController.text) {
                        controller.value = textEditingController.value;
                      }
                    };
                    textEditingController.addListener(listener);
                    _internalListeners[textEditingController] = listener;
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!hasSubmitted) focusNode.requestFocus();
                  });

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    enabled: !hasSubmitted,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type or select your answer',
                    ),
                    onSubmitted: (_) {
                      if (!hasSubmitted) {
                        checkAnswer(controller.text);
                      } else {
                        removeCurrentWord();
                        nextQuestion();
                      }
                    },
                  );
                },
                onSelected: (val) {
                  controller.text = val;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: hasSubmitted
                    ? () {
                        removeCurrentWord();
                        nextQuestion();
                      }
                    : () => checkAnswer(controller.text),
                child: Text(hasSubmitted ? 'Next' : 'Submit'),
              ),
              const SizedBox(height: 20),
              Text(
                feedback,
                style: TextStyle(
                  fontSize: 18,
                  color: feedback.startsWith('✅') ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final entry in _internalListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _internalListeners.clear();
    controller.dispose();
    super.dispose();
  }
}
