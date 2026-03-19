
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../core/providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Bank controllers
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  // Colors matching the design system
  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webEmerald = Color(0xFF1A685B);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webTextDark = Color(0xFF1F2937);
  static const Color webTextGray = Color(0xFF4B5563);
  static const Color webBorderGray = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phoneNumber ?? "";
    }
    
    // Fetch bank account if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.fetchBankAccount();
      final bank = authProvider.bankAccount;
      if (bank != null) {
        _bankNameController.text = bank.bankCode;
        _accountNumberController.text = bank.accountNumber;
        _accountHolderController.text = bank.accountHolderName;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final success = await authProvider.updateAvatar(image.path);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar updated successfully!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bank = authProvider.bankAccount;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(color: webTextDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop() 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: webTextDark),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                // Cancel
                setState(() {
                  _isEditing = false;
                  _nameController.text = user.fullName;
                  _phoneController.text = user.phoneNumber ?? "";
                  if (bank != null) {
                    _bankNameController.text = bank.bankCode;
                    _accountNumberController.text = bank.accountNumber;
                    _accountHolderController.text = bank.accountHolderName;
                  }
                });
              } else {
                // Toggle Edit
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? "Cancel" : "Edit",
              style: const TextStyle(color: webPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: webPrimary.withValues(alpha: 0.2), width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: user.avatarUrl != null 
                              ? NetworkImage(user.avatarUrl!) 
                              : null,
                          child: user.avatarUrl == null
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (authProvider.isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                      if (_isEditing && !authProvider.isLoading)
                        GestureDetector(
                          onTap: _pickImage,
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: webPrimary,
                            child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: webTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: webEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: const TextStyle(
                        color: webEmerald,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Profile Information Section
            _buildSectionTitle("PERSONAL INFORMATION"),
            _buildProfileSection([
              _buildEditableRow(
                icon: Icons.person_outline,
                label: "Full Name",
                controller: _nameController,
                isEditing: _isEditing,
              ),
              _buildEditableRow(
                icon: Icons.phone_android_outlined,
                label: "Phone",
                controller: _phoneController,
                isEditing: _isEditing,
                keyboardType: TextInputType.phone,
              ),
              _buildStaticRow(
                icon: Icons.email_outlined,
                label: "Email",
                value: user.email,
              ),
              _buildStaticRow(
                icon: Icons.verified_user_outlined,
                label: "Identity Verified",
                value: user.verified ? "Verified" : "Unverified",
                valueColor: user.verified ? webEmerald : Colors.grey,
              ),
            ]),

            const SizedBox(height: 16),

            // Bank Details Section
            _buildSectionTitle("FINANCIAL SETTINGS"),
            _buildProfileSection([
              _buildEditableRow(
                icon: Icons.account_balance_outlined,
                label: "Linked Bank",
                controller: _bankNameController,
                isEditing: _isEditing,
                hintText: "Enter Bank Name (e.g. MB Bank)",
              ),
              _buildEditableRow(
                icon: Icons.account_circle_outlined,
                label: "Account Holder",
                controller: _accountHolderController,
                isEditing: _isEditing,
                hintText: "Enter Full Name",
              ),
              _buildEditableRow(
                icon: Icons.numbers,
                label: "Account Number",
                controller: _accountNumberController,
                isEditing: _isEditing,
                keyboardType: TextInputType.number,
                hintText: "Enter Card/Account Number",
              ),
              if (bank != null)
                _buildStaticRow(
                  icon: Icons.check_circle_outline,
                  label: "Status",
                  value: bank.status,
                  valueColor: bank.status == 'VERIFIED' ? webEmerald : Colors.orange,
                ),
            ]),

            const SizedBox(height: 24),

            // Save changes button (only visible when editing)
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    if (authProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: authProvider.isLoading ? null : () async {
                        // 1. Update Profile info
                        final profileSuccess = await authProvider.updateProfile(
                          _nameController.text,
                          _phoneController.text,
                        );
                        
                        // 2. Update Bank info
                        final bankSuccess = await authProvider.saveBankAccount(
                          _bankNameController.text,
                          _accountNumberController.text,
                          _accountHolderController.text,
                        );

                        if (profileSuccess && bankSuccess) {
                          if (!context.mounted) return;
                          setState(() => _isEditing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Profile and Bank details updated!")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: webPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: webPrimary.withValues(alpha: 0.4),
                      ),
                      child: authProvider.isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save All Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Quick Access Section
            _buildSectionTitle("QUICK ACCESS"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildQuickAction(Icons.favorite_outline, "Impact"),
                  _buildQuickAction(Icons.folder_open_outlined, "Campaigns"),
                  _buildQuickAction(Icons.calendar_month_outlined, "Appointments"),
                  _buildQuickAction(Icons.flag_outlined, "Reports"),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Log Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton.icon(
                onPressed: () {
                  authProvider.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12, top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9CA3AF),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: webBorderGray),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStaticRow({required IconData icon, required String label, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: webBgGray, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: webTextGray),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: webTextGray)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? webTextDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: webBgGray, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: isEditing ? webPrimary : webTextGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: webTextGray)),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: webTextDark),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      hintText: hintText ?? "Enter value",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
                    ),
                  )
                else
                  Text(
                    controller.text.isEmpty ? "Not set" : controller.text,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: webTextDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: webBorderGray),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: webPrimary),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: webTextDark),
          ),
        ],
      ),
    );
  }
}

