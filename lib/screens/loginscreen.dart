import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/apiservice.dart';
import '../utils/validators.dart';
import 'dashboardscreen.dart';

/// Metadata for a locally-remembered account.
/// The password itself is never stored here — only in secure storage,
/// keyed by email — this list just tracks who's been signed in on this
/// device so the switcher can show them.
class SavedAccount {
  final String email;
  final String mobile;
  final String username;
  final DateTime savedAt;

  SavedAccount({
    required this.email,
    required this.mobile,
    required this.username,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'mobile': mobile,
    'username': username,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    email: json['email'] as String,
    mobile: (json['mobile'] as String?) ?? '',
    username: (json['username'] as String?) ?? '',
    savedAt: DateTime.parse(json['savedAt'] as String),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _keepSignedIn = true;

  // Explicit mode toggle. Whether we're signing in or creating a new
  // account is now always a deliberate user choice - it's never guessed
  // from a Firebase error code (see apiservice.dart for why that was
  // causing intermittent login failures).
  bool _isRegisterMode = false;

  List<SavedAccount> _savedAccounts = [];
  String? _selectedAccountEmail;
  bool _isProgrammaticFill = false;

  // True while _fillAccount() is awaiting the password read from secure
  // storage. Used to block "Sign In" so a fast tap can't fire before the
  // form has actually finished filling.
  bool _isFillingAccount = false;

  static const _prefKeyAccounts = 'saved_accounts';
  static const _prefKeyLastActiveEmail = 'last_active_email';
  static String _passwordKeyFor(String email) => 'password_$email';

  // Initialize with Android-specific options for better compatibility
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // More reliable on newer Android versions
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  /// Platform-aware password storage - uses secure storage on mobile,
  /// falls back to shared_preferences on web where secure storage is unreliable.
  Future<void> _savePassword(String email, String password) async {
    try {
      if (kIsWeb) {
        // Web: Use shared_preferences (flutter_secure_storage is unreliable on web)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_passwordKeyFor(email), password);
        debugPrint('✅ Password saved to SharedPreferences for $email');
      } else {
        // Mobile: Use secure storage with retry logic
        bool saved = false;
        int retryCount = 0;

        while (!saved && retryCount < 3) {
          try {
            await _storage.write(key: _passwordKeyFor(email), value: password);
            saved = true;
            debugPrint('✅ Password saved to SecureStorage for $email (attempt ${retryCount + 1})');
          } catch (e) {
            retryCount++;
            debugPrint('⚠️ SecureStorage write attempt $retryCount failed: $e');
            if (retryCount >= 3) {
              // If secure storage fails after 3 attempts, fallback to shared_preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_passwordKeyFor(email), password);
              debugPrint('🔄 Fallback: Password saved to SharedPreferences for $email');
              saved = true;
            }
            // Wait a bit before retry
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to save password for $email: $e');
      rethrow;
    }
  }

  /// Platform-aware password retrieval - tries secure storage on mobile,
  /// falls back to shared_preferences on web.
  Future<String?> _getPassword(String email) async {
    try {
      String? password;

      if (kIsWeb) {
        // Web: Read from shared_preferences
        final prefs = await SharedPreferences.getInstance();
        password = prefs.getString(_passwordKeyFor(email));
        debugPrint('🔍 Web: Password ${password != null ? "found" : "not found"} for $email');
      } else {
        // Mobile: Read from secure storage with retry
        bool readSuccess = false;
        int retryCount = 0;

        while (!readSuccess && retryCount < 3) {
          try {
            password = await _storage.read(key: _passwordKeyFor(email));
            readSuccess = true;
            debugPrint('🔍 Mobile: Password ${password != null ? "found" : "not found"} for $email (attempt ${retryCount + 1})');
          } catch (e) {
            retryCount++;
            debugPrint('⚠️ SecureStorage read attempt $retryCount failed: $e');
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        // If still not found, check shared_preferences as fallback
        if (password == null) {
          final prefs = await SharedPreferences.getInstance();
          password = prefs.getString(_passwordKeyFor(email));
          if (password != null) {
            debugPrint('🔄 Found password in SharedPreferences fallback for $email');
            // Migrate back to secure storage if found in fallback
            try {
              await _storage.write(key: _passwordKeyFor(email), value: password);
              await prefs.remove(_passwordKeyFor(email));
              debugPrint('🔄 Migrated password from SharedPreferences to SecureStorage');
            } catch (e) {
              debugPrint('⚠️ Migration failed, keeping in SharedPreferences: $e');
            }
          }
        }
      }

      return password;
    } catch (e) {
      debugPrint('❌ Failed to read password for $email: $e');
      // If secure storage fails on mobile, try shared_preferences as fallback
      if (!kIsWeb) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final password = prefs.getString(_passwordKeyFor(email));
          if (password != null) {
            debugPrint('🔄 Retrieved password from SharedPreferences fallback for $email');
            return password;
          }
        } catch (fallbackError) {
          debugPrint('❌ Fallback also failed: $fallbackError');
        }
      }
      return null;
    }
  }

  /// Platform-aware password deletion
  Future<void> _deletePassword(String email) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_passwordKeyFor(email));
      } else {
        // Try secure storage delete with retry
        bool deleted = false;
        int retryCount = 0;

        while (!deleted && retryCount < 3) {
          try {
            await _storage.delete(key: _passwordKeyFor(email));
            deleted = true;
            debugPrint('🗑️ Password deleted from SecureStorage for $email');
          } catch (e) {
            retryCount++;
            debugPrint('⚠️ SecureStorage delete attempt $retryCount failed: $e');
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        // Also clean up any fallback entries
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_passwordKeyFor(email));
        debugPrint('🗑️ Password deleted from SharedPreferences for $email');
      }
    } catch (e) {
      debugPrint('❌ Failed to delete password for $email: $e');
    }
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyAccounts);

    List<SavedAccount> accounts = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        accounts = list
            .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
            .toList();
        accounts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        debugPrint('📚 Loaded ${accounts.length} saved accounts');
      } catch (e) {
        debugPrint('❌ Failed to parse saved accounts: $e');
        // Clear corrupted data
        await prefs.remove(_prefKeyAccounts);
      }
    }

    if (!mounted) return;
    setState(() => _savedAccounts = accounts);

    // Pre-fill with whichever account was last used, if any.
    final lastEmail = prefs.getString(_prefKeyLastActiveEmail);
    if (lastEmail != null && accounts.any((a) => a.email == lastEmail)) {
      await _fillAccount(lastEmail);
    }
  }

  Future<void> _saveAccountsList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_savedAccounts.map((a) => a.toJson()).toList());
    await prefs.setString(_prefKeyAccounts, raw);
    debugPrint('💾 Saved ${_savedAccounts.length} accounts');
  }

  // Adds/updates this account in the switcher list and stores its password
  // securely. Called after a successful login with "Keep me signed in" on.
  Future<void> _rememberAccount(
      String email, String password, String mobile, String username) async {
    final prefs = await SharedPreferences.getInstance();

    _savedAccounts.removeWhere((a) => a.email == email);
    _savedAccounts.insert(
      0,
      SavedAccount(
        email: email,
        mobile: mobile,
        username: username,
        savedAt: DateTime.now(),
      ),
    );

    await _saveAccountsList();
    await _savePassword(email, password);
    await prefs.setString(_prefKeyLastActiveEmail, email);

    if (mounted) setState(() {});
  }

  // Removes an account entirely from this device (switcher + stored password).
  Future<void> _forgetAccount(String email) async {
    _savedAccounts.removeWhere((a) => a.email == email);
    await _saveAccountsList();
    await _deletePassword(email);

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefKeyLastActiveEmail) == email) {
      await prefs.remove(_prefKeyLastActiveEmail);
    }

    if (_selectedAccountEmail == email) {
      _selectedAccountEmail = null;
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
    }

    if (mounted) setState(() {});
  }

  // Fills the form with a saved account's email + password so the user
  // only has to tap "Sign In" to switch.
  Future<void> _fillAccount(String email) async {
    setState(() {
      _isFillingAccount = true;
      _selectedAccountEmail = email;
    });

    String? password;
    bool storageFailed = false;

    try {
      password = await _getPassword(email);
      if (password == null) {
        storageFailed = true;
        debugPrint('⚠️ No password found for $email');
      }
    } catch (e, stackTrace) {
      storageFailed = true;
      debugPrint('❌ Failed to read stored password for $email: $e');
      debugPrint('$stackTrace');
    }

    if (!mounted) return;

    final account = _savedAccounts.firstWhere(
          (a) => a.email == email,
      orElse: () => SavedAccount(
        email: email,
        mobile: '',
        username: '',
        savedAt: DateTime.now(),
      ),
    );

    _isProgrammaticFill = true;
    setState(() {
      _emailController.text = email;
      _passwordController.text = password ?? '';
      _mobileController.text = account.mobile;
      _usernameController.text = account.username;
      _keepSignedIn = true;
      _isFillingAccount = false;
    });
    _isProgrammaticFill = false;

    if ((password == null || password.isEmpty) && mounted) {
      // Show a more helpful message with option to re-enter
      _showPasswordRequiredDialog(email);
    }
  }

  // Show dialog asking user to re-enter password
  Future<void> _showPasswordRequiredDialog(String email) async {
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Password Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please enter your password for $email',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onFieldSubmitted: (_) {
                      if (passwordController.text.isNotEmpty) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your password'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => isSubmitting = true);

                    // Save the password for future use
                    try {
                      await _savePassword(email, passwordController.text);
                      setDialogState(() => isSubmitting = false);
                      if (mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      if (mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save password: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Save & Continue',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldRetry == true && mounted) {
      setState(() {
        _passwordController.text = passwordController.text;
      });
      // Auto-submit after saving password
      _handleLogin();
    } else if (shouldRetry == false && mounted) {
      // User cancelled - clear the form
      _startNewAccount();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your password manually to continue'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Clears the form to start a fresh ("+ Add account") login.
  void _startNewAccount() {
    setState(() {
      _selectedAccountEmail = null;
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _usernameController.clear();
      _keepSignedIn = true;
    });
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final mobile = _mobileController.text.trim();
    final username = _usernameController.text.trim();

    final result = _isRegisterMode
        ? await ApiService.register(
      email: email,
      password: password,
      mobile: mobile,
      username: username,
      keepSignedIn: _keepSignedIn,
    )
        : await ApiService.login(
      email: email,
      password: password,
      mobile: mobile,
      username: username,
      keepSignedIn: _keepSignedIn,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.redAccent,
      ),
    );

    if (result.success) {
      try {
        if (_keepSignedIn) {
          await _rememberAccount(email, password, mobile, username);
        } else {
          await _forgetAccount(email);
        }
      } catch (e, stackTrace) {
        // Local device storage (SharedPreferences / secure storage) failed.
        // The user is still authenticated with Firebase at this point, so
        // don't let a storage hiccup strand them on the login screen —
        // just skip remembering this device and continue to the dashboard.
        debugPrint('Failed to save account locally: $e');
        debugPrint('$stackTrace');
        // Show warning but continue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in but failed to save locally'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      TextInput.finishAutofillContext();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  Future<void> _confirmForgetAccount(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove account?'),
        content: Text('$email will be removed from this device. You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _forgetAccount(email);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController =
    TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Reset your password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter your email and we'll send you a link to reset your password.",
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                      decoration: _inputDecoration(
                        hint: 'you@company.com',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                    if (!resetFormKey.currentState!.validate()) return;

                    setDialogState(() => isSending = true);

                    final result = await ApiService.sendPasswordReset(
                      email: resetEmailController.text.trim(),
                    );

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: result.success
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                  child: isSending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Send link',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            color: Color(0xFF38BDF8), size: 28),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isRegisterMode ? 'Create your account' : 'Welcome back',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegisterMode
                            ? 'Set up a new account for Workflo'
                            : 'Sign in to continue to Workflo',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),

                      if (_savedAccounts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _FieldLabel('Switch account'),
                        const SizedBox(height: 10),
                        _AccountSwitcherRow(
                          accounts: _savedAccounts,
                          selectedEmail: _selectedAccountEmail,
                          onSelect: (email) => _fillAccount(email),
                          onAddNew: _startNewAccount,
                          onRemove: _confirmForgetAccount,
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Username field
                      const _FieldLabel('Username'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.newUsername],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'Choose a username',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Email field
                      const _FieldLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        onChanged: (_) {
                          if (_isProgrammaticFill) return;
                          if (_selectedAccountEmail != null) {
                            setState(() => _selectedAccountEmail = null);
                          }
                        },
                        decoration: _inputDecoration(
                          hint: 'you@company.com',
                          icon: Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password field
                      const _FieldLabel('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: _inputDecoration(
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Mobile field
                      const _FieldLabel('Mobile number'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        validator: Validators.validateMobile,
                        decoration: _inputDecoration(
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _keepSignedIn,
                                  activeColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _keepSignedIn = v ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Keep me signed in',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                          (_isLoading || _isFillingAccount) ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            _isRegisterMode ? 'Create account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() => _isRegisterMode = !_isRegisterMode),
                          child: Text(
                            _isRegisterMode
                                ? 'Already have an account? Sign in'
                                : "New here? Create an account",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }
}

/// Horizontal row of saved-account chips, plus a trailing "+" chip to
/// start a login with a different account.
class _AccountSwitcherRow extends StatelessWidget {
  final List<SavedAccount> accounts;
  final String? selectedEmail;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddNew;
  final ValueChanged<String> onRemove;

  const _AccountSwitcherRow({
    required this.accounts,
    required this.selectedEmail,
    required this.onSelect,
    required this.onAddNew,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == accounts.length) {
            return _AddAccountChip(onTap: onAddNew);
          }
          final account = accounts[index];
          final isSelected = account.email == selectedEmail;
          return _AccountChip(
            key: ValueKey(account.email),
            account: account,
            isSelected: isSelected,
            onTap: () => onSelect(account.email),
            onRemove: () => onRemove(account.email),
          );
        },
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final SavedAccount account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AccountChip({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
  });

  String get _initial {
    if (account.username.isNotEmpty) return account.username[0].toUpperCase();
    return account.email.isNotEmpty ? account.email[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF38BDF8), width: 2)
                        : null,
                  ),
                  child: Text(
                    _initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              account.username.isNotEmpty
                  ? account.username
                  : account.email.split('@').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAccountChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAccountChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 22, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}