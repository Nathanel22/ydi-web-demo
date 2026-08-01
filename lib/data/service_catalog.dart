import '../models/service_category.dart';
import '../models/scan_dataset.dart';
import '../models/service_item.dart';

class ServiceCatalogEntry {
  const ServiceCatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.domains,
  });

  final String id;
  final String name;
  final ServiceCategory category;
  final List<String> domains;
}

/// Curated offline catalog. Entries are researched before being shipped.
/// Looking up an unknown sender is deliberately not done from the user's app.
abstract final class ServiceCatalog {
  static const entries = <ServiceCatalogEntry>[
    ServiceCatalogEntry(
      id: 'activ_fitness',
      name: 'ACTIV FITNESS',
      category: ServiceCategory.health,
      domains: ['activfitness.ch'],
    ),
    ServiceCatalogEntry(
      id: 'asian_beauty_wholesale',
      name: 'AsianBeautyWholesale',
      category: ServiceCategory.shopping,
      domains: ['asianbeautywholesale.com'],
    ),
    ServiceCatalogEntry(
      id: 'axa',
      name: 'AXA',
      category: ServiceCategory.insurance,
      domains: ['axa.ch'],
    ),
    ServiceCatalogEntry(
      id: 'bitget',
      name: 'Bitget',
      category: ServiceCategory.finance,
      domains: ['bitget.com'],
    ),
    ServiceCatalogEntry(
      id: 'coople',
      name: 'Coople',
      category: ServiceCategory.career,
      domains: ['coople.com'],
    ),
    ServiceCatalogEntry(
      id: 'css',
      name: 'CSS',
      category: ServiceCategory.insurance,
      domains: ['css.ch'],
    ),
    ServiceCatalogEntry(
      id: 'degiro',
      name: 'DEGIRO',
      category: ServiceCategory.finance,
      domains: ['degiro.com', 'degiro.ch'],
    ),
    ServiceCatalogEntry(
      id: 'digitec',
      name: 'Digitec',
      category: ServiceCategory.shopping,
      domains: ['digitec.ch'],
    ),
    ServiceCatalogEntry(
      id: 'dr_hager',
      name: 'DR. HAGER',
      category: ServiceCategory.health,
      domains: ['drhager.com'],
    ),
    ServiceCatalogEntry(
      id: 'dyson',
      name: 'Dyson',
      category: ServiceCategory.shopping,
      domains: ['dyson.ch', 'dyson.com'],
    ),
    ServiceCatalogEntry(
      id: 'audi',
      name: 'Audi',
      category: ServiceCategory.vehicles,
      domains: ['ecom.audi', 'audi.com', 'audi.ch'],
    ),
    ServiceCatalogEntry(
      id: 'galaxus',
      name: 'Galaxus',
      category: ServiceCategory.shopping,
      domains: ['galaxus.ch', 'galaxus.com', 'galaxus.de'],
    ),
    ServiceCatalogEntry(
      id: 'gmx',
      name: 'GMX',
      category: ServiceCategory.email,
      domains: ['gmx.net', 'gmx.de', 'gmx.com', 'gmxnet.de'],
    ),
    ServiceCatalogEntry(
      id: 'sparkasse',
      name: 'Sparkasse',
      category: ServiceCategory.finance,
      domains: ['s-abmil.de'],
    ),
    ServiceCatalogEntry(
      id: 'just_eat',
      name: 'Just Eat',
      category: ServiceCategory.foodDelivery,
      domains: ['just-eat.ch'],
    ),
    ServiceCatalogEntry(
      id: 'main_echo',
      name: 'Main-Echo',
      category: ServiceCategory.news,
      domains: ['main-echo.de'],
    ),
    ServiceCatalogEntry(
      id: 'meta',
      name: 'Meta',
      category: ServiceCategory.socialMedia,
      domains: ['meta.com'],
    ),
    ServiceCatalogEntry(
      id: 'facebook',
      name: 'Facebook',
      category: ServiceCategory.socialMedia,
      domains: ['facebook.com', 'facebookmail.com'],
    ),
    ServiceCatalogEntry(
      id: 'aternos',
      name: 'Aternos',
      category: ServiceCategory.gaming,
      domains: ['aternos.org'],
    ),
    ServiceCatalogEntry(
      id: 'edwin',
      name: 'EDWIN',
      category: ServiceCategory.shopping,
      domains: ['edwin-europe.com'],
    ),
    ServiceCatalogEntry(
      id: 'fivem',
      name: 'FiveM',
      category: ServiceCategory.gaming,
      domains: ['fivem.net'],
    ),
    ServiceCatalogEntry(
      id: 'io_interactive',
      name: 'IO Interactive',
      category: ServiceCategory.gaming,
      domains: ['ioi.dk'],
    ),
    ServiceCatalogEntry(
      id: 'honey',
      name: 'Honey',
      category: ServiceCategory.shopping,
      domains: ['joinhoney.com'],
    ),
    ServiceCatalogEntry(
      id: 'carly',
      name: 'Carly',
      category: ServiceCategory.vehicles,
      domains: ['mycarly.com'],
    ),
    ServiceCatalogEntry(
      id: 'n1_bet',
      name: 'N1 Bet',
      category: ServiceCategory.betting,
      domains: ['n1bet.com'],
    ),
    ServiceCatalogEntry(
      id: 'odd_muse',
      name: 'Odd Muse',
      category: ServiceCategory.shopping,
      domains: ['oddmuse.co.uk'],
    ),
    ServiceCatalogEntry(
      id: 'mulefactory',
      name: 'MuleFactory',
      category: ServiceCategory.gaming,
      domains: ['mulefactory.com'],
    ),
    ServiceCatalogEntry(
      id: 'pc_welt',
      name: 'PC-WELT',
      category: ServiceCategory.news,
      domains: ['pcwelt.de'],
    ),
    ServiceCatalogEntry(
      id: 'proton',
      name: 'Proton',
      category: ServiceCategory.email,
      domains: ['proton.me', 'protonmail.com', 'protonmail.ch'],
    ),
    ServiceCatalogEntry(
      id: 'snapchat',
      name: 'Snapchat',
      category: ServiceCategory.socialMedia,
      domains: ['snapchat.com', 'snap.com'],
    ),
    ServiceCatalogEntry(
      id: 'sweatcoin',
      name: 'Sweatcoin',
      category: ServiceCategory.health,
      domains: ['sweatco.in'],
    ),
    ServiceCatalogEntry(
      id: 'youtube',
      name: 'YouTube',
      category: ServiceCategory.streaming,
      domains: ['youtube.com'],
    ),
    ServiceCatalogEntry(
      id: 'samsung',
      name: 'Samsung',
      category: ServiceCategory.technology,
      domains: ['samsung-mail.com', 'samsung.com'],
    ),
    ServiceCatalogEntry(
      id: 'swisslos',
      name: 'Swisslos',
      category: ServiceCategory.betting,
      domains: ['swisslos.ch'],
    ),
    ServiceCatalogEntry(
      id: 'swisscom',
      name: 'Swisscom',
      category: ServiceCategory.telecommunications,
      domains: ['swisscom.com', 'swisscom.ch'],
    ),
    ServiceCatalogEntry(
      id: 'opodo',
      name: 'Opodo',
      category: ServiceCategory.travel,
      domains: ['opodo.com'],
    ),
    ServiceCatalogEntry(
      id: 'shisha_heaven',
      name: 'Shisha Heaven',
      category: ServiceCategory.shopping,
      domains: ['shisha-heaven.ch'],
    ),
    ServiceCatalogEntry(
      id: 'autoscout24',
      name: 'AutoScout24',
      category: ServiceCategory.vehicles,
      domains: ['autoscout24.ch', 'autoscout24.de'],
    ),
    ServiceCatalogEntry(
      id: 'tommy_hilfiger',
      name: 'Tommy Hilfiger',
      category: ServiceCategory.shopping,
      domains: ['tommy.com'],
    ),
    ServiceCatalogEntry(
      id: 'tutti',
      name: 'tutti.ch',
      category: ServiceCategory.marketplace,
      domains: ['tutti.ch'],
    ),
    ServiceCatalogEntry(
      id: 'carvertical',
      name: 'carVertical',
      category: ServiceCategory.vehicles,
      domains: ['carvertical.com'],
    ),
    ServiceCatalogEntry(
      id: 'amazon',
      name: 'Amazon',
      category: ServiceCategory.shopping,
      domains: ['amazon.de', 'amazon.com', 'amazon.ch'],
    ),
    ServiceCatalogEntry(
      id: 'paypal',
      name: 'PayPal',
      category: ServiceCategory.finance,
      domains: ['paypal.ch', 'paypal.com', 'paypal.de'],
    ),
    ServiceCatalogEntry(
      id: 'mobilezone',
      name: 'mobilezone',
      category: ServiceCategory.telecommunications,
      domains: ['mobilezone.ch'],
    ),
    ServiceCatalogEntry(
      id: 'air_europa',
      name: 'Air Europa',
      category: ServiceCategory.travel,
      domains: ['aireuropa.com', 'aireuropanews.com'],
    ),
    ServiceCatalogEntry(
      id: 'revolut',
      name: 'Revolut',
      category: ServiceCategory.finance,
      domains: ['revolut.com'],
    ),
    ServiceCatalogEntry(
      id: 'virgin_hotels',
      name: 'Virgin Hotels',
      category: ServiceCategory.travel,
      domains: ['virginhotels.com', 'virginhotelslv.com'],
    ),
    ServiceCatalogEntry(
      id: 'mankido',
      name: 'Mankido',
      category: ServiceCategory.productivity,
      domains: ['mankido.de'],
    ),
    ServiceCatalogEntry(
      id: 'edeka',
      name: 'EDEKA',
      category: ServiceCategory.shopping,
      domains: ['edeka.de'],
    ),
    ServiceCatalogEntry(
      id: 'trink_jello',
      name: 'JELLO',
      category: ServiceCategory.shopping,
      domains: ['trinkjello.com'],
    ),
    ServiceCatalogEntry(
      id: 'delizio',
      name: 'Delizio',
      category: ServiceCategory.shopping,
      domains: ['delizio.ch'],
    ),
    ServiceCatalogEntry(
      id: 'ab_in_den_urlaub',
      name: 'Ab-in-den-Urlaub',
      category: ServiceCategory.travel,
      domains: ['ab-in-den-urlaub.ch', 'ab-in-den-urlaub.de'],
    ),
    ServiceCatalogEntry(
      id: 'myfritz',
      name: 'MyFRITZ!',
      category: ServiceCategory.technology,
      domains: ['myfritz.net'],
    ),
    ServiceCatalogEntry(
      id: 'migros',
      name: 'Migros',
      category: ServiceCategory.shopping,
      domains: ['migros.ch'],
    ),
    ServiceCatalogEntry(
      id: 'empfohlen_de',
      name: 'empfohlen.de',
      category: ServiceCategory.surveys,
      domains: ['empfohlen.de'],
    ),
    ServiceCatalogEntry(
      id: 'swiss_post',
      name: 'Die Post',
      category: ServiceCategory.shipping,
      domains: ['post.ch'],
    ),
    ServiceCatalogEntry(
      id: 'ricardo',
      name: 'Ricardo',
      category: ServiceCategory.marketplace,
      domains: ['ricardo.ch'],
    ),
    ServiceCatalogEntry(
      id: 'ticketino',
      name: 'Ticketino',
      category: ServiceCategory.tickets,
      domains: ['ticketino.com'],
    ),
    ServiceCatalogEntry(
      id: 'elvia',
      name: 'ELVIA',
      category: ServiceCategory.insurance,
      domains: ['elvia.ch'],
    ),
    ServiceCatalogEntry(
      id: 'apple',
      name: 'Apple',
      category: ServiceCategory.technology,
      domains: ['apple.com', 'appleid.com'],
    ),
    ServiceCatalogEntry(
      id: 'dhl',
      name: 'DHL',
      category: ServiceCategory.shipping,
      domains: ['dhl.de', 'dhl.com'],
    ),
    ServiceCatalogEntry(
      id: 'amag',
      name: 'AMAG',
      category: ServiceCategory.vehicles,
      domains: ['amag.ch'],
    ),
    ServiceCatalogEntry(
      id: 'zoho_bookings',
      name: 'Zoho Bookings',
      category: ServiceCategory.productivity,
      domains: ['zohobookings.com'],
    ),
    ServiceCatalogEntry(
      id: 'famwalls',
      name: 'Famwalls',
      category: ServiceCategory.shopping,
      domains: ['famwalls.com'],
    ),
    ServiceCatalogEntry(
      id: 'mypaket_konstanz',
      name: 'MyPaket Konstanz',
      category: ServiceCategory.shipping,
      domains: ['mypaket-konstanz.de'],
    ),
    ServiceCatalogEntry(
      id: 'amazon_music',
      name: 'Amazon Music',
      category: ServiceCategory.streaming,
      domains: ['amazonmusic.com'],
    ),
    ServiceCatalogEntry(
      id: 'american_express',
      name: 'American Express',
      category: ServiceCategory.finance,
      domains: ['americanexpress.ch', 'americanexpress.com'],
    ),
    ServiceCatalogEntry(
      id: 'tiktok',
      name: 'TikTok',
      category: ServiceCategory.socialMedia,
      domains: ['tiktok.com'],
    ),
    ServiceCatalogEntry(
      id: 'newhome',
      name: 'newhome',
      category: ServiceCategory.realEstate,
      domains: ['newhome.ch'],
    ),
    ServiceCatalogEntry(
      id: 'musik_ebert',
      name: 'Musikhaus Ebert',
      category: ServiceCategory.shopping,
      domains: ['musik-ebert.de'],
    ),
    ServiceCatalogEntry(
      id: 'ultimate_setup',
      name: 'Ultimate Setup',
      category: ServiceCategory.shopping,
      domains: ['ultimatesetup.com', 'ultimatesetup.de'],
    ),
    ServiceCatalogEntry(
      id: 'badeparadies',
      name: 'Badeparadies Schwarzwald',
      category: ServiceCategory.travel,
      domains: ['badeparadies-schwarzwald.de'],
    ),
    ServiceCatalogEntry(
      id: 'resmio',
      name: 'resmio',
      category: ServiceCategory.foodDelivery,
      domains: ['resmio.com'],
    ),
    ServiceCatalogEntry(
      id: 'allianz',
      name: 'Allianz',
      category: ServiceCategory.insurance,
      domains: ['allianz.ch', 'allianz.de'],
    ),
    ServiceCatalogEntry(
      id: 'wagner_it',
      name: 'WAGNER',
      category: ServiceCategory.technology,
      domains: ['wagner.ch'],
    ),
    ServiceCatalogEntry(
      id: 'heylight',
      name: 'HeyLight',
      category: ServiceCategory.finance,
      domains: ['heylight.com', 'heylight.ch'],
    ),
    ServiceCatalogEntry(
      id: 'hermes',
      name: 'Hermes',
      category: ServiceCategory.shipping,
      domains: ['myhermes.de'],
    ),
    ServiceCatalogEntry(
      id: 'opentable',
      name: 'OpenTable',
      category: ServiceCategory.foodDelivery,
      domains: ['opentable.de', 'opentable.com'],
    ),
    ServiceCatalogEntry(
      id: 'medallia',
      name: 'Medallia',
      category: ServiceCategory.surveys,
      domains: ['medallia.eu', 'medallia.com'],
    ),
    ServiceCatalogEntry(
      id: 'binance',
      name: 'Binance',
      category: ServiceCategory.finance,
      domains: ['binance.com'],
    ),
    ServiceCatalogEntry(
      id: 'sampleson',
      name: 'Sampleson',
      category: ServiceCategory.technology,
      domains: ['sampleson.com'],
    ),
    ServiceCatalogEntry(
      id: 'interiman',
      name: 'Interiman Group',
      category: ServiceCategory.career,
      domains: ['interiman-group.ch'],
    ),
    ServiceCatalogEntry(
      id: 'miles_more_cards',
      name: 'Miles & More Kreditkarten',
      category: ServiceCategory.finance,
      domains: ['miles-and-more-cards.ch'],
    ),
    ServiceCatalogEntry(
      id: 'expovina',
      name: 'Expovina',
      category: ServiceCategory.tickets,
      domains: ['expovina.ch'],
    ),
    ServiceCatalogEntry(
      id: 'fielmann',
      name: 'Fielmann',
      category: ServiceCategory.health,
      domains: ['fielmann.de', 'fielmann.ch'],
    ),
    ServiceCatalogEntry(
      id: 'returnless',
      name: 'Returnless',
      category: ServiceCategory.shipping,
      domains: ['returnless.com'],
    ),
    ServiceCatalogEntry(
      id: 'mediamarkt',
      name: 'MediaMarkt',
      category: ServiceCategory.shopping,
      domains: ['mediamarkt.ch', 'mediamarkt.de'],
    ),
    ServiceCatalogEntry(
      id: 'brasserie_lok',
      name: 'Brasserie LOK',
      category: ServiceCategory.foodDelivery,
      domains: ['brasserielok.ch'],
    ),
    ServiceCatalogEntry(
      id: 'parcel_plaza',
      name: 'Parcel Plaza',
      category: ServiceCategory.shipping,
      domains: ['parcelplaza.com'],
    ),
    ServiceCatalogEntry(
      id: 'openai',
      name: 'OpenAI',
      category: ServiceCategory.technology,
      domains: ['openai.com'],
    ),
    ServiceCatalogEntry(
      id: 'surveymonkey',
      name: 'SurveyMonkey',
      category: ServiceCategory.surveys,
      domains: ['surveymonkeyuser.com', 'surveymonkey.com'],
    ),
    ServiceCatalogEntry(
      id: 'armida_finance',
      name: 'Armida Finance',
      category: ServiceCategory.finance,
      domains: ['armidafinance.ch'],
    ),
    ServiceCatalogEntry(
      id: 'swiss_marketplace_group',
      name: 'SMG Swiss Marketplace Group',
      category: ServiceCategory.marketplace,
      domains: ['swissmarketplace.group'],
    ),
    ServiceCatalogEntry(
      id: 'mobiliar',
      name: 'Die Mobiliar',
      category: ServiceCategory.insurance,
      domains: ['mobiliar.ch'],
    ),
    ServiceCatalogEntry(
      id: 'egym',
      name: 'EGYM',
      category: ServiceCategory.health,
      domains: ['egym.com'],
    ),
    ServiceCatalogEntry(
      id: 'parcel_panel',
      name: 'ParcelPanel',
      category: ServiceCategory.shipping,
      domains: ['parcelpanel.net'],
    ),
    ServiceCatalogEntry(
      id: 'visa',
      name: 'Visa',
      category: ServiceCategory.finance,
      domains: ['visa.com'],
    ),
    ServiceCatalogEntry(
      id: 'judge_me',
      name: 'Judge.me',
      category: ServiceCategory.surveys,
      domains: ['judge.me'],
    ),
    ServiceCatalogEntry(
      id: 'british_airways',
      name: 'British Airways',
      category: ServiceCategory.travel,
      domains: ['ba.com'],
    ),
    ServiceCatalogEntry(
      id: 'fc_bayern',
      name: 'FC Bayern München',
      category: ServiceCategory.other,
      domains: ['fcbayern.com'],
    ),
    ServiceCatalogEntry(
      id: 'swisscard',
      name: 'Swisscard',
      category: ServiceCategory.finance,
      domains: ['swisscard.ch'],
    ),
    ServiceCatalogEntry(
      id: 'luamaya',
      name: 'Luamaya',
      category: ServiceCategory.shopping,
      domains: ['luamaya.com'],
    ),
    ServiceCatalogEntry(
      id: 'kneady',
      name: 'Kneady',
      category: ServiceCategory.productivity,
      domains: ['kneady.io'],
    ),
    ServiceCatalogEntry(
      id: 'playstation',
      name: 'PlayStation',
      category: ServiceCategory.gaming,
      domains: ['playstation.com'],
    ),
    ServiceCatalogEntry(
      id: 'global_blue',
      name: 'Global Blue',
      category: ServiceCategory.finance,
      domains: ['globalblue.com'],
    ),
    ServiceCatalogEntry(
      id: 'update_fitness',
      name: 'update Fitness',
      category: ServiceCategory.health,
      domains: ['update-fitness.ch'],
    ),
    ServiceCatalogEntry(
      id: 'salto_systems',
      name: 'SALTO Systems',
      category: ServiceCategory.technology,
      domains: ['saltosystems.com'],
    ),
    ServiceCatalogEntry(
      id: 'netflix',
      name: 'Netflix',
      category: ServiceCategory.streaming,
      domains: ['netflix.com'],
    ),
    ServiceCatalogEntry(
      id: 'immoscout24',
      name: 'ImmoScout24',
      category: ServiceCategory.realEstate,
      domains: ['immobilienscout24.de', 'immoscout24.de'],
    ),
    ServiceCatalogEntry(
      id: 'instant_gaming',
      name: 'Instant Gaming',
      category: ServiceCategory.gaming,
      domains: ['instant-gaming.com'],
    ),
    ServiceCatalogEntry(
      id: 'klarna',
      name: 'Klarna',
      category: ServiceCategory.finance,
      domains: ['klarna.de', 'klarna.com'],
    ),
    ServiceCatalogEntry(
      id: 'microsoft',
      name: 'Microsoft',
      category: ServiceCategory.technology,
      domains: ['microsoft.com'],
    ),
    ServiceCatalogEntry(
      id: 'kununu',
      name: 'Kununu',
      category: ServiceCategory.career,
      domains: ['kununu.com'],
    ),
    ServiceCatalogEntry(
      id: 'joyn',
      name: 'Joyn',
      category: ServiceCategory.streaming,
      domains: ['joyn.de'],
    ),
    ServiceCatalogEntry(
      id: 'google',
      name: 'Google',
      category: ServiceCategory.technology,
      domains: ['google.com'],
    ),
    ServiceCatalogEntry(
      id: 'ubisoft',
      name: 'Ubisoft',
      category: ServiceCategory.gaming,
      domains: ['ubisoft.com'],
    ),
    ServiceCatalogEntry(
      id: 'instaffo',
      name: 'Instaffo',
      category: ServiceCategory.career,
      domains: ['instaffo.com'],
    ),
    ServiceCatalogEntry(
      id: 'vacanceselect',
      name: 'VacanceSelect',
      category: ServiceCategory.travel,
      domains: ['vacanceselect.com'],
    ),
    ServiceCatalogEntry(
      id: 'airbnb',
      name: 'Airbnb',
      category: ServiceCategory.travel,
      domains: ['airbnb.com'],
    ),
    ServiceCatalogEntry(
      id: 'ing',
      name: 'ING',
      category: ServiceCategory.finance,
      domains: ['ing.de'],
    ),
    ServiceCatalogEntry(
      id: 'xing',
      name: 'XING',
      category: ServiceCategory.career,
      domains: ['xing.com'],
    ),
    ServiceCatalogEntry(
      id: 'cdkeys',
      name: 'CDKeys',
      category: ServiceCategory.gaming,
      domains: ['cdkeys.com'],
    ),
    ServiceCatalogEntry(
      id: 'ninja_bet',
      name: 'Ninja Bet',
      category: ServiceCategory.betting,
      domains: ['ninja-bet.de'],
    ),
    ServiceCatalogEntry(
      id: 'adticket',
      name: 'ADticket',
      category: ServiceCategory.tickets,
      domains: ['adticket.de'],
    ),
    ServiceCatalogEntry(
      id: 'toneroffice',
      name: 'Toneroffice',
      category: ServiceCategory.officeSupplies,
      domains: ['toneroffice.de'],
    ),
    ServiceCatalogEntry(
      id: 'laduree',
      name: 'Ladurée',
      category: ServiceCategory.shopping,
      domains: ['laduree.com'],
    ),
    ServiceCatalogEntry(
      id: 'snapbuy',
      name: 'Snapbuy',
      category: ServiceCategory.shopping,
      domains: ['snapbuy.de'],
    ),
    ServiceCatalogEntry(
      id: 'gut_morgen_cloud',
      name: 'Gut Morgen Cloud',
      category: ServiceCategory.cloud,
      domains: ['gutmorgen.cloud'],
    ),
    ServiceCatalogEntry(
      id: 'bring',
      name: 'Bring!',
      category: ServiceCategory.productivity,
      domains: ['getbring.com'],
    ),
    ServiceCatalogEntry(
      id: 'steam',
      name: 'Steam',
      category: ServiceCategory.gaming,
      domains: ['steampowered.com'],
    ),
    ServiceCatalogEntry(
      id: 'twitch',
      name: 'Twitch',
      category: ServiceCategory.streaming,
      domains: ['twitch.tv'],
    ),
    ServiceCatalogEntry(
      id: 'check24',
      name: 'CHECK24',
      category: ServiceCategory.comparison,
      domains: ['check24.de'],
    ),
    ServiceCatalogEntry(
      id: 'sony',
      name: 'Sony',
      category: ServiceCategory.technology,
      domains: ['sony.com', 'sonyentertainmentnetwork.com'],
    ),
    ServiceCatalogEntry(
      id: 'doyouspain',
      name: 'DoYouSpain',
      category: ServiceCategory.travel,
      domains: ['news-doyouspain.com', 'doyouspain.com'],
    ),
    ServiceCatalogEntry(
      id: 'hm',
      name: 'H&M',
      category: ServiceCategory.shopping,
      domains: ['hm.com'],
    ),
    ServiceCatalogEntry(
      id: 'ea',
      name: 'Electronic Arts',
      category: ServiceCategory.gaming,
      domains: ['ea.com'],
    ),
    ServiceCatalogEntry(
      id: 'nintendo',
      name: 'Nintendo',
      category: ServiceCategory.gaming,
      domains: ['nintendo.com', 'nintendo-europe.com'],
    ),
    ServiceCatalogEntry(
      id: 'kleinanzeigen',
      name: 'Kleinanzeigen',
      category: ServiceCategory.marketplace,
      domains: ['kleinanzeigen.de'],
    ),
    ServiceCatalogEntry(
      id: 'wemod',
      name: 'WeMod',
      category: ServiceCategory.gaming,
      domains: ['wemod.com'],
    ),
    ServiceCatalogEntry(
      id: 'nike',
      name: 'Nike',
      category: ServiceCategory.shopping,
      domains: ['nike.com'],
    ),
    ServiceCatalogEntry(
      id: 'epic_games',
      name: 'Epic Games',
      category: ServiceCategory.gaming,
      domains: ['epicgames.com'],
    ),
    ServiceCatalogEntry(
      id: 'zara',
      name: 'Zara',
      category: ServiceCategory.shopping,
      domains: ['zara.com'],
    ),
    ServiceCatalogEntry(
      id: 'deka',
      name: 'Deka',
      category: ServiceCategory.finance,
      domains: ['deka.de'],
    ),
    ServiceCatalogEntry(
      id: 'spotify',
      name: 'Spotify',
      category: ServiceCategory.streaming,
      domains: ['spotify.com'],
    ),
    ServiceCatalogEntry(
      id: 'swarovski',
      name: 'Swarovski',
      category: ServiceCategory.shopping,
      domains: ['swarovski.com'],
    ),
    ServiceCatalogEntry(
      id: 'vodafone',
      name: 'Vodafone',
      category: ServiceCategory.telecommunications,
      domains: ['vodafone.de', 'vodafone.com'],
    ),
    ServiceCatalogEntry(
      id: 'teamviewer',
      name: 'TeamViewer',
      category: ServiceCategory.technology,
      domains: ['teamviewer.com'],
    ),
    ServiceCatalogEntry(
      id: 'christ',
      name: 'CHRIST',
      category: ServiceCategory.shopping,
      domains: ['christ.de'],
    ),
    ServiceCatalogEntry(
      id: 'steuerbot',
      name: 'Steuerbot',
      category: ServiceCategory.finance,
      domains: ['steuerbot.com'],
    ),
    ServiceCatalogEntry(
      id: 'idealo',
      name: 'idealo',
      category: ServiceCategory.comparison,
      domains: ['idealo.com'],
    ),
    ServiceCatalogEntry(
      id: 'disney_plus',
      name: 'Disney+',
      category: ServiceCategory.streaming,
      domains: ['disneyplus.com'],
    ),
    ServiceCatalogEntry(
      id: 'xiaomi',
      name: 'Xiaomi',
      category: ServiceCategory.technology,
      domains: ['xiaomi.com'],
    ),
    ServiceCatalogEntry(
      id: 'linkedin',
      name: 'LinkedIn',
      category: ServiceCategory.career,
      domains: ['linkedin.com'],
    ),
    ServiceCatalogEntry(
      id: 'nvidia',
      name: 'NVIDIA',
      category: ServiceCategory.technology,
      domains: ['nvidia.com'],
    ),
    ServiceCatalogEntry(
      id: 'thefork',
      name: 'TheFork',
      category: ServiceCategory.foodDelivery,
      domains: ['thefork.de', 'thefork.com'],
    ),
    ServiceCatalogEntry(
      id: 'supercell',
      name: 'Supercell',
      category: ServiceCategory.gaming,
      domains: ['supercell.com'],
    ),
    ServiceCatalogEntry(
      id: 'mobile_de',
      name: 'mobile.de',
      category: ServiceCategory.vehicles,
      domains: ['mobile.de'],
    ),
    ServiceCatalogEntry(
      id: 'rockstar_games',
      name: 'Rockstar Games',
      category: ServiceCategory.gaming,
      domains: ['rockstargames.com'],
    ),
    ServiceCatalogEntry(
      id: 'qualtrics',
      name: 'Qualtrics',
      category: ServiceCategory.surveys,
      domains: ['qualtrics-research.com', 'qualtrics.com'],
    ),
    ServiceCatalogEntry(
      id: 'temu',
      name: 'Temu',
      category: ServiceCategory.shopping,
      domains: ['temu.com'],
    ),
    ServiceCatalogEntry(
      id: 'govee',
      name: 'Govee',
      category: ServiceCategory.smartHome,
      domains: ['govee.com'],
    ),
    ServiceCatalogEntry(
      id: 'discord',
      name: 'Discord',
      category: ServiceCategory.socialMedia,
      domains: ['discord.com'],
    ),
    ServiceCatalogEntry(
      id: 'zalando',
      name: 'Zalando',
      category: ServiceCategory.shopping,
      domains: ['zalando.de', 'zalando.ch'],
    ),
    ServiceCatalogEntry(
      id: 'booking',
      name: 'Booking.com',
      category: ServiceCategory.travel,
      domains: ['booking.com'],
    ),
    ServiceCatalogEntry(
      id: 'ansons',
      name: 'ANSON’S',
      category: ServiceCategory.shopping,
      domains: ['ansons.de'],
    ),
    ServiceCatalogEntry(
      id: 'myticket',
      name: 'myticket',
      category: ServiceCategory.tickets,
      domains: ['myticket.de'],
    ),
    ServiceCatalogEntry(
      id: 'indeed',
      name: 'Indeed',
      category: ServiceCategory.career,
      domains: ['indeed.com'],
    ),
    ServiceCatalogEntry(
      id: 'xxxlutz',
      name: 'XXXLutz',
      category: ServiceCategory.shopping,
      domains: ['xxxlutz.de', 'xxxlutz.ch'],
    ),
    ServiceCatalogEntry(
      id: 'grover',
      name: 'Grover',
      category: ServiceCategory.shopping,
      domains: ['grover.com'],
    ),
    ServiceCatalogEntry(
      id: 'blackmagic_design',
      name: 'Blackmagic Design',
      category: ServiceCategory.technology,
      domains: ['blackmagic-design.com'],
    ),
    ServiceCatalogEntry(
      id: 'kinguin',
      name: 'Kinguin',
      category: ServiceCategory.gaming,
      domains: ['kinguin.net'],
    ),
    ServiceCatalogEntry(
      id: 'deutsche_post',
      name: 'Deutsche Post',
      category: ServiceCategory.shipping,
      domains: ['deutschepost.de'],
    ),
    ServiceCatalogEntry(
      id: 'onedrive',
      name: 'OneDrive',
      category: ServiceCategory.cloud,
      domains: ['onedrive.com'],
    ),
    ServiceCatalogEntry(
      id: 'mailchimp',
      name: 'Mailchimp',
      category: ServiceCategory.newsletterSystem,
      domains: ['mailchimpapp.com', 'mailchimp.com'],
    ),
    ServiceCatalogEntry(
      id: 'ableton',
      name: 'Ableton',
      category: ServiceCategory.technology,
      domains: ['ableton.com'],
    ),
    ServiceCatalogEntry(
      id: 'instagram',
      name: 'Instagram',
      category: ServiceCategory.socialMedia,
      domains: ['instagram.com'],
    ),
    ServiceCatalogEntry(
      id: 'jans_auto_service',
      name: 'Jans Autoservice',
      category: ServiceCategory.vehicles,
      domains: ['jansautoservice.com'],
    ),
    ServiceCatalogEntry(
      id: 'burger_king',
      name: 'Burger King',
      category: ServiceCategory.foodDelivery,
      domains: ['burgerking.de'],
    ),
    ServiceCatalogEntry(
      id: 'ryer',
      name: 'RYER',
      category: ServiceCategory.shopping,
      domains: ['ryer.de'],
    ),
    ServiceCatalogEntry(
      id: 'metaflow',
      name: 'MetaFlow',
      category: ServiceCategory.health,
      domains: ['metaflow.de'],
    ),
    ServiceCatalogEntry(
      id: 'sultanbet',
      name: 'SultanBet',
      category: ServiceCategory.betting,
      domains: ['hellosultanbet.com'],
    ),
    ServiceCatalogEntry(
      id: 'bitbull_trading',
      name: 'Bitbull Trading',
      category: ServiceCategory.finance,
      domains: ['bitbull-trading.com'],
    ),
    ServiceCatalogEntry(
      id: 'gesund_essen_leicht',
      name: 'Gesund essen leicht',
      category: ServiceCategory.health,
      domains: ['gesund-essen-leicht.de'],
    ),
  ];

  static ServiceCatalogEntry? findByDomain(String domain) {
    final normalized = domain.toLowerCase().trim();
    for (final entry in entries) {
      for (final candidate in entry.domains) {
        if (normalized == candidate || normalized.endsWith('.$candidate')) {
          return entry;
        }
      }
    }
    return null;
  }

  /// Applies new catalog knowledge to data already stored on the device.
  /// No network request is made and no user data leaves the device.
  static ScanDataset normalizeDataset(ScanDataset dataset) {
    final normalized = <String, ServiceItem>{};

    for (final service in dataset.services) {
      ServiceCatalogEntry? entry;
      for (final domain in service.domains) {
        entry = findByDomain(domain);
        if (entry != null) break;
      }

      final resolved = ServiceItem(
        id: entry?.id ?? service.id,
        name: entry?.name ?? service.name,
        categoryId: entry?.category ?? service.categoryId,
        mailCounts: service.mailCounts,
        color: service.color,
        monogram: entry == null ? service.monogram : _monogram(entry.name),
        domains: {
          ...service.domains,
          ...?entry?.domains,
        }.toList(growable: false),
        newsletterCounts: service.newsletterCounts,
        securityCounts: service.securityCounts,
        unsubscribeByAccount: service.unsubscribeByAccount,
        unsubscribeUrlsByAccount: service.unsubscribeUrlsByAccount,
        unsubscribeRequiresPostByAccount:
            service.unsubscribeRequiresPostByAccount,
      );

      final existing = normalized[resolved.id];
      normalized[resolved.id] = existing == null
          ? resolved
          : _combine(existing, resolved);
    }

    final services = normalized.values.toList()
      ..sort((a, b) => b.totalMailCount.compareTo(a.totalMailCount));
    return ScanDataset(services: services, sourceFiles: dataset.sourceFiles);
  }

  static ServiceItem _combine(ServiceItem first, ServiceItem second) =>
      ServiceItem(
        id: first.id,
        name: first.name,
        categoryId: first.categoryId,
        mailCounts: _sumCounts(first.mailCounts, second.mailCounts),
        color: first.color,
        monogram: first.monogram,
        domains: {...first.domains, ...second.domains}.toList(growable: false),
        newsletterCounts: _sumCounts(
          first.newsletterCounts,
          second.newsletterCounts,
        ),
        securityCounts: _sumCounts(first.securityCounts, second.securityCounts),
        unsubscribeByAccount: _mergeFlags(
          first.unsubscribeByAccount,
          second.unsubscribeByAccount,
        ),
        unsubscribeUrlsByAccount: {
          ...first.unsubscribeUrlsByAccount,
          ...second.unsubscribeUrlsByAccount,
        },
        unsubscribeRequiresPostByAccount: {
          ...first.unsubscribeRequiresPostByAccount,
          ...second.unsubscribeRequiresPostByAccount,
        },
      );

  static Map<String, int> _sumCounts(
    Map<String, int> first,
    Map<String, int> second,
  ) {
    final result = Map<String, int>.from(first);
    for (final entry in second.entries) {
      result.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return result;
  }

  static Map<String, bool> _mergeFlags(
    Map<String, bool> first,
    Map<String, bool> second,
  ) {
    final result = Map<String, bool>.from(first);
    for (final entry in second.entries) {
      result.update(
        entry.key,
        (value) => value || entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return result;
  }

  static String _monogram(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }
    final end = name.length < 2 ? name.length : 2;
    return name.substring(0, end).toUpperCase();
  }
}
