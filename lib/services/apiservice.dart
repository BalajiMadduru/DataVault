import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> allVarieties = ['BB MOD', 'BB SPL MOD', 'MECH'];

  // ============ AUTH METHODS ============

  static Future<ApiResponse> login({
    required String email,
    required String password,
    required String mobile,
    required String username,
    bool keepSignedIn = true,
  }) async {
    try {
      print('🔄 Login attempt for: $email');
      if (kIsWeb) {
        await _auth.setPersistence(
          keepSignedIn ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Login successful for: ${credential.user?.uid}');
      return await _saveDailyRecordAndRespond(credential, email, mobile, username);
    } on FirebaseAuthException catch (e) {
      return ApiResponse(
        success: false,
        message: _mapAuthError(e.code),
        data: {'code': e.code},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  static Future<ApiResponse> register({
    required String email,
    required String password,
    required String mobile,
    required String username,
    bool keepSignedIn = true,
  }) async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(
          keepSignedIn ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _saveDailyRecordAndRespond(
        credential, email, mobile, username,
        isNewAccount: true,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return ApiResponse(
          success: false,
          message: 'An account already exists for that email. Try signing in instead.',
          data: {'code': e.code},
        );
      }
      return ApiResponse(
        success: false,
        message: _mapAuthError(e.code),
        data: {'code': e.code},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Something went wrong creating your account: ${e.toString()}',
      );
    }
  }

  static Future<ApiResponse> _saveDailyRecordAndRespond(
      UserCredential credential,
      String email,
      String mobile,
      String username, {
        bool isNewAccount = false,
      }) async {
    try {
      final uid = credential.user!.uid;
      final userData = {
        'email': email,
        'mobile': mobile,
        'username': username,
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('users').doc(uid).set(
        userData,
        SetOptions(merge: true),
      );
      return ApiResponse(
        success: true,
        message: isNewAccount ? 'Account created — welcome!' : 'Login successful',
        data: {'uid': uid},
      );
    } catch (e) {
      return ApiResponse(
        success: true,
        message: isNewAccount
            ? 'Account created successfully! Please sign in.'
            : 'Login successful',
        data: {'uid': credential.user!.uid},
      );
    }
  }

  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  static Future<ApiResponse> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final userData = {
          'email': user.email ?? '',
          'username': user.email?.split('@').first ?? '',
          'mobile': '',
          'lastLogin': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('users').doc(user.uid).set(
          userData,
          SetOptions(merge: true),
        );
        return ApiResponse(
          success: true,
          message: 'Profile fetched',
          data: {
            'uid': user.uid,
            'username': user.email?.split('@').first ?? '',
            'email': user.email ?? '',
            'mobile': '',
          },
        );
      }
      final data = doc.data() ?? {};
      return ApiResponse(
        success: true,
        message: 'Profile fetched',
        data: {
          'uid': user.uid,
          'username': (data['username'] as String?) ?? '',
          'email': (data['email'] as String?) ?? user.email ?? '',
          'mobile': (data['mobile'] as String?) ?? '',
        },
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching profile: $e',
      );
    }
  }

  static Future<ApiResponse> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return ApiResponse(
        success: true,
        message: 'Password reset link sent to $email',
      );
    } on FirebaseAuthException catch (e) {
      return ApiResponse(
        success: false,
        message: _mapAuthError(e.code),
        data: {'code': e.code},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  static String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for that email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'invalid-email':
        return 'That email address looks invalid';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'weak-password':
        return 'Please choose a stronger password (min 8 chars)';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again';
      case 'email-already-in-use':
        return 'An account already exists for that email';
      default:
        return 'Login failed. Please try again';
    }
  }

  // ============ GET NEXT REPORT NUMBER ============

  static Future<ApiResponse> getNextReportNo({
    required String type,
    required String centre,
    DateTime? date,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final normalizedCentre = centre.trim().toLowerCase();
      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .get();

      int maxReportNo = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;
        final reportNo = (data['reportNo'] as num?)?.toInt() ?? 0;
        if (reportNo > maxReportNo) maxReportNo = reportNo;
      }
      return ApiResponse(
        success: true,
        message: 'Next report number generated',
        data: {'nextReportNo': maxReportNo + 1},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to generate report number: $e',
      );
    }
  }

  // ============ DUPLICATE CHECK ============

  static Future<ApiResponse> checkDuplicateEntry({
    required String type,
    required String centre,
    required int reportNo,
    required DateTime date,
    required String variety,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final normalizedCentre = centre.trim().toLowerCase();
      final normalizedVariety = variety.trim().toLowerCase();

      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .get();

      bool foundDuplicate = false;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;
        final storedReportNo = (data['reportNo'] as num?)?.toInt() ?? 0;
        if (storedReportNo != reportNo) continue;
        final rawDate = data['date'];
        if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null &&
              parsed.year == date.year &&
              parsed.month == date.month &&
              parsed.day == date.day) {
            final storedVariety = (data['variety'] as String? ?? '').trim().toLowerCase();
            if (storedVariety == normalizedVariety) {
              foundDuplicate = true;
              break;
            }
          }
        }
      }
      return ApiResponse(
        success: true,
        message: foundDuplicate ? 'Duplicate entry found' : 'No duplicate found',
        data: {'exists': foundDuplicate},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error checking duplicate: $e',
      );
    }
  }

  // ============ SAVE METHODS ============

  static Future<ApiResponse> savePurchaseEntry(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      data['userId'] = user.uid;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['type'] = 'purchase';

      final docRef = await _db.collection('purchases').add(data);
      return ApiResponse(
        success: true,
        message: 'Purchase entry saved successfully',
        data: {'id': docRef.id},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error saving purchase: $e',
      );
    }
  }

  static Future<ApiResponse> saveSeedEntry(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      data['userId'] = user.uid;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['type'] = 'seed';

      final docRef = await _db.collection('purchases').add(data);
      return ApiResponse(
        success: true,
        message: 'Seed entry saved successfully',
        data: {'id': docRef.id},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error saving seed: $e',
      );
    }
  }

  static Future<ApiResponse> findEntry({
    required String type,
    required String centre,
    required int reportNo,
    required DateTime date,
    String? variety,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final normalizedCentre = centre.trim().toLowerCase();
      final normalizedVariety = variety?.trim().toLowerCase();

      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .where('reportNo', isEqualTo: reportNo)
          .get();

      Map<String, dynamic>? match;
      String? matchId;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;

        if (normalizedVariety != null && normalizedVariety.isNotEmpty) {
          bool varietyMatches;
          if (data['variety'] != null) {
            varietyMatches = (data['variety'] as String? ?? '').trim().toLowerCase() == normalizedVariety;
          } else if (data['seedFactories'] is List) {
            varietyMatches = (data['seedFactories'] as List).any((f) {
              final factoryVariety = (f is Map) ? (f['variety'] as String? ?? '') : '';
              return factoryVariety.trim().toLowerCase() == normalizedVariety;
            });
          } else {
            varietyMatches = false;
          }
          if (!varietyMatches) continue;
        }

        final rawDate = data['date'];
        if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null &&
              parsed.year == date.year &&
              parsed.month == date.month &&
              parsed.day == date.day) {
            match = data;
            matchId = doc.id;
            break;
          }
        }
      }

      if (match == null) {
        final varietyPart = (normalizedVariety != null && normalizedVariety.isNotEmpty)
            ? ', variety'
            : '';
        return ApiResponse(
          success: false,
          message: 'No entry found for that centre$varietyPart, report number & date',
        );
      }
      match['id'] = matchId;
      return ApiResponse(
        success: true,
        message: 'Entry found',
        data: {'entry': match},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error finding entry: $e',
      );
    }
  }

  // ============ GET LATEST PROGRESSIVE ARRIVALS ============

  static Future<ApiResponse> getLatestProgressiveArrivals({
    required String type,
    required String centre,
    required String variety,
    DateTime? beforeDate,
    String? excludeDocId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final normalizedCentre = centre.trim().toLowerCase();
      final normalizedVariety = variety.trim().toLowerCase();

      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .get();

      Map<String, dynamic>? latestEntry;
      int highestReportNo = -1;

      for (final doc in querySnapshot.docs) {
        if (excludeDocId != null && doc.id == excludeDocId) continue;
        final data = doc.data();
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;
        final storedVariety = (data['variety'] as String? ?? '').trim().toLowerCase();
        if (storedVariety != normalizedVariety) continue;
        final reportNo = (data['reportNo'] as num?)?.toInt() ?? 0;
        if (reportNo > highestReportNo) {
          highestReportNo = reportNo;
          latestEntry = data;
        }
      }

      if (latestEntry == null) {
        return ApiResponse(
          success: true,
          message: 'No previous entry found',
          data: {
            'progPressedBales': 0,
            'progPurchaseQtls': 0,
            'progPurchaseBales': 0,
            'progFarmers': 0,
            'progArrivalsApmc': 0,
            'progArrivalsOutside': 0,
            'farmersProgressive': 0,
            'mspValueProg': 0,
            'balesPressedProg': 0,
          },
        );
      }

      final progPressedBales = (latestEntry['progPressedBales'] ??
          latestEntry['balesPressedProg'] as num?)
          ?.toDouble() ??
          0;
      final progPurchaseQtls = (latestEntry['progPurchaseQtls'] as num?)?.toDouble() ?? 0;
      final progPurchaseBales = (latestEntry['progPurchaseBales'] as num?)?.toDouble() ?? 0;
      final progFarmers = (latestEntry['progFarmers'] ??
          latestEntry['farmersProgressive'] as num?)
          ?.toDouble() ??
          0;

      return ApiResponse(
        success: true,
        message: 'Previous entry found',
        data: {
          'progPressedBales': progPressedBales,
          'progPurchaseQtls': progPurchaseQtls,
          'progPurchaseBales': progPurchaseBales,
          'progFarmers': progFarmers,
          'balesPressedProg': progPressedBales,
          'farmersProgressive': progFarmers,
          'progArrivalsApmc': (latestEntry['progArrivalsApmc'] as num?)?.toDouble() ?? 0,
          'progArrivalsOutside': (latestEntry['progArrivalsOutside'] as num?)?.toDouble() ?? 0,
          'mspValueProg': (latestEntry['mspValueProg'] as num?)?.toDouble() ?? 0,
        },
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching previous entry: $e',
      );
    }
  }

  // ============ GET PROGRESSIVE FOR ALL VARIETIES ============
  // Returns a map keyed by variety name with the latest progressive
  // values for that variety at the given centre. Used by the entry form
  // to populate `otherVarietiesProgressive` before saving a purchase.

  static Future<Map<String, Map<String, double>>> getProgressiveForAllVarieties({
    required String type,
    required String centre,
    List<String> varieties = allVarieties,
  }) async {
    final result = <String, Map<String, double>>{};

    for (final variety in varieties) {
      final response = await getLatestProgressiveArrivals(
        type: type,
        centre: centre,
        variety: variety,
      );

      final d = response.data ?? {};
      result[variety] = {
        'progPressedBales': (d['progPressedBales'] as num?)?.toDouble() ?? 0,
        'progPurchaseQtls': (d['progPurchaseQtls'] as num?)?.toDouble() ?? 0,
        'progPurchaseBales': (d['progPurchaseBales'] as num?)?.toDouble() ?? 0,
        'progFarmers': (d['progFarmers'] as num?)?.toDouble() ?? 0,
      };
    }
    return result;
  }

  // ============ GET PURCHASE ENTRIES (NORMALIZED) ============

  static Future<ApiResponse> getPurchaseEntries() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'purchase')
          .orderBy('createdAt', descending: true)
          .get();

      final entries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Normalize alternate field names to canonical ones.
        data['progPressedBales'] ??= data['balesPressedProg'];
        data['balesPressedProg'] ??= data['progPressedBales'];
        data['progFarmers'] ??= data['farmersProgressive'];
        data['farmersProgressive'] ??= data['progFarmers'];
        data['progArrivalsApmc'] ??= data['progPurchaseQtls'];
        data['progArrivalsOutside'] ??= data['progPurchaseBales'];

        return data;
      }).toList();

      return ApiResponse(
        success: true,
        message: 'Entries fetched successfully',
        data: {'entries': entries},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching entries: $e',
      );
    }
  }

  static Future<ApiResponse> getSeedEntries() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'seed')
          .orderBy('createdAt', descending: true)
          .get();

      final entries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        data['progPressedBales'] ??= data['balesPressedProg'];
        data['balesPressedProg'] ??= data['progPressedBales'];
        data['progFarmers'] ??= data['farmersProgressive'];
        data['farmersProgressive'] ??= data['progFarmers'];

        return data;
      }).toList();

      return ApiResponse(
        success: true,
        message: 'Entries fetched successfully',
        data: {'entries': entries},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching entries: $e',
      );
    }
  }

  static Future<ApiResponse> updateEntry(String docId, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('purchases').doc(docId).update(data);
      return ApiResponse(
        success: true,
        message: 'Entry updated successfully',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error updating entry: $e',
      );
    }
  }

  static Future<ApiResponse> deleteEntry(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }

      final proformaQuery = await _db
          .collection('proformas')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (final proformaDoc in proformaQuery.docs) {
        final data = proformaDoc.data();
        final entries = data['entries'];
        if (entries is Map && entries.containsKey(docId)) {
          final updatedEntries = Map<String, dynamic>.from(entries)..remove(docId);
          if (updatedEntries.isEmpty) {
            await proformaDoc.reference.delete();
          } else {
            await proformaDoc.reference.update({
              ..._recomputeProformaTotals(updatedEntries),
              'entries': updatedEntries,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          break;
        }
      }

      await _db.collection('purchases').doc(docId).delete();
      return ApiResponse(
        success: true,
        message: 'Entry deleted successfully',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error deleting entry: $e',
      );
    }
  }

  static Future<ApiResponse> checkEntryExists({
    required String type,
    required String centre,
    required int reportNo,
    required DateTime date,
    required String variety,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final normalizedCentre = centre.trim().toLowerCase();
      final normalizedVariety = variety.trim().toLowerCase();

      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;
        final storedReportNo = (data['reportNo'] as num?)?.toInt() ?? 0;
        if (storedReportNo != reportNo) continue;
        final rawDate = data['date'];
        if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null &&
              parsed.year == date.year &&
              parsed.month == date.month &&
              parsed.day == date.day) {
            final storedVariety = (data['variety'] as String? ?? '').trim().toLowerCase();
            if (storedVariety == normalizedVariety) {
              return ApiResponse(
                success: true,
                message: 'Entry exists',
                data: {'exists': true, 'docId': doc.id},
              );
            }
          }
        }
      }
      return ApiResponse(
        success: true,
        message: 'No entry found',
        data: {'exists': false},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error checking entry: $e',
      );
    }
  }

  // ============ PROFORMA METHODS ============

  static const List<String> _proformaSumFields = [
    'quantity', 'amount', 'farmers', 'moistureValue', 'shortageValue',
    'padthaValue', 'outTurnValue', 'seedValue', 'bales', 'heap',
  ];

  static const List<String> _proformaAvgFields = [
    'rate', 'moisture', 'shortage', 'padtha', 'outTurn', 'seed',
  ];

  static Map<String, dynamic> recomputeProformaTotals(
      Map<String, dynamic> entries) =>
      _recomputeProformaTotals(entries);

  static Map<String, dynamic> filterEntriesByDateRange(
      Map<String, dynamic> entries, {
        DateTime? start,
        DateTime? end,
      }) {
    if (start == null && end == null) return entries;
    final filtered = <String, dynamic>{};
    entries.forEach((key, value) {
      if (value is! Map) return;
      final entry = Map<String, dynamic>.from(value);
      final entryDate = DateTime.tryParse(entry['entryDate']?.toString() ?? '');
      if (entryDate == null) return;
      final normalized = DateTime(entryDate.year, entryDate.month, entryDate.day);
      if (start != null) {
        final s = DateTime(start.year, start.month, start.day);
        if (normalized.isBefore(s)) return;
      }
      if (end != null) {
        final e = DateTime(end.year, end.month, end.day);
        if (normalized.isAfter(e)) return;
      }
      filtered[key] = value;
    });
    return filtered;
  }

  static Map<String, dynamic> _recomputeProformaTotals(Map<String, dynamic> entries) {
    final sumFields = <String, num>{};
    final avgFields = <String, List<num>>{};
    int entryCount = 0;

    for (final raw in entries.values) {
      final entry = Map<String, dynamic>.from(raw as Map);
      entryCount++;

      for (final field in _proformaSumFields) {
        final value = entry[field];
        if (value is num) {
          sumFields[field] = (sumFields[field] ?? 0) + value;
        } else if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            sumFields[field] = (sumFields[field] ?? 0) + parsed;
          }
        }
      }

      for (final field in _proformaAvgFields) {
        final value = entry[field];
        if (value is num) {
          avgFields[field] = (avgFields[field] ?? [])..add(value);
        } else if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            avgFields[field] = (avgFields[field] ?? [])..add(parsed);
          }
        }
      }
    }

    final result = <String, dynamic>{...sumFields};
    final totalQuantity = sumFields['quantity'] as num? ?? 0;
    if (totalQuantity > 0) {
      final totalAmount = sumFields['amount'] as num? ?? 0;
      result['rate'] = totalAmount / totalQuantity;
      final totalMoistureValue = sumFields['moistureValue'] as num? ?? 0;
      result['moisture'] = totalMoistureValue / totalQuantity;
      final totalShortageValue = sumFields['shortageValue'] as num? ?? 0;
      result['shortage'] = totalShortageValue / totalQuantity;
      final totalPadthaValue = sumFields['padthaValue'] as num? ?? 0;
      result['padtha'] = totalPadthaValue / totalQuantity;
      final totalOutTurnValue = sumFields['outTurnValue'] as num? ?? 0;
      result['outTurn'] = totalOutTurnValue / totalQuantity;
      final totalSeedValue = sumFields['seedValue'] as num? ?? 0;
      result['seed'] = totalSeedValue / totalQuantity;
    } else {
      for (final entry in avgFields.entries) {
        final values = entry.value;
        if (values.isNotEmpty) {
          final avg = values.reduce((a, b) => a + b) / values.length;
          result[entry.key] = avg;
        }
      }
    }

    final entryDates = entries.values
        .map((e) => e['entryDate']?.toString())
        .whereType<String>()
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();

    if (entryDates.isNotEmpty) {
      entryDates.sort();
      result['dateRangeStart'] = entryDates.first.toIso8601String();
      result['dateRangeEnd'] = entryDates.last.toIso8601String();
      result['date'] = entryDates.last.toIso8601String();
    }
    result['entryCount'] = entryCount;
    return result;
  }

  static Future<void> _removeStaleProformaContribution(
      String userId,
      String purchaseEntryId, {
        required String currentCentre,
        required String currentVariety,
      }) async {
    final query = await _db.collection('proformas').where('userId', isEqualTo: userId).get();
    for (final doc in query.docs) {
      final data = doc.data();
      final entries = data['entries'];
      if (entries is! Map || !entries.containsKey(purchaseEntryId)) continue;
      if (data['centre'] == currentCentre && data['variety'] == currentVariety) continue;
      final updatedEntries = Map<String, dynamic>.from(entries)..remove(purchaseEntryId);
      if (updatedEntries.isEmpty) {
        await doc.reference.delete();
      } else {
        await doc.reference.update({
          ..._recomputeProformaTotals(updatedEntries),
          'entries': updatedEntries,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<ApiResponse> saveProforma(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final centre = data['centre']?.toString() ?? '';
      final variety = data['variety']?.toString() ?? '';
      final rawDate = data['date'];
      final purchaseEntryId = data['purchaseEntryId']?.toString();

      if (centre.isEmpty || variety.isEmpty || rawDate == null) {
        return ApiResponse(
          success: false,
          message: 'Centre, variety, and date are required to save a proforma',
        );
      }
      if (purchaseEntryId == null || purchaseEntryId.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'purchaseEntryId is required to save a proforma',
        );
      }

      final parsedDate = rawDate is String ? DateTime.parse(rawDate) : rawDate as DateTime;
      final normalizedDateStr =
      DateTime(parsedDate.year, parsedDate.month, parsedDate.day).toIso8601String();

      final entry = Map<String, dynamic>.from(data)
        ..remove('centre')
        ..remove('variety')
        ..remove('userId')
        ..remove('purchaseEntryId');
      entry['entryDate'] = normalizedDateStr;

      await _removeStaleProformaContribution(
        user.uid, purchaseEntryId,
        currentCentre: centre, currentVariety: variety,
      );

      final existing = await _db
          .collection('proformas')
          .where('userId', isEqualTo: user.uid)
          .where('centre', isEqualTo: centre)
          .where('variety', isEqualTo: variety)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final existingEntries = Map<String, dynamic>.from(
          (doc.data()['entries'] as Map?) ?? {},
        );
        existingEntries[purchaseEntryId] = entry;
        await doc.reference.update({
          ..._recomputeProformaTotals(existingEntries),
          'entries': existingEntries,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return ApiResponse(
          success: true,
          message: 'Proforma updated',
          data: {'id': doc.id},
        );
      }

      final entries = {purchaseEntryId: entry};
      final docRef = await _db.collection('proformas').add({
        ..._recomputeProformaTotals(entries),
        'userId': user.uid,
        'centre': centre,
        'variety': variety,
        'entries': entries,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ApiResponse(
        success: true,
        message: 'Proforma saved successfully',
        data: {'id': docRef.id},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error saving proforma: $e',
      );
    }
  }

  static Future<ApiResponse> getProformas() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final querySnapshot = await _db
          .collection('proformas')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final proformas = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return ApiResponse(
        success: true,
        message: 'Proformas fetched successfully',
        data: {'proformas': proformas},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching proformas: $e',
      );
    }
  }

  static Future<ApiResponse> getProformaByPurchaseEntry(String purchaseEntryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final query = await _db.collection('proformas').where('userId', isEqualTo: user.uid).get();
      for (final doc in query.docs) {
        final data = doc.data();
        final entries = data['entries'];
        if (entries is Map && entries.containsKey(purchaseEntryId)) {
          final entryData = Map<String, dynamic>.from(data);
          entryData['id'] = doc.id;
          entryData['selectedEntry'] = entries[purchaseEntryId];
          return ApiResponse(
            success: true,
            message: 'Proforma found',
            data: {'proforma': entryData},
          );
        }
      }
      return ApiResponse(
        success: false,
        message: 'No proforma found for this entry',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching proforma: $e',
      );
    }
  }

  static Future<ApiResponse> getProformaById(String proformaId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      final doc = await _db.collection('proformas').doc(proformaId).get();
      if (!doc.exists) {
        return ApiResponse(
          success: false,
          message: 'Proforma not found',
        );
      }
      final data = doc.data() ?? {};
      if (data['userId'] != user.uid) {
        return ApiResponse(
          success: false,
          message: 'Access denied',
        );
      }
      data['id'] = doc.id;
      return ApiResponse(
        success: true,
        message: 'Proforma found',
        data: {'proforma': data},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching proforma: $e',
      );
    }
  }

  static Future<ApiResponse> deleteProforma(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }
      await _db.collection('proformas').doc(docId).delete();
      return ApiResponse(
        success: true,
        message: 'Proforma deleted successfully',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error deleting proforma: $e',
      );
    }
  }
}

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({required this.success, required this.message, this.data});
}