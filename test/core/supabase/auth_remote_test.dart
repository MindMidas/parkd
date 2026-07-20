import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkd/core/supabase/auth_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late _MockSupabaseClient client;
  late _MockFunctionsClient functions;
  late _MockGoTrueClient auth;

  setUp(() {
    client = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    auth = _MockGoTrueClient();
    when(() => client.functions).thenReturn(functions);
    when(() => client.auth).thenReturn(auth);
  });

  test(
    'account deletion clears the local session after server success',
    () async {
      when(
        () => functions.invoke(
          'delete-account',
          body: const <String, dynamic>{'confirmation': 'DELETE'},
        ),
      ).thenAnswer((_) async => const FunctionResponse(status: 200));
      when(
        () => auth.signOut(scope: SignOutScope.local),
      ).thenAnswer((_) async {});

      await AuthRemote(client).deleteCurrentAccount();

      verify(() => auth.signOut(scope: SignOutScope.local)).called(1);
    },
  );

  test(
    'account deletion keeps the session when server deletion fails',
    () async {
      when(
        () => functions.invoke(
          'delete-account',
          body: const <String, dynamic>{'confirmation': 'DELETE'},
        ),
      ).thenAnswer(
        (_) async => const FunctionResponse(
          status: 500,
          data: <String, dynamic>{'error': 'Cleanup failed.'},
        ),
      );

      await expectLater(
        AuthRemote(client).deleteCurrentAccount(),
        throwsA(isA<AuthException>()),
      );
      verifyNever(() => auth.signOut(scope: SignOutScope.local));
    },
  );
}
