import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _validating = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'API key is required');
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    final valid = await appState.submitApiKey(key);
    if (!mounted) return;
    setState(() => _validating = false);
    if (!valid) {
      final networkError = appState.lastAuthError;
      setState(() => _error = networkError != null
          ? 'Could not reach RunPod: $networkError'
          : 'Invalid API key. Please check and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RunPod Manager')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dns, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Enter your RunPod API key to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('apiKeyField'),
                  controller: _controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('validateApiKeyButton'),
                  onPressed: _validating ? null : _submit,
                  child: _validating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Validate & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
