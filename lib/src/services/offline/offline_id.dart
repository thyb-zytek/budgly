import 'dart:math';
class OfflineId {
  static final Random _random = Random();
  static String uuid() { final b=List<int>.generate(16, (_) => _random.nextInt(256)); b[6]=(b[6]&15)|64; b[8]=(b[8]&63)|128; final h=b.map((e)=>e.toRadixString(16).padLeft(2,'0')).join(); return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}'; }
}
