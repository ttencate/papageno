import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/user_db.dart';
import 'package:pedantic/pedantic.dart';

final _log = Logger('KnowledgeController');

/// Controller for the [Knowledge] of a single [Profile].
///
/// It is kept in memory and updated synchronously, while database updates happen in the background.
class KnowledgeController {
  final Profile profile;
  Knowledge _knowledge;
  Future<Knowledge> _knowledgeFuture;

  final UserDb _userDb;

  final _knowledgeUpdatesController = StreamController<Knowledge>.broadcast();

  KnowledgeController({@required this.profile, @required UserDb userDb}) :
      _userDb = userDb
  {
    _knowledgeFuture = _load();
  }

  Future<Knowledge> _load() async {
    final knowledge = await _userDb.knowledge(profile.profileId);
    _notifyListeners(knowledge);
    return knowledge;
  }

  void dispose() {
    _knowledgeUpdatesController.close();
  }

  /// Current [Knowledge], or `null` if not yet loaded.
  Knowledge get knowledge => _knowledge;

  /// The latest [Knowledge]. Usually in a resolved state, unless updates are in progress.
  Future<Knowledge> get updatedKnowledge => _knowledgeFuture;

  /// Stream of all updates to the [Knowledge].
  Stream<Knowledge> get knowledgeUpdates => _knowledgeUpdatesController.stream;

  /// Updates the stored [Knowledge] with the answer to the given [Question].
  Future<Knowledge> updateSpeciesKnowledge(Question question) async {
    assert(question.isAnswered);
    _knowledgeFuture = _knowledgeFuture.then((knowledge) {
      _log.fine('Updating species knowledge after $question');

      var correctSpeciesKnowledge = knowledge.ofSpeciesOrNull(question.correctAnswer);
      var givenSpeciesKnowledge = knowledge.ofSpeciesOrNull(question.givenAnswer);

      final correct = question.isCorrect;
      // Only record the confusion on both sides if the user has heard at least one of these species before.
      final recordConfusion = !correct && (correctSpeciesKnowledge != null || givenSpeciesKnowledge != null);

      // Never heard before? Make sure to initialize so we can update the model.
      correctSpeciesKnowledge ??= SpeciesKnowledge.none();
      // If the species has been heard before but was answered correctly, record this as a confusion even though it
      // really isn't, to push out the real confusions eventually.
      if (correct && !correctSpeciesKnowledge.isNone) {
        correctSpeciesKnowledge = correctSpeciesKnowledge.withAddedConfusion(
            confusedWithspeciesId: question.givenAnswer.speciesId);
      }
      // The species has been asked, so we should update its model to reflect the newly gained knowledge.
      correctSpeciesKnowledge = correctSpeciesKnowledge.withUpdatedModel(
          correct: correct,
          answerTimestamp: question.answerTimestamp);
      if (!correct && givenSpeciesKnowledge?.isNone == false) {
        givenSpeciesKnowledge = givenSpeciesKnowledge.withUpdatedModel(
            correct: false,
            answerTimestamp: question.answerTimestamp,
            updateTimestamp: false);
      }
      if (recordConfusion) {
        correctSpeciesKnowledge = correctSpeciesKnowledge.withAddedConfusion(
            confusedWithspeciesId: question.givenAnswer.speciesId);
        givenSpeciesKnowledge ??= SpeciesKnowledge.none();
        givenSpeciesKnowledge = givenSpeciesKnowledge.withAddedConfusion(
            confusedWithspeciesId: question.correctAnswer.speciesId);
      }

      var newKnowledge = knowledge;
      if (correctSpeciesKnowledge != null) {
        newKnowledge = newKnowledge.updated(question.correctAnswer, correctSpeciesKnowledge);
        unawaited(_userDb.upsertSpeciesKnowledge(profile.profileId, question.correctAnswer.speciesId, correctSpeciesKnowledge));
      }
      if (!correct && givenSpeciesKnowledge != null) {
        newKnowledge = newKnowledge.updated(question.givenAnswer, givenSpeciesKnowledge);
        unawaited(_userDb.upsertSpeciesKnowledge(profile.profileId, question.givenAnswer.speciesId, givenSpeciesKnowledge));
      }

      _notifyListeners(newKnowledge);
      return newKnowledge;
    });
    return await _knowledgeFuture;
  }

  void _notifyListeners(Knowledge knowledge) {
    _knowledge = knowledge;
    _knowledgeUpdatesController.add(knowledge);
  }
}