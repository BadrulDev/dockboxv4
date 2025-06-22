import 'package:flutter/material.dart';

class StateController extends ChangeNotifier {
  int _selectedIndex = 0;
  String _username = "";
  String _password = "";
  bool _devSet = false;

  int get selectedIndex => _selectedIndex;
  String get username => _username;
  String get password => _password;
  bool get devSet => _devSet;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setUsername(String index) {
    _username = index;
    notifyListeners();
  }

  void setPassword(String index) {
    _password = index;

    notifyListeners();
  }

  void setDevSet(bool index) {
    _devSet = index;

    notifyListeners();
  }
}