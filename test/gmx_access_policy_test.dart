import 'package:flutter_test/flutter_test.dart';
import 'package:ydi_app/config/public_demo.dart';
import 'package:ydi_app/services/gmx_imap_scanner.dart';

void main() {
  test('Public Demo blockiert den echten GMX-Connector', () async {
    var clientCreated = false;
    final scanner = GmxImapScanner(
      accessPolicy: const RealGmxAccessPolicy(
        isPublicDemo: true,
        allowRealGmxTest: true,
      ),
      clientFactory: () {
        clientCreated = true;
        throw StateError('A client must not be created.');
      },
    );

    await expectLater(
      scanner.testConnection('demo@example.com', 'synthetic-password'),
      throwsStateError,
    );
    expect(clientCreated, isFalse);
  });

  test('GMX bleibt ohne explizite Testfreigabe blockiert', () async {
    var clientCreated = false;
    final scanner = GmxImapScanner(
      accessPolicy: const RealGmxAccessPolicy(
        isPublicDemo: false,
        allowRealGmxTest: false,
      ),
      clientFactory: () {
        clientCreated = true;
        throw StateError('A client must not be created.');
      },
    );

    await expectLater(
      scanner.testConnection('demo@example.com', 'synthetic-password'),
      throwsStateError,
    );
    expect(clientCreated, isFalse);
  });

  test('Der private Testscan ist gechunkt und auf Header begrenzt', () {
    expect(GmxImapScanner.maximumMessages, 5000);
    expect(GmxImapScanner.chunkSize, 250);
    expect(GmxImapScanner.headerFetchCriteria, contains('FROM'));
    expect(GmxImapScanner.headerFetchCriteria, contains('SUBJECT'));
    expect(GmxImapScanner.headerFetchCriteria, contains('LIST-UNSUBSCRIBE'));
    expect(GmxImapScanner.headerFetchCriteria, contains('LIST-ID'));
    expect(GmxImapScanner.headerFetchCriteria, isNot(contains('BODY[]')));
  });

  test('Die Public Demo behält ausschließlich ihr synthetisches Dataset', () {
    expect(publicDemoDataset.sourceFiles, ['YDI Web-Demo']);
    expect(publicDemoDataset.accounts, contains('GMX Demo'));
    expect(
      publicDemoDataset.accounts.any((account) => account.contains('@')),
      isFalse,
    );
  });
}
