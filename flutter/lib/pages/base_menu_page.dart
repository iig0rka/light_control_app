import 'package:flutter/material.dart';

import '../ble/require_device_bloc.dart';

// 🔧 підправ шляхи під твої файли
import 'category_pages.dart';
import 'latest_page.dart';
import 'favorites_page.dart';
import 'quick_drive_page.dart';
import 'connect_device_page.dart';

class MenuTargetScreens {
  static Widget getScreen(String title) {
    switch (title) {
      case 'Categories':
        return const RequireDeviceBloc(child: CategoriesPage());

      case 'Latest':
        return const LatestPage(); // якщо не треба BLE

      case 'Favorites':
        return const FavouritesPage(); // якщо не треба BLE

      case 'Quick drive':
        return const RequireDeviceBloc(child: QuickDriveScreen());

      case 'Connect device':
        return const ConnectDevicePage();

      default:
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              'Unknown screen: $title',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
    }
  }
}
