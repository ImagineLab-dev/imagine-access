import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:imagine_access/features/tickets/data/ticket_repository.dart';

// ─── Mocks ──────────────────────────────────────────────
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockRef extends Mock implements Ref {}

void main() {
  late MockSupabaseClient mockClient;
  late MockFunctionsClient mockFunctions;
  late MockRef mockRef;
  late TicketRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();
    mockRef = MockRef();

    when(() => mockClient.functions).thenReturn(mockFunctions);
    repository = TicketRepository(mockClient, mockRef);
  });

  group('TicketRepository', () {
    group('createTicket', () {
      test('calls create_ticket edge function with correct body', () async {
        when(() => mockFunctions.invoke(
              'create_ticket',
              body: any(named: 'body'),
            )).thenAnswer((_) async => FunctionResponse(
              status: 200,
              data: {
                'ticket_id': 'tk-001',
                'status': 'created',
              },
            ));

        final result = await repository.createTicket(
          eventSlug: 'summer-party-2026',
          type: 'VIP',
          price: 150000.0,
          buyerName: 'Juan Pérez',
          buyerEmail: 'juan@test.com',
          buyerDoc: '12345678',
          buyerPhone: '+595981234567',
        );

        expect(result['ticket_id'], equals('tk-001'));
        expect(result['status'], equals('created'));

        verify(() => mockFunctions.invoke(
              'create_ticket',
              body: any(named: 'body'),
            )).called(1);
      });

      test('throws TicketException on non-200 response', () async {
        when(() => mockFunctions.invoke(
              'create_ticket',
              body: any(named: 'body'),
            )).thenAnswer((_) async => FunctionResponse(
              status: 400,
              data: 'Quota exceeded',
            ));

        expect(
          () => repository.createTicket(
            eventSlug: 'test-event',
            type: 'Standard',
            price: 50000.0,
            buyerName: 'Test',
            buyerEmail: 'test@test.com',
            buyerDoc: '99999999',
            buyerPhone: '+595900000000',
          ),
          throwsA(isA<TicketException>()),
        );
      });

      test('wraps unexpected errors in TicketException', () async {
        when(() => mockFunctions.invoke(
              'create_ticket',
              body: any(named: 'body'),
            )).thenThrow(Exception('Network timeout'));

        expect(
          () => repository.createTicket(
            eventSlug: 'test',
            type: 'Standard',
            price: 0,
            buyerName: 'Test',
            buyerEmail: 'test@test.com',
            buyerDoc: '00000000',
            buyerPhone: '+0',
          ),
          throwsA(isA<TicketException>()),
        );
      });
    });

    group('resendTicket', () {
      test('calls resend_ticket_email edge function', () async {
        when(() => mockFunctions.invoke(
              'resend_ticket_email',
              body: {'ticket_id': 'tk-001'},
            )).thenAnswer((_) async => FunctionResponse(
              status: 200,
              data: {'success': true},
            ));

        await repository.resendTicket('tk-001');

        verify(() => mockFunctions.invoke(
              'resend_ticket_email',
              body: {'ticket_id': 'tk-001'},
            )).called(1);
      });

      test('throws TicketException on failure', () async {
        when(() => mockFunctions.invoke(
              'resend_ticket_email',
              body: {'ticket_id': 'tk-001'},
            )).thenAnswer((_) async => FunctionResponse(
              status: 500,
              data: 'SMTP error',
            ));

        expect(
          () => repository.resendTicket('tk-001'),
          throwsA(isA<TicketException>()),
        );
      });
    });

    group('voidTicket', () {
      test('calls void_ticket edge function', () async {
        when(() => mockFunctions.invoke(
              'void_ticket',
              body: {'ticket_id': 'tk-002'},
            )).thenAnswer((_) async => FunctionResponse(
              status: 200,
              data: {'success': true},
            ));

        await repository.voidTicket('tk-002');

        verify(() => mockFunctions.invoke(
              'void_ticket',
              body: {'ticket_id': 'tk-002'},
            )).called(1);
      });

      test('throws TicketException on failure', () async {
        when(() => mockFunctions.invoke(
              'void_ticket',
              body: {'ticket_id': 'tk-002'},
            )).thenAnswer((_) async => FunctionResponse(
              status: 403,
              data: 'Not authorized',
            ));

        expect(
          () => repository.voidTicket('tk-002'),
          throwsA(isA<TicketException>()),
        );
      });

      test('wraps unexpected errors in TicketException', () async {
        when(() => mockFunctions.invoke(
              'void_ticket',
              body: {'ticket_id': 'tk-002'},
            )).thenThrow(Exception('Connection refused'));

        expect(
          () => repository.voidTicket('tk-002'),
          throwsA(isA<TicketException>()),
        );
      });
    });
  });
}
