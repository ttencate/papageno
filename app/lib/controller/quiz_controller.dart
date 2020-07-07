import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart';
import 'package:papageno/controller/knowledge_controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:papageno/utils/random_utils.dart';
import 'package:pedantic/pedantic.dart';

final _log = Logger('QuizController');

/// Controller for the quiz page.
///
/// Conceptually, it's a list of questions, whose length may grow over time (though it's currently fixed).
/// The questions are generated on the fly to account for updated knowledge gained during the quiz.
/// 
/// Questions are generated in batches, where a batch cannot contain the same species more than once.
/// This prevents over-quizzing on a particular species.
class QuizController {
  static const _choiceCount = 5;
  static const _maxConfusionChoices = 2;

  /// Number of batches in a quiz.
  final int questionBatchCount;
  /// Size of a batch. Should be greater than the number of species unlocked at a time (currently 5),
  /// otherwise only new species will be asked at the start of a new quiz.
  final int questionBatchSize;
  /// Total number of questions in the quiz.
  final int questionCount;

  final AppDb _appDb;
  final UserDb _userDb;
  final KnowledgeController _knowledgeController;
  final Course _course;
  final Random _random;

  final _questions = <Question>[];
  Future<void> _questionsFuture;
  var _answerCount = 0;
  final _recordingsBags = <Species, RandomBag<Recording>>{};

  final _quizUpdatesController = StreamController<Quiz>();

  QuizController(AppDb appDb, UserDb userDb, KnowledgeController knowledgeController, Course course, {Random random, this.questionBatchCount = 3, this.questionBatchSize = 8}) :
      _appDb = appDb,
      _userDb = userDb,
      _knowledgeController = knowledgeController,
      _course = course,
      _random = random ?? Random(DateTime.now().microsecondsSinceEpoch),
      questionCount = questionBatchCount * questionBatchSize
  {
    _ensureQuestions();
  }

  Stream<Quiz> get quizUpdates => _quizUpdatesController.stream;

  void answerQuestion(int questionIndex, Species givenAnswer, DateTime answerTimestamp) {
    if (questionIndex >= _questions.length) {
      _log.severe('Answer ${givenAnswer} given to question ${questionIndex} which was not in the list');
      return;
    }
    if (_questions[questionIndex].isAnswered) {
      _log.info('Tried to answer question ${questionIndex} with ${givenAnswer} while it already has an answer');
      return;
    }

    _answerCount++;
    final answeredQuestion = _questions[questionIndex].answeredWith(givenAnswer, answerTimestamp);
    _questions[questionIndex] = answeredQuestion;
    _notifyListeners();

    unawaited(_userDb.insertQuestion(_course.profileId, _course.courseId, answeredQuestion));
    unawaited(_knowledgeController.updateSpeciesKnowledge(answeredQuestion));
    unawaited(_ensureQuestions());
  }

  void dispose() {
    _log.fine('QuizController.dispose()');
    _quizUpdatesController.close();
  }

  Future<void> _ensureQuestions() async {
    if (_questionsFuture != null) {
      return;
    }
    if (_answerCount < questionCount && _answerCount >= _questions.length) {
      _questionsFuture = () async {
        final batch = await _generateQuestionBatch(min(questionBatchSize, questionCount - _answerCount));
        _questions.addAll(batch);
        _notifyListeners();
        _questionsFuture = null;
      }();
    }
  }

  void _notifyListeners() {
    _quizUpdatesController.add(Quiz(questionCount, _questions.toBuiltList()));
  }

  Future<List<Question>> _generateQuestionBatch(int count) async {
    final stopwatch = Stopwatch()..start();
    _log.fine('Generating new batch of questions');

    final now = DateTime.now();
    final allSpecies = _course.unlockedSpecies.toSet();
    final knowledge = await _knowledgeController.updatedKnowledge;

    // Ask higher priority first.
    int byPriority(Species a, Species b) {
      final ka = knowledge.ofSpeciesOrNone(a);
      final kb = knowledge.ofSpeciesOrNone(b);
      if (ka == null && kb == null) {
        return 0;
      } else if (ka == null) {
        return -1;
      } else if (kb == null) {
        return 1;
      } else {
        return -ka.priority(now).compareTo(kb.priority(now));
      }
    }

    final questionsBag = CyclicBag(allSpecies.sorted(byPriority));
    final answersBag = RandomBag(allSpecies);

    final questions = <Question>[];
    for (var i = 0; i < count; i++) {
      final correctAnswer = questionsBag.next();
      if (!_recordingsBags.containsKey(correctAnswer)) {
        _recordingsBags[correctAnswer] = RandomBag(await _appDb.recordingsFor(correctAnswer));
      }
      final recording = _recordingsBags[correctAnswer].next(_random);

      final speciesKnowledge = knowledge.ofSpeciesOrNone(correctAnswer);
      final confusions =
          // Make a copy because Future.wait returns an unmodifiable list.
          List.of(await Future.wait(speciesKnowledge.confusionSpeciesIds.map(_appDb.species)))
              ..retainWhere(allSpecies.contains);
      var remainingConfusionsCount = _maxConfusionChoices;
      final choices = <Species>[correctAnswer];
      while (choices.length < min(_choiceCount, allSpecies.length)) {
        Species choice;
        if (remainingConfusionsCount > 0 && confusions.isNotEmpty) {
          choice = confusions.randomElement(_random);
          confusions.removeWhere((species) => species == choice);
          remainingConfusionsCount--;
          _log.finer('Adding confusion answer: $choice');
        } else {
          choice = answersBag.next(_random);
        }
        assert(choice != null);
        if (!choices.contains(choice)) {
          choices.add(choice);
        }
      }
      choices.shuffle(_random);

      questions.add(Question(
        recording: recording,
        choices: choices,
        correctAnswer: correctAnswer,
      ));
    }
    questions.shuffle(_random);

    stopwatch.stop();
    _log.fine('Generated new batch of questions in ${stopwatch.elapsedMilliseconds} ms');
    return questions;
  }
}