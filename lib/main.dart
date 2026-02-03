import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rps_app/Screen/MainScreen.dart';
import 'package:rps_app/l10n/app_localizations.dart';
import 'package:rps_app/providers/language_provider.dart';
import 'package:rps_app/providers/cart_notifier.dart';
import 'package:rps_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) {
          final notifier = CartNotifier();
          // initial load
          notifier.loadCount();
          return notifier;
        }),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'รุ่งประเสริฐเฟอร์นิเจอร์',
            theme: ThemeData(
              primarySwatch: MaterialColor(
                AppTheme.primaryColor.value,
                <int, Color>{
                  50: AppTheme.primaryColor.withOpacity(0.1),
                  100: AppTheme.primaryColor.withOpacity(0.2),
                  200: AppTheme.primaryColor.withOpacity(0.3),
                  300: AppTheme.primaryColor.withOpacity(0.4),
                  400: AppTheme.primaryColor.withOpacity(0.5),
                  500: AppTheme.primaryColor,
                  600: AppTheme.primaryColor.withOpacity(0.7),
                  700: AppTheme.primaryColor.withOpacity(0.8),
                  800: AppTheme.primaryColor.withOpacity(0.9),
                  900: AppTheme.primaryColor,
                },
              ),
              primaryColor: AppTheme.primaryColor,
              scaffoldBackgroundColor: AppTheme.backgroundColor,
              cardColor: AppTheme.cardColor,
              fontFamily: 'Kanit',
              appBarTheme: const AppBarTheme(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.primaryWhite,
                elevation: 0,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: AppTheme.textPrimaryColor),
                bodyMedium: TextStyle(color: AppTheme.textSecondaryColor),
                titleLarge: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            locale: languageProvider.currentLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}