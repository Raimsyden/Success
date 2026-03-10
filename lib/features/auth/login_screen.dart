import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {

  // Controladores de los campos de texto
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  // Estados locales
  bool _obscurePassword = true;
  bool _isLoading       = false;

  // Controlador de animación de entrada
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    // Animación de entrada al abrir la pantalla
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

    // Inicia la animación al abrir la pantalla
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── LOGIN ────────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    debugPrint('[Login] iniciando login...');
    // Valida que los campos estén correctos antes de enviar
    if (!_formKey.currentState!.validate()) {
      debugPrint('[Login] validación falló');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('[Login] llamando authNotifier.signIn...');
      await ref.read(authNotifierProvider.notifier).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      debugPrint('[Login] signIn completado, navegando a /feed');
      // Si el login fue exitoso, GoRouter redirige automáticamente al feed
      
      if (mounted) {
        debugPrint('[Login] llamando context.go(/feed)');
        context.go('/feed');
      }

    } catch (e) {
      debugPrint('[Login] error capturado: $e');
      // Muestra error si algo salió mal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e.toString())),
            backgroundColor: Colors.redAccent.withOpacity(0.9),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Convierte errores técnicos en mensajes amigables
  String _parseError(String error) {
    if (error.contains('Email not confirmed')) {
      return 'Revisa tu correo para confirmar tu cuenta antes de iniciar sesión';
    }
    if (error.contains('Invalid login')) {
      return 'Correo o contraseña incorrectos';
    }
    if (error.contains('network')) {
      return 'Sin conexión. Verifica tu internet';
    }
    return 'Ocurrió un error. Intenta de nuevo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── ORBES DE FONDO ─────────────────────────────────────────────
          _buildBackgroundOrbs(),

          // ─── CONTENIDO ──────────────────────────────────────────────────
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
                        const SizedBox(height: 60),

                        // Logo
                        _buildLogo(),
                        const SizedBox(height: 48),

                        // Campo email
                        _buildEmailField(),
                        const SizedBox(height: 16),

                        // Campo contraseña
                        _buildPasswordField(),
                        const SizedBox(height: 12),

                        // Olvidé mi contraseña
                        _buildForgotPassword(),
                        const SizedBox(height: 28),

                        // Botón login
                        _buildLoginButton(),
                        const SizedBox(height: 24),

                        // Divider
                        _buildDivider(),
                        const SizedBox(height: 24),

                        // Botón Google
                        _buildGoogleButton(),
                        const SizedBox(height: 40),

                        // Ir a registro
                        _buildRegisterLink(),
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

  // ─── WIDGETS PRIVADOS ─────────────────────────────────────────────────────

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        // Orbe peach arriba derecha
        Positioned(
          top: -80, right: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.peach.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Orbe mint abajo izquierda
        Positioned(
          bottom: 100, left: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.mint.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Suc',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cream,
                ),
              ),
              TextSpan(
                text: 'cess',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: AppColors.peach,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Conecta · Emprende · Crece',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mint,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color: AppColors.cream,
        fontSize: 15,
      ),
      decoration: const InputDecoration(
        labelText: 'CORREO ELECTRÓNICO',
        hintText: 'tu@correo.com',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingresa tu correo';
        }
        if (!value.contains('@')) {
          return 'Correo inválido';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(
        color: AppColors.cream,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: 'CONTRASEÑA',
        hintText: '••••••••',
        // Botón para mostrar/ocultar contraseña
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
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
        if (value == null || value.isEmpty) {
          return 'Ingresa tu contraseña';
        }
        if (value.length < 6) {
          return 'Mínimo 6 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          // TODO: navegar a pantalla de recuperar contraseña
        },
        child: Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedButton(
      onTap: _isLoading ? null : _handleLogin,
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
                  'Iniciar Sesión',
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o continúa con',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.cream.withOpacity(0.3),
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return AnimatedButton(
      onTap: () {
        // TODO: implementar login con Google
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono de Google con los colores reales
            SizedBox(
              width: 20, height: 20,
              child: CustomPaint(painter: _GoogleIconPainter()),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continuar con Google',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: GestureDetector(
        onTap: () => context.go('/register'),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '¿No tienes cuenta? ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.cream.withOpacity(0.4),
                  fontFamily: 'DM Sans',
                ),
              ),
              const TextSpan(
                text: 'Regístrate gratis',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.peach,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'DM Sans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── BOTÓN CON ANIMACIÓN SPRING ───────────────────────────────────────────
// Widget reutilizable para cualquier botón con efecto de escala suave
// Uso: AnimatedButton(onTap: () {}, child: tuWidget)
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AnimatedButton({super.key, required this.child, this.onTap});

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

// ─── ÍCONO DE GOOGLE ──────────────────────────────────────────────────────
// Dibuja el ícono de Google con sus colores reales usando Canvas
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cuatro sectores de colores
    final colors = [
      const Color(0xFFEA4335), // Rojo
      const Color(0xFFFBBC04), // Amarillo
      const Color(0xFF34A853), // Verde
      const Color(0xFF4285F4), // Azul
    ];

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (i * 90 - 90) * (3.14159 / 180),
        90 * (3.14159 / 180),
        true,
        paint,
      );
    }

    // Círculo central para efecto donut
    paint.color = AppColors.background;
    canvas.drawCircle(center, radius * 0.6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}