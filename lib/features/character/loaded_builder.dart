import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'character_bloc.dart';

/// Rebuilds only when the character changes (not for notice-only states).
class LoadedBuilder extends StatelessWidget {
  const LoadedBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, CharacterLoaded state) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CharacterBloc, CharacterState>(
      buildWhen: (p, n) {
        if (p is CharacterLoaded && n is CharacterLoaded) {
          return p.character != n.character;
        }
        return true;
      },
      builder: (context, state) {
        if (state is CharacterLoaded) return builder(context, state);
        return const SizedBox.shrink();
      },
    );
  }
}
