import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';

/// Stub de inicio de sesión. Detrás del feature flag `AUTH_ENABLED`.
///
/// Implementa el envío de código OTP por correo con Supabase. **Todavía NO**
/// restringe por dominio institucional ni por matrícula: eso depende de la API
/// que defina el área de TI de la UES.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  bool _enviando = false;
  String? _mensaje;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!AppConfig.supabaseConfigurado) {
      setState(() => _mensaje =
          'Supabase no está configurado. Corre la app con --dart-define de '
              'SUPABASE_URL y SUPABASE_ANON_KEY.');
      return;
    }
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _email.text.trim(),
        shouldCreateUser: true,
      );
      setState(() =>
          _mensaje = 'Te enviamos un enlace / código a ${_email.text.trim()}.');
    } on AuthException catch (e) {
      setState(() => _mensaje = e.message);
    } catch (e) {
      setState(() => _mensaje = 'No se pudo enviar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Correo institucional',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Usa tu correo @${AppConfig.dominioInstitucional}. Te enviaremos un '
            'código para entrar, sin contraseñas.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'correo@ues.mx',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enviar código'),
          ),
          if (_mensaje != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_mensaje!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Nota: la validación de que el correo pertenezca a la UES (o el '
            'inicio de sesión por matrícula) se conectará cuando la Universidad '
            'proporcione el método oficial.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
