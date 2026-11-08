import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/models.dart';
import '../../domain/repository.dart';

class CharacterListState extends Equatable {
  const CharacterListState({
    this.characters = const [],
    this.loading = true,
    this.error,
  });
  final List<Character> characters;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [characters, loading, error];
}

/// Simple UI state, so a Cubit rather than a Bloc.
class CharacterListCubit extends Cubit<CharacterListState> {
  CharacterListCubit(this._repo) : super(const CharacterListState()) {
    _sub = _repo.watchAll().listen(
      (list) => emit(CharacterListState(characters: list, loading: false)),
      onError: (Object e) =>
          emit(CharacterListState(loading: false, error: '$e')),
    );
  }

  final CharacterRepository _repo;
  late final StreamSubscription<List<Character>> _sub;

  Future<Character> import(String json) => _repo.importJson(json);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
