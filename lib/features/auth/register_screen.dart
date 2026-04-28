import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import 'login_screen.dart' show AnimatedButton;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading       = false;
  String _selectedRole  = 'client'; // rol por defecto

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── REGISTRO ─────────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Verificar si el username ya está tomado
      final authService = ref.read(authServiceProvider);
      final available = await authService.isUsernameAvailable(
        _usernameController.text.trim(),
      );

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ese nombre de usuario ya está en uso'),
            ),
          );
        }
        return;
      }

      // Crear la cuenta
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        role: _selectedRole,
      );
      
      // Importante: hacer logout después del registro para que el usuario
      // no quede logueado automáticamente
      await authService.signOut();

      if (mounted) {
        // Mostrar mensaje de confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada! Revisa tu correo para confirmarla'),
          ),
        );
        context.go('/login');
      }

    } catch (e) {
      // Log completo para depuración en consola
      debugPrint('Register error: ${e.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error) {
    final e = error.toLowerCase();
    if (e.contains('already registered') || e.contains('already exists')) {
      return 'Este correo ya tiene una cuenta';
    }
    if (e.contains('password') || e.contains('password length') || e.contains('password should')) {
      return 'La contraseña debe tener mínimo 6 caracteres';
    }
    if (e.contains('network') || e.contains('timeout')) {
      return 'Sin conexión. Verifica tu internet';
    }
    if (e.contains('could not find the table')) {
      // caso típico cuando la tabla 'users' no existe en la base
      return 'Error interno: falta tabla de usuarios en la base de datos';
    }
    if (e.contains('duplicate') || e.contains('unique') || e.contains('username')) {
      return 'El nombre de usuario o correo ya están en uso';
    }
    return 'Ocurrió un error. Intenta de nuevo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackgroundOrbs(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildFullNameField(),
                        const SizedBox(height: 16),
                        _buildUsernameField(),
                        const SizedBox(height: 16),
                        _buildEmailField(),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                        const SizedBox(height: 28),
                        _buildRoleSelector(),
                        const SizedBox(height: 32),
                        _buildRegisterButton(),
                        const SizedBox(height: 28),
                        _buildLoginLink(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── WIDGETS ──────────────────────────────────────────────────────────────

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -60, left: -80,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.mint.withOpacity(0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 80, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.peach.withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: 'Suc',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: AppColors.cream,
              ),
            ),
            TextSpan(
              text: 'cess',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: AppColors.peach,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          'Crea tu cuenta gratis',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mint,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return TextFormField(
      controller: _fullNameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: AppColors.cream, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'NOMBRE COMPLETO',
        hintText: 'Juan Pérez',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa tu nombre';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      style: const TextStyle(color: AppColors.cream, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'NOMBRE DE USUARIO',
        hintText: 'juanperez',
        prefixText: '@',
        prefixStyle: TextStyle(
          color: AppColors.mint,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Elige un nombre de usuario';
        }
        if (value.contains(' ')) {
          return 'El usuario no puede tener espacios';
        }
        if (value.length < 3) {
          return 'Mínimo 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: AppColors.cream, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'CORREO ELECTRÓNICO',
        hintText: 'tu@correo.com',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa tu correo';
        if (!value.contains('@')) return 'Correo inválido';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: AppColors.cream, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'CONTRASEÑA',
        hintText: '••••••••',
        suffixIcon: IconButton(
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.mint,
            size: 20,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa una contraseña';
        if (value.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
    );
  }

  // ─── SELECTOR DE ROL ──────────────────────────────────────────────────────
  // El corazón de este formulario: elige quién eres en la app
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOY UN...',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppColors.mint,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                icon: '👤',
                label: 'Cliente',
                description: 'Exploro y compro',
                isSelected: _selectedRole == 'client',
                onTap: () => setState(() => _selectedRole = 'client'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleCard(
                icon: '🚀',
                label: 'Emprendedor',
                description: 'Vendo mis productos',
                isSelected: _selectedRole == 'entrepreneur',
                onTap: () => setState(() => _selectedRole = 'entrepreneur'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _RoleCard(
          icon: '🏢',
          label: 'Empresario',
          description: 'Empresa constituida con badge verificado',
          isSelected: _selectedRole == 'business',
          onTap: () => setState(() => _selectedRole = 'business'),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return AnimatedButton(
      onTap: _isLoading ? null : _handleRegister,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.peach, AppColors.peachDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.peach.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Crear Cuenta',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.background,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => context.go('/login'),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: '¿Ya tienes cuenta? ',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.cream.withOpacity(0.4),
                fontFamily: 'DM Sans',
              ),
            ),
            const TextSpan(
              text: 'Inicia sesión',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.peach,
                fontWeight: FontWeight.w600,
                fontFamily: 'DM Sans',
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── TARJETA DE ROL ───────────────────────────────────────────────────────
// Tarjeta seleccionable que representa cada tipo de usuario
// Se ilumina con borde peach cuando está seleccionada
class _RoleCard extends StatelessWidget {
  final String icon;
  final String label;
  final String description;
  final bool isSelected;
  final bool isWide;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isWide ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.peach.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.peach.withOpacity(0.6)
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: isWide
            ? Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.peach
                              : AppColors.cream,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.cream.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.peach,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: AppColors.background,
                      ),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 24)),
                      if (isSelected)
                        Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.peach,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 11,
                            color: AppColors.background,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.peach : AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.cream.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}