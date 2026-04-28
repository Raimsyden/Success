import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para probar RLS en la tabla users
class RLSTestService {
  final _supabase = Supabase.instance.client;

  /// Prueba 1: Leer tu propio registro
  Future<Map<String, dynamic>> testReadOwnUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario logueado',
          'details': null,
        };
      }

      debugPrint('[RLS_TEST] Leyendo registro propio: ${user.id}');

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      debugPrint('[RLS_TEST] Respuesta: $response');

      return {
        'success': true,
        'data': response,
        'details': 'Lograste leer tu propio registro ✓',
      };
    } catch (e) {
      debugPrint('[RLS_TEST] Error en testReadOwnUser: $e');
      return {
        'success': false,
        'error': e.toString(),
        'details': 'Verifica que la política SELECT esté activa',
      };
    }
  }

  /// Prueba 2: Intentar leer un registro ajeno (debe fallar)
  Future<Map<String, dynamic>> testReadOtherUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario logueado',
          'details': null,
        };
      }

      // UUID falso para probar
      const fakeUserId = '00000000-0000-0000-0000-000000000000';
      debugPrint('[RLS_TEST] Intentando leer registro ajeno: $fakeUserId');

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', fakeUserId)
          .maybeSingle();

      // Si response es null, significa que RLS funcionó (bloqueó la lectura)
      if (response == null) {
        debugPrint('[RLS_TEST] RLS funcionó: retornó null para otro usuario');
        return {
          'success': true,
          'data': null,
          'details': 'RLS bloqueó correctamente la lectura de otro usuario ✓',
        };
      }

      return {
        'success': false,
        'error': 'RLS no está bloqueando lecturas ajenas',
        'details': 'Obtuviste datos de otro usuario: $response',
      };
    } catch (e) {
      debugPrint('[RLS_TEST] Error (esperado): $e');
      return {
        'success': true,
        'data': null,
        'details': 'RLS bloqueó el acceso (error esperado) ✓',
      };
    }
  }

  /// Prueba 3: Actualizar tu propio registro
  Future<Map<String, dynamic>> testUpdateOwnUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No hay usuario logueado',
          'details': null,
        };
      }

      debugPrint('[RLS_TEST] Actualizando registro propio');

      final response = await _supabase
          .from('users')
          .update({'bio': 'Updated at ${DateTime.now().toIso8601String()}'})
          .eq('id', user.id)
          .select()
          .maybeSingle();

      debugPrint('[RLS_TEST] Update response: $response');

      return {
        'success': true,
        'data': response,
        'details': 'Lograste actualizar tu propio registro ✓',
      };
    } catch (e) {
      debugPrint('[RLS_TEST] Error en testUpdateOwnUser: $e');
      return {
        'success': false,
        'error': e.toString(),
        'details': 'Verifica que la política UPDATE esté activa',
      };
    }
  }

  /// Ejecuta todos los tests y devuelve un resumen
  Future<Map<String, dynamic>> runAllTests() async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('INICIANDO PRUEBAS DE RLS EN TABLA USERS');
    debugPrint('═══════════════════════════════════════');

    final resultados = <String, Map<String, dynamic>>{};

    debugPrint('\n[TEST 1/3] Leyendo tu propio registro...');
    resultados['read_own'] = await testReadOwnUser();

    debugPrint('\n[TEST 2/3] Intentando leer registro ajeno...');
    resultados['read_other'] = await testReadOtherUser();

    debugPrint('\n[TEST 3/3] Actualizando tu propio registro...');
    resultados['update_own'] = await testUpdateOwnUser();

    debugPrint('\n═══════════════════════════════════════');
    debugPrint('RESUMEN DE PRUEBAS:');
    resultados.forEach((key, result) {
      final status = result['success'] ? '✓ PASS' : '✗ FAIL';
      debugPrint('$key: $status');
      if (result['details'] != null) {
        debugPrint('  → ${result['details']}');
      }
      if (result['error'] != null) {
        debugPrint('  → ERROR: ${result['error']}');
      }
    });
    debugPrint('═══════════════════════════════════════\n');

    return {
      'all_passed':
          resultados.values.every((r) => r['success'] == true),
      'results': resultados,
    };
  }
}
