import 'package:flutter/material.dart';
//import 'widgets/mode_card.dart';
//import 'package:flutter_svg/flutter_svg.dart';
import 'lighting_modes_tab.dart';
import 'turn_signals_tab.dart';
import 'emergency_alarm_tab.dart';
import 'power_on_modes_tab.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Назви екранів
  final tabs = const [
    "Lighting modes",
    "Power-on modes",
    "Turn signals",
    "Emergency alarm",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0E2344),
              Color(0xFF093A6B),
              Color(0xFF04183A),
              Color(0xFF0A0A14),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ← Back + Title
              _buildTopBar(),

              // --- PageView with 4 categories ---
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: tabs.length,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                  },
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      // Lighting modes з анімацією
                      return const LightingModesTab();
                    }
                    if (index == 1) {
                      // Lighting modes з анімацією
                      return const PowerOnModesTab();
                    }
                    if (index == 2) {
                      // Lighting modes з анімацією
                      return const TurnSignalsTab();
                    }
                    if (index == 3) {
                      // Lighting modes з анімацією
                      return const EmergencyAlarmTab();
                    } else {
                      // поки що прості заглушки для решти трьох вкладок
                      return _buildCategoryPage(tabs[index]);
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // --- Dots indicator ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage == i ? 10 : 6,
                    height: _currentPage == i ? 10 : 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: const [
          BackButton(color: Colors.white),
          SizedBox(width: 10),
          Text(
            "Categories",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPage(String title) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // SUB-TAB TITLE
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        // --- Swipeable mode cards ---
        const SizedBox(height: 260, child: LightingModesTab()),

        const SizedBox(height: 20),
      ],
    );
  }
}
