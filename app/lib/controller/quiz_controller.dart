import 'dart:async';
import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/iterable_utils.dart';
import 'package:papageno/utils/random_utils.dart';

final _log = Logger('QuizController');

/// Controller for the quiz page.
///
/// Conceptually, it's a list of questions, whose length may grow over time (though it's currently fixed).
/// The questions are generated on the fly to account for updated knowledge gained during the quiz.
/// 
/// Questions are generated in batches, where a batch cannot contain the same species more than once.
/// This prevents over-quizzing on a particular species.
class QuizController {
  /// Number of batches in a quiz.
  static const _questionBatchCount = 3;
  /// Size of a batch. Should be greater than the number of species unlocked at a time (currently 5),
  /// otherwise only new species will be asked at the start of a new quiz.
  static const _questionBatchSize = 2;
  static const _questionCount = _questionBatchCount * _questionBatchSize;
  static const _choiceCount = 4;

  final AppDb _appDb;
  final UserDb _userDb;
  final Course _course;
  final Random _random;

  final _quizUpdatesController = StreamController<Quiz>.broadcast();
  final _answersController = StreamController<_Answer>.broadcast();

  QuizController(AppDb appDb, UserDb userDb, Course course, {Random random}) :
      _appDb = appDb,
      _userDb = userDb,
      _course = course,
      _random = random ?? Random(DateTime.now().microsecondsSinceEpoch) {
    _run();
  }

  Stream<Quiz> get quizUpdates => _quizUpdatesController.stream;

  Future<void> _run() async {
    final questionCount = _questionCount;
    final questions = <Question>[];
    void notify() {
      _quizUpdatesController.add(Quiz(questionCount, questions.toBuiltList()));
    }
    var answerCount = 0;
    while (answerCount < questionCount) {
      if (answerCount >= questions.length) {
        final batch = await _generateQuestionBatch(_questionBatchSize);
        questions.addAll(batch);
        notify();
      }

      _Answer answer;
      try {
        answer = await _answersController.stream.first;
      } catch (e) {
        // Answer stream closed prematurely probably means that the controller was disposed.
        _log.info('_answersController closed ($e)');
        break;
      }

      if (answer.questionIndex >= questions.length) {
        _log.severe('Answer ${answer.species} given to question ${answer.questionIndex} which was not in the list');
      } else if (questions[answer.questionIndex].isAnswered) {
        _log.severe('Tried to answer question ${answer.questionIndex} with ${answer.species} while it already has an answer');
      } else {
        answerCount++;
        final answeredQuestion = questions[answer.questionIndex].answeredWith(answer.species, answer.timestamp);
        questions[answer.questionIndex] = answeredQuestion;
        await _storeAnswer(answeredQuestion);
        notify();
      }
    }
    _log.info('Closing _quizUpdatesController');
    await _quizUpdatesController.close();
  }

  void answerQuestion(int questionIndex, Species answer, DateTime answerTimestamp) {
    _answersController.add(_Answer(questionIndex, answer, answerTimestamp));
  }

  void dispose() {
    _log.fine('QuizController.dispose()');
    _answersController.close();
  }

  Future<void> _storeAnswer(Question question) async {
    assert(question.isAnswered);

    await _userDb.insertQuestion(_course.profileId, _course.courseId, question);
    final speciesKnowledge = await _userDb.speciesKnowledgeOrNull(_course.profileId, question.correctAnswer.speciesId);
    final newSpeciesKnowledge =
        speciesKnowledge?.update(correct: question.isCorrect, answerTimestamp: question.answerTimestamp) ??
            SpeciesKnowledge.initial(question.answerTimestamp);
    await _userDb.upsertSpeciesKnowledge(_course.profileId, question.correctAnswer.speciesId, newSpeciesKnowledge);
  }

  Future<List<Question>> _generateQuestionBatch(int count) async {
    final stopwatch = Stopwatch()..start();
    _log.fine('Generating new batch of questions');

    final now = DateTime.now();
    final allSpecies = _course.unlockedSpecies.toList();
    final knowledge = await _userDb.knowledge(_course.profileId);

    // Ask higher priority first.
    int byPriority(Species a, Species b) {
      final ka = knowledge.ofSpecies(a);
      final kb = knowledge.ofSpecies(b);
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
    final recordingsBags = <Species, RandomBag<Recording>>{};

    final questions = <Question>[];
    for (var i = 0; i < count; i++) {
      final correctAnswer = questionsBag.next();
      if (!recordingsBags.containsKey(correctAnswer)) {
        recordingsBags[correctAnswer] = RandomBag(await _appDb.recordingsFor(correctAnswer));
      }
      final recording = recordingsBags[correctAnswer].next(_random);
      final choices = <Species>[correctAnswer];
      while (choices.length < min(_choiceCount, allSpecies.length)) {
        final choice = answersBag.next(_random);
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

class _Answer {
  final int questionIndex;
  final Species species;
  final DateTime timestamp;

  _Answer(this.questionIndex, this.species, this.timestamp);
}