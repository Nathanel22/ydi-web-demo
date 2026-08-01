import 'package:flutter/material.dart';

enum AppLanguage {
  german('de', 'Deutsch'),
  english('en', 'English'),
  french('fr', 'Français'),
  spanish('es', 'Español');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;
}

final languageNotifier = ValueNotifier<AppLanguage>(AppLanguage.german);

class AppText {
  const AppText(this.language);
  final AppLanguage language;

  String _pick(String de, String en, String fr, String es) =>
      switch (language) {
        AppLanguage.german => de,
        AppLanguage.english => en,
        AppLanguage.french => fr,
        AppLanguage.spanish => es,
      };

  String get digitalOverview => _pick(
    'Deine digitale Übersicht',
    'Your digital overview',
    'Votre aperçu numérique',
    'Tu resumen digital',
  );
  String get services => _pick('Dienste', 'Services', 'Services', 'Servicios');
  String get digitalServices => _pick(
    'Digitale Dienste',
    'Digital services',
    'Services numériques',
    'Servicios digitales',
  );
  String get newsletters =>
      _pick('Newsletter', 'Newsletters', 'Newsletters', 'Boletines');
  String get securityActivities => _pick(
    'Sicherheitsaktivitäten',
    'Security activity',
    'Activités de sécurité',
    'Actividad de seguridad',
  );
  String get unsubscribeLinks => _pick(
    'Abmeldelinks',
    'Unsubscribe links',
    'Liens de désabonnement',
    'Enlaces de baja',
  );
  String get duplicateRegistrations => _pick(
    'Doppelte Registrierungen',
    'Duplicate registrations',
    'Inscriptions en double',
    'Registros duplicados',
  );
  String get detectedAcrossAccounts => _pick(
    'Auf mehreren E-Mail-Konten erkannt',
    'Detected across multiple email accounts',
    'Détecté sur plusieurs comptes e-mail',
    'Detectado en varias cuentas de correo',
  );
  String get overview => _pick('Übersicht', 'Overview', 'Aperçu', 'Resumen');
  String get settings =>
      _pick('Einstellungen', 'Settings', 'Paramètres', 'Ajustes');
  String get languageSetting =>
      _pick('Sprache', 'Language', 'Langue', 'Idioma');
  String get mostFrequentServices => _pick(
    'Häufigste Dienste',
    'Most frequent services',
    'Services les plus fréquents',
    'Servicios más frecuentes',
  );
  String get showAll =>
      _pick('Alle anzeigen', 'Show all', 'Tout afficher', 'Ver todo');
  String get emailAccounts => _pick(
    'E-Mail-Konten',
    'Email accounts',
    'Comptes e-mail',
    'Cuentas de correo',
  );
  String get allEmailAccounts => _pick(
    'Alle E-Mail-Konten',
    'All email accounts',
    'Tous les comptes e-mail',
    'Todas las cuentas de correo',
  );
  String get chooseEmailAccount => _pick(
    'E-Mail-Konto auswählen',
    'Choose email account',
    'Choisir un compte e-mail',
    'Elegir cuenta de correo',
  );
  String get privacy =>
      _pick('Datenschutz', 'Privacy', 'Confidentialité', 'Privacidad');
  String get localAnalysis => _pick(
    'Lokale Analyse',
    'Local analysis',
    'Analyse locale',
    'Análisis local',
  );
  String get importScanResults => _pick(
    'Scan-Ergebnisse importieren',
    'Import scan results',
    'Importer les résultats du scan',
    'Importar resultados del análisis',
  );
  String get importScanDescription => _pick(
    'GMX- und Gmail-CSV lokal auswählen',
    'Select GMX and Gmail CSV files locally',
    'Sélectionner localement les CSV GMX et Gmail',
    'Seleccionar localmente los CSV de GMX y Gmail',
  );
  String get refreshScan => _pick(
    'Scan aktualisieren',
    'Refresh scan',
    'Actualiser le scan',
    'Actualizar análisis',
  );
  String get deleteLocalScanData => _pick(
    'Alle lokalen Scandaten löschen',
    'Delete all local scan data',
    'Supprimer toutes les données locales du scan',
    'Eliminar todos los datos locales del análisis',
  );
  String get noLocalScanData => _pick(
    'Keine importierten Daten gespeichert',
    'No imported data saved',
    'Aucune donnée importée enregistrée',
    'No hay datos importados guardados',
  );
  String localScanDataSummary(int accounts, int services) => _pick(
    '$accounts Konten · $services Dienste lokal gespeichert',
    '$accounts accounts · $services services saved locally',
    '$accounts comptes · $services services enregistrés localement',
    '$accounts cuentas · $services servicios guardados localmente',
  );
  String importSuccessful(int accounts, int services) => _pick(
    '$accounts Konten und $services Dienste importiert',
    '$accounts accounts and $services services imported',
    '$accounts comptes et $services services importés',
    '$accounts cuentas y $services servicios importados',
  );
  String get aboutYdi =>
      _pick('Über YDI', 'About YDI', 'À propos de YDI', 'Acerca de YDI');
  String get category =>
      _pick('Kategorie', 'Category', 'Catégorie', 'Categoría');
  String get allCategories => _pick(
    'Alle Kategorien',
    'All categories',
    'Toutes les catégories',
    'Todas las categorías',
  );
  String get sortBy =>
      _pick('Sortieren nach', 'Sort by', 'Trier par', 'Ordenar por');
  String get alphabetical =>
      _pick('Alphabetisch', 'Alphabetical', 'Alphabétique', 'Alfabético');
  String get byCategory =>
      _pick('Nach Kategorie', 'By category', 'Par catégorie', 'Por categoría');
  String servicesFound(int count) => _pick(
    '$count Dienste gefunden',
    '$count services found',
    '$count services trouvés',
    '$count servicios encontrados',
  );
  String get detectedEmails => _pick(
    'Erkannte E-Mails',
    'Detected emails',
    'E-mails détectés',
    'Correos detectados',
  );
  String get usedAccount => _pick(
    'Verwendetes Konto',
    'Account used',
    'Compte utilisé',
    'Cuenta utilizada',
  );

  String mails(int count) => _pick(
    '$count Mails',
    '$count emails',
    '$count e-mails',
    '$count correos',
  );

  String duplicateServicesFound(int count) {
    if (count == 1) {
      return _pick(
        '1 Dienst wurde auf mehreren E-Mail-Konten erkannt',
        '1 service was detected across multiple email accounts',
        '1 service a été détecté sur plusieurs comptes e-mail',
        'Se detectó 1 servicio en varias cuentas de correo',
      );
    }
    return _pick(
      '$count Dienste wurden auf mehreren E-Mail-Konten erkannt',
      '$count services were detected across multiple email accounts',
      '$count services ont été détectés sur plusieurs comptes e-mail',
      'Se detectaron $count servicios en varias cuentas de correo',
    );
  }

  String servicesAlphabetically(int count) => _pick(
    '$count Dienste · alphabetisch',
    '$count services · alphabetical',
    '$count services · ordre alphabétique',
    '$count servicios · orden alfabético',
  );

  String accountLabel(String account) =>
      account == 'Alle E-Mail-Konten' ? allEmailAccounts : account;

  String categoryLabel(String id) => switch (id) {
    'streaming' => 'Streaming',
    'real_estate' => _pick(
      'Immobilien',
      'Real estate',
      'Immobilier',
      'Inmobiliaria',
    ),
    'career' => _pick('Karriere', 'Career', 'Carrière', 'Empleo'),
    'technology' => _pick(
      'Technologie',
      'Technology',
      'Technologie',
      'Tecnología',
    ),
    'gaming' => 'Gaming',
    'shopping' => _pick('Shopping', 'Shopping', 'Achats', 'Compras'),
    'social_media' => _pick(
      'Social Media',
      'Social media',
      'Réseaux sociaux',
      'Redes sociales',
    ),
    'finance' => _pick('Finanzen', 'Finance', 'Finance', 'Finanzas'),
    'travel' => _pick('Reisen', 'Travel', 'Voyages', 'Viajes'),
    'vehicles' => _pick('Fahrzeuge', 'Vehicles', 'Véhicules', 'Vehículos'),
    'comparison' => _pick(
      'Vergleich',
      'Comparison',
      'Comparaison',
      'Comparación',
    ),
    'email' => _pick('E-Mail', 'Email', 'E-mail', 'Correo'),
    'shipping' => _pick('Versand', 'Shipping', 'Livraison', 'Envíos'),
    'betting' => _pick('Sportwetten', 'Betting', 'Paris sportifs', 'Apuestas'),
    'tickets' => _pick(
      'Tickets & Events',
      'Tickets & Events',
      'Billets & Événements',
      'Entradas y Eventos',
    ),
    'cloud' => 'Cloud',
    'smart_home' => 'Smart Home',
    'newsletter_system' => _pick(
      'Newsletter-System',
      'Newsletter system',
      'Système de newsletter',
      'Sistema de boletines',
    ),
    'health' => _pick('Gesundheit', 'Health', 'Santé', 'Salud'),
    'telecommunications' => _pick(
      'Telekommunikation',
      'Telecommunications',
      'Télécommunications',
      'Telecomunicaciones',
    ),
    'marketplace' => _pick(
      'Marktplatz',
      'Marketplace',
      'Marketplace',
      'Mercado',
    ),
    'productivity' => _pick(
      'Produktivität',
      'Productivity',
      'Productivité',
      'Productividad',
    ),
    'office_supplies' => _pick(
      'Bürobedarf',
      'Office supplies',
      'Fournitures de bureau',
      'Material de oficina',
    ),
    'surveys' => _pick('Umfragen', 'Surveys', 'Sondages', 'Encuestas'),
    'unknown' => _pick('Unbekannt', 'Unknown', 'Inconnu', 'Desconocido'),
    _ => _pick('Sonstiges', 'Other', 'Autre', 'Otros'),
  };
}
