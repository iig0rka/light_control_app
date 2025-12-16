import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/widgets/menu_drawer.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  bool _isMenuOpen = false;
  double _screenWidth = 0;
  double _screenHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double maxSlideW = _screenWidth * 0.78;
    final double maxSlideH = _screenHeight * 0.2;

    final double yOffset = _isMenuOpen ? maxSlideH : 0;
    final double xOffset = _isMenuOpen ? maxSlideW : 0;
    final double scaleFactor = _isMenuOpen ? 0.7 : 1.0;
    final double borderRadius = _isMenuOpen ? 40.0 : 0.0;

    const menuGradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A104E), Color(0xFF2B2356), Color(0xFF211A37)],
        stops: [0.0, 0.1, 0.86],
      ),
    );

    const homeGradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromARGB(255, 21, 24, 52),
          Color.fromARGB(255, 20, 97, 159),
          Color.fromARGB(255, 4, 9, 58),
          Color.fromARGB(255, 25, 25, 31),
        ],
        stops: [0, 0.35, 0.74, 1.0],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A104E),
      body: Stack(
        children: <Widget>[
          MenuScreen(
            toggleMenu: _toggleMenu,
            decoration: menuGradientDecoration,
            isMenuOpen: _isMenuOpen,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            transform: Matrix4.translationValues(xOffset, yOffset, 0)
              ..scale(scaleFactor),
            decoration: homeGradientDecoration.copyWith(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: GestureDetector(
              onTap: () {
                if (_isMenuOpen) _toggleMenu();
              },
              child: HomeScreen(
                toggleMenu: _toggleMenu,
                isMenuOpen: _isMenuOpen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
