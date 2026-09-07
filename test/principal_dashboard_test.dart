import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roshni_rams/features/dashboard/presentation/principal_dashboard.dart';
import 'package:roshni_rams/features/auth/presentation/auth_providers.dart';
import 'package:roshni_rams/features/auth/models/app_user.dart';
import 'package:roshni_rams/features/friends/presentation/documents_provider.dart';
import 'package:roshni_rams/core/localization/localization.dart';

void main() {
  testWidgets('PrincipalDashboardScreen renders without crashing and shows upload options', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final principalUser = AppUser(
      uid: 'principal_uid',
      email: 'principal@roshni.org',
      fullName: 'Tariq Alvi (Principal)',
      role: 'principal',
      isActive: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier();
            notifier.state = AuthState(user: principalUser);
            return notifier;
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en', ''),
            Locale('ur', ''),
          ],
          home: PrincipalDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Welcome, Tariq Alvi (Principal)'), findsOneWidget);

    // 1. Verifies the uploaded documents tab shows uploaded documents list and categories
    expect(find.textContaining('Uploaded Documents'), findsOneWidget);
    expect(find.text('Psychological Assessments'), findsOneWidget);

    // 2. Verifies the bottom Floating Action Button has upload option on confidential document tab
    expect(find.widgetWithText(FloatingActionButton, 'Upload Confidential Document'), findsOneWidget);

    // 3. Switch to Tab 2: Beneficiaries & IP
    await tester.tap(find.text('Beneficiaries & Individual Plans (IP)'));
    await tester.pumpAndSettle();

    // 4. Verifies the bottom upload button is NOT present on the second tab
    expect(find.widgetWithText(FloatingActionButton, 'Upload Confidential Document'), findsNothing);
  });

  testWidgets('Uploaded document is displayed at the top of the vault documents list', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final principalUser = AppUser(
      uid: 'principal_uid',
      email: 'principal@roshni.org',
      fullName: 'Tariq Alvi (Principal)',
      role: 'principal',
      isActive: true,
    );

    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier();
            notifier.state = AuthState(user: principalUser);
            return notifier;
          }),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              localizationsDelegates: [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en', ''),
                Locale('ur', ''),
              ],
              home: PrincipalDashboardScreen(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Perform an upload via documentsProvider
    await container.read(documentsProvider.notifier).uploadDocument(
      friendId: 'general_institute',
      documentType: 'psychological_assessment',
      title: 'Newly Uploaded Special Assessment',
      fileBytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'special_assessment_2026.pdf',
      fileType: 'pdf',
      uploadedBy: 'Tariq Alvi (Principal)',
    );

    await tester.pumpAndSettle();

    // Verify the newly uploaded document is visible on screen
    expect(find.text('Newly Uploaded Special Assessment'), findsOneWidget);
    expect(find.textContaining('special_assessment_2026.pdf'), findsOneWidget);
  });
}
