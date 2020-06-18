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
  Future<void> updateSpeciesKnowledge(Question question) async {
    assert(question.isAnswered);
    _knowledgeFuture = _knowledgeFuture.then((knowledge) {
      _log.fine('Updating species knowledge after $question');
      final species = question.correctAnswer;
      final speciesKnowledge = knowledge.ofSpeciesOrNone(species);
      final newSpeciesKnowledge = speciesKnowledge.update(correct: question.isCorrect);
      final newKnowledge = knowledge.updated(species, newSpeciesKnowledge);
      unawaited(_userDb.upsertSpeciesKnowledge(profile.profileId, species.speciesId, newSpeciesKnowledge));
      _notifyListeners(newKnowledge);
      return newKnowledge;
    });
  }

  void _notifyListeners(Knowledge knowledge) {
    _knowledge = knowledge;
    _knowledgeUpdatesController.add(knowledge);
  }
}