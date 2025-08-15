import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ========================= COLORS =========================

  // Primary Colors - Changed from blue to yellow
  static const Color primaryColor = Color(0xFFFFC107); // Amber/Yellow
  static const Color primaryDark = Color(0xFFFF8F00); // Dark Amber
  static const Color primaryLight = Color(0xFFFFE082); // Light Amber

  // Secondary Colors
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFF81C784);

  // Accent Colors - Complementary to yellow
  static const Color accentColor =
      Color(0xFF673AB7); // Deep Purple (complementary)
  static const Color accentDark = Color(0xFF512DA8);
  static const Color accentLight = Color(0xFF9575CD);

  // Background Colors
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary =
      Color(0xFF000000); // Changed to black for better contrast on yellow

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFFFFC107); // Changed to yellow

  // Marketplace Specific Colors
  static const Color priceColor = Color(0xFF4CAF50);
  static const Color discountColor = Color(0xFFE91E63);
  static const Color donationColor = Color(0xFF9C27B0);
  static const Color soldColor = Color(0xFF757575);

  // Community Colors
  static const Color questionColor = Color(0xFF673AB7); // Changed to purple
  static const Color answerColor = Color(0xFF009688);
  static const Color upvoteColor = Color(0xFF4CAF50);
  static const Color downvoteColor = Color(0xFFF44336);

  // Chat Colors
  static const Color senderBubble = Color(0xFFFFC107); // Changed to yellow
  static const Color receiverBubble = Color(0xFFE0E0E0);
  static const Color onlineStatus = Color(0xFF4CAF50);
  static const Color offlineStatus = Color(0xFF757575);

  // ========================= GRADIENTS =========================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondaryColor, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========================= SHADOWS =========================

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryColor.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> appBarShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // ========================= BORDER RADIUS =========================

  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius =
      BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius =
      BorderRadius.all(Radius.circular(24));

  // ========================= SPACING =========================

  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ========================= MAIN THEME =========================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryLight,
        secondary: secondaryColor,
        secondaryContainer: secondaryLight,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: textPrimary,
        onError: textOnPrimary,
      ),

      // Typography
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        // Headlines
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),

        // Titles
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),

        // Body Text
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),

        // Labels
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textHint,
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: mediumRadius,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimary,
          elevation: 2,
          shadowColor: primaryColor.withOpacity(0.3),
          shape: const RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: mediumRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingS,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundColor,
        border: const OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: textHint),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: textHint),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: mediumRadius,
          borderSide: BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingM,
        ),
        hintStyle: GoogleFonts.poppins(
          color: textHint,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          color: textSecondary,
          fontSize: 14,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        selectedColor: primaryColor,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: smallRadius,
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: largeRadius,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: textSecondary,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: textHint,
        thickness: 0.5,
        space: 1,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),

      // Primary Icon Theme
      primaryIconTheme: const IconThemeData(
        color: primaryColor,
        size: 24,
      ),
    );
  }

  // ========================= CUSTOM STYLES =========================

  // Price Text Style
  static TextStyle priceTextStyle({double fontSize = 18}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: priceColor,
    );
  }

  // Discount Text Style
  static TextStyle discountTextStyle({double fontSize = 14}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: discountColor,
    );
  }

  // Status Text Style
  static TextStyle statusTextStyle(String status, {double fontSize = 12}) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = successColor;
        break;
      case 'sold':
        color = soldColor;
        break;
      case 'reserved':
        color = warningColor;
        break;
      default:
        color = textSecondary;
    }

    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  // University Tag Style
  static TextStyle universityTagStyle({double fontSize = 10}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: primaryColor,
    );
  }

  // Subject Tag Style
  static TextStyle subjectTagStyle({double fontSize = 10}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: secondaryColor,
    );
  }

  // ========================= SYSTEM UI OVERLAY STYLE =========================

  static const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}
