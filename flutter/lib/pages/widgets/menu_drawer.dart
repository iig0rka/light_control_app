import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../pages/base_menu_page.dart';

class MenuItem {
  final String title;
  final String iconPath;

  const MenuItem(this.title, String iconName)
    : iconPath = 'assets/svg/$iconName.svg';
}

const List<MenuItem> menuItems = [
  MenuItem('Categories', 'apps'),
  MenuItem('Latest', 'lastest'),
  MenuItem('Favorites', 'favorites'),
  MenuItem('Quick drive', 'quick_drive'),
  MenuItem('Connect device', 'connect_device'),
];

class StaggeredMenuListView extends StatefulWidget {
  final bool isMenuOpen;
  final VoidCallback toggleMenu;

  const StaggeredMenuListView({
    super.key,
    required this.isMenuOpen,
    required this.toggleMenu,
  });

  @override
  State<StaggeredMenuListView> createState() => _StaggeredMenuListViewState();
}

class _StaggeredMenuListViewState extends State<StaggeredMenuListView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(StaggeredMenuListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMenuOpen && !oldWidget.isMenuOpen) {
      _controller.forward(from: 0.0);
    } else if (!widget.isMenuOpen && oldWidget.isMenuOpen) {
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(menuItems.length, (index) {
        final interval = Interval(
          index * (1 / menuItems.length) * 0.5,
          0.8,
          curve: Curves.easeOut,
        );

        final animation = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: interval));

        final opacityAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _controller, curve: interval));

        return FadeTransition(
          opacity: opacityAnimation,
          child: SlideTransition(
            position: animation,
            child: MenuListTile(
              item: menuItems[index],
              toggleMenu: widget.toggleMenu,
            ),
          ),
        );
      }),
    );
  }
}

class MenuScreen extends StatelessWidget {
  final VoidCallback toggleMenu;
  final BoxDecoration decoration;
  final bool isMenuOpen;

  const MenuScreen({
    super.key,
    required this.toggleMenu,
    required this.decoration,
    required this.isMenuOpen,
  });

  Widget _buildCloseButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color.fromARGB(10, 225, 255, 255),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 30),
        onPressed: toggleMenu,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.only(top: 54, left: 20, right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildCloseButton()],
          ),
          const SizedBox(height: 50),
          StaggeredMenuListView(isMenuOpen: isMenuOpen, toggleMenu: toggleMenu),
          const Spacer(),
        ],
      ),
    );
  }
}

class MenuListTile extends StatelessWidget {
  final MenuItem item;
  final VoidCallback toggleMenu;

  const MenuListTile({super.key, required this.item, required this.toggleMenu});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      fontFamily: 'Noto Sans Telugu UI',
    );

    return ListTile(
      onTap: () {
        toggleMenu(); // ✅ закрили меню перед переходом
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MenuTargetScreens.getScreen(item.title),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      horizontalTitleGap: 13,
      leading: SvgPicture.asset(
        item.iconPath,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        width: 24,
        height: 24,
      ),
      title: Text(
        item.title,
        style: textStyle,
        strutStyle: const StrutStyle(height: 1.0, forceStrutHeight: true),
      ),
      minVerticalPadding: 12,
    );
  }
}
