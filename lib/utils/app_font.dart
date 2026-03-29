import 'package:flutter/material.dart';

class FontFamily {
  static const String poppins = 'poppins';
}

class FontWeightCustom {
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight regular = FontWeight.w400;
}

class PoppinsTextStyle {
  static const TextStyle bold = TextStyle(
    fontFamily: FontFamily.poppins,
    fontWeight: FontWeightCustom.bold,
  );

  static const TextStyle semiBold = TextStyle(
    fontFamily: FontFamily.poppins,
    fontWeight: FontWeightCustom.semiBold,
  );

  static const TextStyle medium = TextStyle(
    fontFamily: FontFamily.poppins,
    fontWeight: FontWeightCustom.medium,
  );

  static const TextStyle regular = TextStyle(
    fontFamily: FontFamily.poppins,
    fontWeight: FontWeightCustom.regular,
  );

  static const TextStyle italic = TextStyle(
    fontFamily: FontFamily.poppins,
    fontStyle: FontStyle.italic,
  );
}
