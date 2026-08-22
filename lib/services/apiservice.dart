import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============ AUTH METHODS ============

  static Future<ApiResponse> login({
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

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return _saveDailyRecordAndRespond(credential, email, mobile, username);
    } on FirebaseAuthException catch (e) {
      // NOTE: the Firebase error code is now surfaced in `data['code']` so
      // the UI can react to specific cases (e.g. offer to create an
      // account when sign-in fails because none exists yet) instead of
      // only having the human-readable message to work with.
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
      return _saveDailyRecordAndRespond(
        credential,
        email,
        mobile,
        username,
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
        message: 'Something went wrong creating your account.',
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
    final uid = credential.user!.uid;

    await _db.collection('users').doc(uid).set({
      'email': email,
      'mobile': mobile,
      'username': username,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return ApiResponse(
      success: true,
      message: isNewAccount ? 'Account created — welcome!' : 'Login successful',
      data: {'uid': uid},
    );
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<ApiResponse> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(success: false, message: 'User not logged in');
      }

      final doc = await _db.collection('users').doc(user.uid).get();
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
        return 'Please choose a stronger password';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again';
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        if (reportNo > maxReportNo) {
          maxReportNo = reportNo;
        }
      }

      final nextReportNo = maxReportNo + 1;

      return ApiResponse(
        success: true,
        message: 'Next report number generated',
        data: {'nextReportNo': nextReportNo},
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to generate report number: $e',
      );
    }
  }

  // ============ DUPLICATE CHECK METHOD ============

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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
      }

      final normalizedCentre = centre.trim().toLowerCase();
      final normalizedVariety = variety.trim().toLowerCase();

      // Get all entries for this user and type
      final querySnapshot = await _db
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .get();

      // Check for duplicate
      bool foundDuplicate = false;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // Check centre match (case insensitive)
        final storedCentre = (data['centre'] as String? ?? '').trim().toLowerCase();
        if (storedCentre != normalizedCentre) continue;

        // Check reportNo match
        final storedReportNo = (data['reportNo'] as num?)?.toInt() ?? 0;
        if (storedReportNo != reportNo) continue;

        // Check date match
        final rawDate = data['date'];
        if (rawDate is String) {
          final parsed = DateTime.tryParse(rawDate);
          if (parsed != null &&
              parsed.year == date.year &&
              parsed.month == date.month &&
              parsed.day == date.day) {

            // Check variety match (case insensitive)
            final storedVariety = (data['variety'] as String? ?? '').trim().toLowerCase();
            if (storedVariety == normalizedVariety) {
              foundDuplicate = true;
              break;
            }
          }
        }
      }

      if (foundDuplicate) {
        return ApiResponse(
          success: true,
          message: 'Duplicate entry found',
          data: {'exists': true},
        );
      } else {
        return ApiResponse(
          success: true,
          message: 'No duplicate found',
          data: {'exists': false},
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error checking duplicate: $e',
      );
    }
  }

  // ============ PURCHASE DATA METHODS ============

  static Future<ApiResponse> savePurchaseEntry(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
      }

      final normalizedCentre = centre.trim().toLowerCase();

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
        return ApiResponse(
          success: false,
          message: 'No entry found for that centre, report number & date',
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
  // NOTE: Scoped by centre AND variety, so progressive totals are
  // tracked separately per variety within a centre.
  // Add this to ApiService class in apiservice.dart
  static Future<ApiResponse> getLatestProgressiveArrivals({
    required String type,
    required String centre,
    required String variety,
    DateTime? beforeDate,
    String? excludeDocId, // NEW: exclude a specific document ID
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        // Skip the excluded document
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
            'progArrivalsApmc': 0,
            'progArrivalsOutside': 0,
            'farmersProgressive': 0,
            'mspValueProg': 0,
            'balesPressedProg': 0,
          },
        );
      }

      final progApmc = (latestEntry['progArrivalsApmc'] as num?)?.toDouble() ?? 0;
      final progOutside = (latestEntry['progArrivalsOutside'] as num?)?.toDouble() ?? 0;
      final farmersProg = (latestEntry['farmersProgressive'] as num?)?.toDouble() ?? 0;
      final mspProg = (latestEntry['mspValueProg'] as num?)?.toDouble() ?? 0;
      final balesProg = (latestEntry['balesPressedProg'] as num?)?.toDouble() ?? 0;

      return ApiResponse(
        success: true,
        message: 'Previous entry found',
        data: {
          'progArrivalsApmc': progApmc,
          'progArrivalsOutside': progOutside,
          'farmersProgressive': farmersProg,
          'mspValueProg': mspProg,
          'balesPressedProg': balesProg,
        },
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error fetching previous entry: $e',
      );
    }
  }

  static Future<ApiResponse> getPurchaseEntries() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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

  // ============ PROFORMA METHODS ============

  // Fields that represent day-level running totals. When multiple purchase
  // entries land on the same centre + day, these are summed across entries.
  // Everything else (rate, moisture %, shortage %, padtha %, outTurn %,
  // etc.) isn't meaningful when summed, so the most recently saved entry's
  // value wins instead.
  static const List<String> _proformaAdditiveFields = [
    'quantity', 'amount', 'farmers', 'moistureValue', 'shortageValue',
    'padthaValue', 'outTurnValue', 'seed', 'seedValue', 'bales', 'heap',
  ];

  static Map<String, dynamic> _recomputeProformaTotals(Map<String, dynamic> entries) {
    final totals = <String, num>{for (final f in _proformaAdditiveFields) f: 0};
    Map<String, dynamic>? lastEntry;

    for (final raw in entries.values) {
      final entry = Map<String, dynamic>.from(raw as Map);
      lastEntry = entry;
      for (final field in _proformaAdditiveFields) {
        final value = entry[field];
        if (value is num) {
          totals[field] = (totals[field] ?? 0) + value;
        } else if (value is String) {
          totals[field] = (totals[field] ?? 0) + (num.tryParse(value) ?? 0);
        }
      }
    }

    final result = <String, dynamic>{...totals};
    if (lastEntry != null) {
      for (final key in lastEntry.keys) {
        if (!_proformaAdditiveFields.contains(key)) {
          result[key] = lastEntry[key];
        }
      }
    }
    result['entryCount'] = entries.length;
    return result;
  }

  /// If [purchaseEntryId] already contributed to a *different* day's
  /// proforma (e.g. its date or centre was edited since it was last
  /// generated), remove that stale contribution so a regenerate never
  /// leaves duplicate/ghost totals behind on the old day.
  static Future<void> _removeStaleProformaContribution(
      String userId,
      String purchaseEntryId, {
        required String currentDate,
        required String currentCentre,
      }) async {
    final query = await _db.collection('proformas').where('userId', isEqualTo: userId).get();

    for (final doc in query.docs) {
      final data = doc.data();
      final entries = data['entries'];
      if (entries is! Map || !entries.containsKey(purchaseEntryId)) continue;
      if (data['date'] == currentDate && data['centre'] == currentCentre) continue;

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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
      }

      final centre = data['centre']?.toString() ?? '';
      final rawDate = data['date'];
      final purchaseEntryId = data['purchaseEntryId']?.toString();

      if (centre.isEmpty || rawDate == null) {
        return ApiResponse(
          success: false,
          message: 'Centre and date are required to save a proforma',
        );
      }
      if (purchaseEntryId == null || purchaseEntryId.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'purchaseEntryId is required to save a proforma',
        );
      }

      // Normalize to midnight so multiple purchase entries on the same
      // calendar day resolve to the same key, regardless of what time
      // each entry was generated.
      final parsedDate = rawDate is String ? DateTime.parse(rawDate) : rawDate as DateTime;
      final normalizedDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      final normalizedDateStr = normalizedDate.toIso8601String();

      // Clean up any stale contribution left behind on a different day/centre
      // before writing the fresh one below.
      await _removeStaleProformaContribution(
        user.uid,
        purchaseEntryId,
        currentDate: normalizedDateStr,
        currentCentre: centre,
      );

      final entry = Map<String, dynamic>.from(data)
        ..remove('centre')
        ..remove('date')
        ..remove('userId')
        ..remove('purchaseEntryId');

      final existing = await _db
          .collection('proformas')
          .where('userId', isEqualTo: user.uid)
          .where('centre', isEqualTo: centre)
          .where('date', isEqualTo: normalizedDateStr)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final existingEntries = Map<String, dynamic>.from(
          (doc.data()['entries'] as Map?) ?? {},
        );
        // Overwrite this purchase entry's own slot — never additive here,
        // so re-generating an already-saved entry replaces it cleanly
        // instead of double-counting its values.
        existingEntries[purchaseEntryId] = entry;

        await doc.reference.update({
          ..._recomputeProformaTotals(existingEntries),
          'entries': existingEntries,
          'date': normalizedDateStr,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return ApiResponse(
          success: true,
          message: 'Proforma updated',
          data: {'id': doc.id},
        );
      }

      // No proforma yet for this centre + day — create the first one.
      final entries = {purchaseEntryId: entry};
      final docRef = await _db.collection('proformas').add({
        ..._recomputeProformaTotals(entries),
        'userId': user.uid,
        'centre': centre,
        'date': normalizedDateStr,
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
      }

      // Firestore can't query "does this map contain this key" directly, so
      // we scan the user's proformas and check the entries map client-side.
      // Per-user proforma counts are small in practice, so this stays fast.
      final query = await _db.collection('proformas').where('userId', isEqualTo: user.uid).get();

      for (final doc in query.docs) {
        final data = doc.data();
        final entries = data['entries'];
        if (entries is Map && entries.containsKey(purchaseEntryId)) {
          data['id'] = doc.id;
          return ApiResponse(
            success: true,
            message: 'Proforma found',
            data: {'proforma': data},
          );
        }
      }

      // Fall back to the older schema (a singular purchaseEntryId field on
      // the doc, from before day-wise merging existed) so old links keep working.
      final legacy = await _db
          .collection('proformas')
          .where('userId', isEqualTo: user.uid)
          .where('purchaseEntryId', isEqualTo: purchaseEntryId)
          .limit(1)
          .get();

      if (legacy.docs.isNotEmpty) {
        final doc = legacy.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return ApiResponse(
          success: true,
          message: 'Proforma found',
          data: {'proforma': data},
        );
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

  static Future<ApiResponse> deleteProforma(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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

  // Add this method to check if entry exists (used for validation)
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
        return ApiResponse(
          success: false,
          message: 'User not logged in',
        );
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

}

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({required this.success, required this.message, this.data});
}