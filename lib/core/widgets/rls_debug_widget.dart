import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/rls_test_service.dart';

/// Widget flotante para ejecutar tests de RLS (solo en desarrollo)
/// Muestra un botón pequeño en la esquina que abre un panel de pruebas
class RLSDebugWidget extends ConsumerWidget {
  const RLSDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // El contenido normal de la página va aquí
        Scaffold(
          body: Container(),
        ),

        // Botón flotante de debug (esquina inferior derecha)
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.orange.withOpacity(0.8),
            onPressed: () {
              _showRLSTestModal(context);
            },
            tooltip: 'RLS Debug Tests',
            child: const Icon(Icons.bug_report),
          ),
        ),
      ],
    );
  }

  void _showRLSTestModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RLSTestPanel(),
    );
  }
}

class _RLSTestPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RLSTestPanel> createState() => _RLSTestPanelState();
}

class _RLSTestPanelState extends ConsumerState<_RLSTestPanel> {
  bool _isRunning = false;
  Map<String, dynamic>? _results;
  String _logs = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RLS Test Suite',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),

            // Botón para ejecutar tests
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runTests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRunning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Run All RLS Tests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Resultados
            if (_results != null) ...[
              Text(
                'Results:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildResultsWidget(_results!),
              const SizedBox(height: 16),
            ],

            // Logs
            if (_logs.isNotEmpty) ...[
              Text(
                'Debug Logs:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  _logs,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsWidget(Map<String, dynamic> results) {
    final allPassed = results['all_passed'] as bool;
    final testResults = results['results'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status global
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: allPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: allPassed ? Colors.green : Colors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allPassed ? Icons.check_circle : Icons.error,
                color: allPassed ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                allPassed ? 'All tests PASSED ✓' : 'Some tests FAILED ✗',
                style: TextStyle(
                  color: allPassed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Resultados individuales
        ...testResults.entries.map((entry) {
          final testName = entry.key;
          final result = entry.value as Map<String, dynamic>;
          final success = result['success'] as bool;
          final details = result['details'] as String?;
          final error = result['error'] as String?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: success ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: success ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        success ? Icons.check : Icons.warning,
                        color: success ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        testName.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: success ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Error: $error',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _logs = 'Ejecutando tests...\n';
    });

    try {
      final service = RLSTestService();
      final results = await service.runAllTests();

      setState(() {
        _results = results;
        _logs += '\n✓ Tests completados exitosamente';
      });
    } catch (e) {
      setState(() {
        _logs += '\n✗ Error durante tests: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}
