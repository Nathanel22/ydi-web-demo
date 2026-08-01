import 'package:flutter/material.dart';

import '../models/service_category.dart';
import '../models/service_item.dart';

/// Synthetic sample data used only by the public web demonstration.
/// No address, token, URL or count in this file comes from a user account.
abstract final class DemoServices {
  static const all = <ServiceItem>[
    ServiceItem(
      id: 'netflix_demo',
      name: 'Netflix',
      categoryId: ServiceCategory.streaming,
      mailCounts: {'GMX Demo': 42},
      newsletterCounts: {'GMX Demo': 18},
      unsubscribeByAccount: {'GMX Demo': true},
      color: Color(0xFFE50914),
      monogram: 'N',
      domains: ['netflix.com'],
    ),
    ServiceItem(
      id: 'immoscout24_demo',
      name: 'ImmoScout24',
      categoryId: ServiceCategory.realEstate,
      mailCounts: {'GMX Demo': 31},
      newsletterCounts: {'GMX Demo': 16},
      unsubscribeByAccount: {'GMX Demo': true},
      color: Color(0xFF00A88F),
      monogram: 'I',
      domains: ['immobilienscout24.de'],
    ),
    ServiceItem(
      id: 'microsoft_demo',
      name: 'Microsoft',
      categoryId: ServiceCategory.technology,
      mailCounts: {'GMX Demo': 19, 'Gmail Demo': 24},
      newsletterCounts: {'Gmail Demo': 5},
      securityCounts: {'GMX Demo': 3, 'Gmail Demo': 4},
      color: Color(0xFF2777BD),
      monogram: 'M',
      domains: ['microsoft.com'],
    ),
    ServiceItem(
      id: 'instant_gaming_demo',
      name: 'Instant Gaming',
      categoryId: ServiceCategory.gaming,
      mailCounts: {'GMX Demo': 14, 'Gmail Demo': 21},
      newsletterCounts: {'GMX Demo': 6, 'Gmail Demo': 8},
      color: Color(0xFFF39B28),
      monogram: 'IG',
      domains: ['instant-gaming.com'],
    ),
    ServiceItem(
      id: 'linkedin_demo',
      name: 'LinkedIn',
      categoryId: ServiceCategory.career,
      mailCounts: {'Gmail Demo': 54},
      newsletterCounts: {'Gmail Demo': 28},
      unsubscribeByAccount: {'Gmail Demo': true},
      color: Color(0xFF0A66C2),
      monogram: 'LI',
      domains: ['linkedin.com'],
    ),
    ServiceItem(
      id: 'google_demo',
      name: 'Google',
      categoryId: ServiceCategory.technology,
      mailCounts: {'Gmail Demo': 36},
      securityCounts: {'Gmail Demo': 9},
      color: Color(0xFF4285F4),
      monogram: 'G',
      domains: ['google.com'],
    ),
    ServiceItem(
      id: 'temu_demo',
      name: 'Temu',
      categoryId: ServiceCategory.shopping,
      mailCounts: {'Gmail Demo': 23},
      newsletterCounts: {'Gmail Demo': 12},
      unsubscribeByAccount: {'Gmail Demo': true},
      color: Color(0xFFFF6A00),
      monogram: 'T',
      domains: ['temu.com'],
    ),
    ServiceItem(
      id: 'facebook_demo',
      name: 'Facebook',
      categoryId: ServiceCategory.socialMedia,
      mailCounts: {'Gmail Demo': 15},
      newsletterCounts: {'Gmail Demo': 7},
      securityCounts: {'Gmail Demo': 2},
      unsubscribeByAccount: {'Gmail Demo': true},
      color: Color(0xFF1877F2),
      monogram: 'F',
      domains: ['facebook.com'],
    ),
  ];
}
