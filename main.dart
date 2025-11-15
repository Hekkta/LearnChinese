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
  List<Map<String, dynamic>> vocab = [];
  List<Map<String, dynamic>> sessionList = [];
  Map<String, dynamic>? currentWord;
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
  int selectedWords = 0;
  int correctCount = 0;
  int attemptedCount = 0;

  List<Map<String, dynamic>> wrongAnswers = [];

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  Future<File> getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vocab.json');
  }

  Future<void> saveJsonLocally(String jsonString) async {
    final file = await getLocalFile();
    await file.writeAsString(jsonString);
  }

  Future<String?> readJsonFromLocal() async {
    try {
      final file = await getLocalFile();
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  Future<void> loadWords() async {
    List<Map<String, dynamic>> localData = [];

    // Load local JSON
    final cached = await readJsonFromLocal();
    if (cached != null) {
      final List<dynamic> data = json.decode(cached);
      localData = data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // Fetch from GitHub
    final url = Uri.parse(
        'https://raw.githubusercontent.com/Hekkta/LearnChinese/main/vocab.json');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> remoteData = json.decode(response.body);
        for (var word in remoteData) {
          bool exists = localData.any((w) =>
              w['pinyin'] == word['pinyin'] &&
              w['english'] == word['english']);
          if (!exists) {
            // New word: set streaks to 0
            localData.add({
              'pinyin': word['pinyin'],
              'english': word['english'],
              'hanzi': word['hanzi'],
              'correctStreakPinyin': 0,
              'correctStreakEnglish': 0,
            });
          }
        }
        await saveJsonLocally(json.encode(localData));
      }
    } catch (e) {
      print('Could not fetch from GitHub: $e');
    }

    setState(() {
      vocab = localData;
      totalWords = vocab.length;
      correctCount = 0;
      attemptedCount = 0;
      wrongAnswers.clear();
      isFinished = false;
      prepareSessionList();
      nextQuestion();
    });
  }

  void prepareSessionList() {
    final random = Random();
    sessionList = vocab.where((w) {
      // Include mastered words at 10% probability
      int streakPinyin = w['correctStreakPinyin'] ?? 0;
      int streakEnglish = w['correctStreakEnglish'] ?? 0;
      if (streakPinyin >= 10 && streakEnglish >= 10) {
        return random.nextDouble() < 0.1;
      }
      return true;
    }).toList();

    selectedWords = sessionList.length;
  }

  void nextQuestion() {
    if (sessionList.isEmpty) {
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

    final random = Random();
    final index = random.nextInt(sessionList.length);
    final choice = random.nextInt(2);
    final word = sessionList[index];

    sessionList.removeAt(index);

    setState(() {
      currentWord = word;
      feedback = '';
      hasSubmitted = false;

      // Clear both main controller and synced internal controllers
      controller.clear();
      for (var entry in _internalListeners.entries) {
        entry.key.clear();
      }

      if (choice == 0) {
        clueType = 'English';
        clue = word['english'];
        correctAnswer = word['pinyin'];
      } else {
        clueType = 'Chinese (Pinyin)';
        clue = word['pinyin'];
        correctAnswer = word['english'];
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFocusNode?.requestFocus();
    });
  }

  void checkAnswer(String input) async {
    final user = input.trim().toLowerCase();
    final answer = correctAnswer.trim().toLowerCase();
    bool isCorrect = user == answer;

    setState(() {
      hasSubmitted = true;
      attemptedCount++;

      if (isCorrect) {
        correctCount++;
        feedback = '✅ Correct!';

        if (clueType == 'English') {
          currentWord!['correctStreakPinyin'] =
              (currentWord!['correctStreakPinyin'] ?? 0) + 1;
        } else {
          currentWord!['correctStreakEnglish'] =
              (currentWord!['correctStreakEnglish'] ?? 0) + 1;
        }
      } else {
        feedback =
            '❌ Correct answer: ${currentWord!['english']} (${currentWord!['pinyin']} / ${currentWord!['hanzi']})';
        wrongAnswers.add(currentWord!);
        currentWord!['correctStreakPinyin'] = 0;
        currentWord!['correctStreakEnglish'] = 0;
      }
    });

    await saveJsonLocally(json.encode(vocab));
  }

  String normalizePinyin(String input) {
    const Map<String, String> toneMap = {
      'ā': 'a',
      'á': 'a',
      'ǎ': 'a',
      'à': 'a',
      'ē': 'e',
      'é': 'e',
      'ě': 'e',
      'è': 'e',
      'ī': 'i',
      'í': 'i',
      'ǐ': 'i',
      'ì': 'i',
      'ō': 'o',
      'ó': 'o',
      'ǒ': 'o',
      'ò': 'o',
      'ū': 'u',
      'ú': 'u',
      'ǔ': 'u',
      'ù': 'u',
      'ǖ': 'ü',
      'ǘ': 'ü',
      'ǚ': 'ü',
      'ǜ': 'ü',
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
                    '$selectedWords/$totalWords selected',
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
                              title: Text(word['english']!,
                                  style: const TextStyle(fontSize: 18)),
                              subtitle: Text(word['pinyin']!,
                                  style: const TextStyle(fontSize: 16)),
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

    // Build suggestions for autocomplete
    final List<String> suggestions = (clueType == 'English')
        ? vocab.map((w) => w['pinyin'].toString()).toList()
        : vocab.map((w) => w['english'].toString()).toList();

    final int streak = (clueType == 'English')
        ? (currentWord?['correctStreakPinyin'] as int? ?? 0)
        : (currentWord?['correctStreakEnglish'] as int? ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Chinese Practice')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // prevent overflow on phone
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
                      '$selectedWords/$totalWords selected',
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
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Word streak: $streak',
                  style:
                      const TextStyle(fontSize: 16, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue value) {
                    if (value.text.isEmpty)
                      return const Iterable<String>.empty();
                    final input = normalizePinyin(value.text);
                    return suggestions.where(
                        (option) => normalizePinyin(option).startsWith(input));
                  },
                  fieldViewBuilder:
                      (context, textEditingController, focusNode, onSubmit) {
                    _autoFocusNode = focusNode;

                    // Sync internal controller with main controller
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
                      ? nextQuestion
                      : () => checkAnswer(controller.text),
                  child: Text(hasSubmitted ? 'Next' : 'Submit'),
                ),
                const SizedBox(height: 20),
                Text(
                  feedback,
                  style: TextStyle(
                    fontSize: 18,
                    color: feedback.startsWith('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
