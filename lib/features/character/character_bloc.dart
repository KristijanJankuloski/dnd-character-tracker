import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../domain/models.dart';
import '../../domain/repository.dart';
import '../../domain/rules.dart';
import 'character_event.dart';

/// One-off message for the UI (snackbar with Undo).
class Notice extends Equatable {
  const Notice(
    this.id,
    this.message, {
    this.warning = false,
    this.undoable = false,
  });
  final int id;
  final String message;
  final bool warning;
  final bool undoable;
  @override
  List<Object?> get props => [id];
}

sealed class CharacterState extends Equatable {
  const CharacterState();
  @override
  List<Object?> get props => [];
}

class CharacterLoading extends CharacterState {
  const CharacterLoading();
}

class CharacterMissing extends CharacterState {
  const CharacterMissing();
}

class CharacterLoaded extends CharacterState {
  CharacterLoaded(this.character, {this.notice})
    : stats = resolveStats(character);
  final Character character;
  final CharacterStats stats;
  final Notice? notice;

  @override
  List<Object?> get props => [character, notice];
}

class CharacterFailure extends CharacterState {
  const CharacterFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class CharacterBloc extends Bloc<CharacterEvent, CharacterState> {
  CharacterBloc({
    required CharacterRepository repository,
    required this.characterId,
  }) : _repo = repository,
       super(const CharacterLoading()) {
    on<CharacterStarted>(_onStarted, transformer: restartable());
    // Actions run one at a time so rapid taps never overwrite each other.
    on<CharacterAction>(_onEvent, transformer: sequential());
    add(const CharacterStarted());
  }

  final CharacterRepository _repo;
  final String characterId;
  Notice? _pending;
  int _noticeCounter = 0;
  Character? _latest;

  Future<void> _onStarted(
    CharacterStarted event,
    Emitter<CharacterState> emit,
  ) async {
    await emit.forEach<Character?>(
      _repo.watch(characterId),
      onData: (c) {
        if (c == null) return const CharacterMissing();
        _latest = c;
        final n = _pending;
        _pending = null;
        return CharacterLoaded(c, notice: n);
      },
      onError: (e, _) => CharacterFailure('$e'),
    );
  }

  Future<void> _onEvent(
    CharacterAction event,
    Emitter<CharacterState> emit,
  ) async {
    final current = _latest;
    if (current == null) return;
    try {
      if (event is UndoRequested) {
        final undone = await _repo.undoLast(characterId);
        // Later events must build on the restored character, not the
        // snapshot from before the undo.
        _latest = await _repo.get(characterId) ?? _latest;
        _pending = Notice(
          ++_noticeCounter,
          undone == null ? 'Nothing to undo' : 'Undid: $undone',
        );
        if (undone == null) _flushPending(emit);
        return;
      }
      final result = event.run(current);
      if (result.blocked) {
        _pending = Notice(++_noticeCounter, result.description, warning: true);
        _flushPending(emit);
        return;
      }
      final message = [result.description, ...result.warnings].join('\n');
      _pending = Notice(
        ++_noticeCounter,
        message,
        warning: result.warnings.isNotEmpty,
        undoable: event.logged,
      );
      if (event.logged) {
        await _repo.apply(
          before: current,
          after: result.character,
          type: event.runtimeType.toString(),
          description: result.description,
        );
        // The repository stream may not have re-emitted yet; the next queued
        // event must build on this result, not on the stale snapshot.
        _latest = result.character;
      } else {
        _pending = null;
        await _repo.save(result.character);
        _latest = result.character;
      }
    } catch (e) {
      _pending = null;
      emit(CharacterFailure('$e'));
    }
  }

  void _flushPending(Emitter<CharacterState> emit) {
    final c = _latest;
    if (c == null) return;
    final n = _pending;
    _pending = null;
    emit(CharacterLoaded(c, notice: n));
  }
}
