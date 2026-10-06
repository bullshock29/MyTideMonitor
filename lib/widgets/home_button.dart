import 'package:flutter/material.dart';

/// A home icon for the app bar that always returns to the home screen,
/// however many screens deep the user is.
///
/// Put it in an AppBar's `actions:` on every screen except the home screen.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home),
      tooltip: 'Home',
      // The home screen is the first screen in the stack, so this closes
      // every screen on top of it.
      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
    );
  }
}
