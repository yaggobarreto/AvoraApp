
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/image_upload.dart';
import '../../../core/theme/app_theme.dart';
import '../data/groups_repository.dart';
import '../domain/group.dart';
import 'group_avatar.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Group group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _repository = GroupsRepository();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;

  late Group _group;
  bool _isUploadingPhoto = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _nameController = TextEditingController(text: _group.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Raw exception text can carry hostnames and driver details, so it is
  /// logged rather than shown.
  void _showError(Object error) {
    debugPrint('Group settings error: $error');
    _showMessage('Não foi possível salvar. Tente novamente.');
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _repository.uploadGroupPhoto(
        _group.id,
        Uint8List.fromList(bytes),
        normalizeImageExtension(picked.name),
      );
      final updated = await _repository.setGroupPhoto(_group.id, url);
      if (mounted) setState(() => _group = updated);
    } on InvalidImageException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _chooseIcon(String icon) async {
    try {
      final updated = await _repository.setGroupIcon(_group.id, icon);
      if (mounted) setState(() => _group = updated);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == _group.name) return;

    setState(() => _isSavingName = true);
    try {
      final updated = await _repository.renameGroup(_group.id, name);
      if (mounted) setState(() => _group = updated);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The list behind this screen needs the edited group to refresh its card.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _group);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Personalizar grupo')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  GroupAvatar(group: _group, size: 110),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do grupo',
                suffixIcon: IconButton(
                  onPressed: _isSavingName ? null : _saveName,
                  icon: _isSavingName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                ),
              ),
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: 28),
            const Text(
              'Ou escolha um ícone',
              style: TextStyle(
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final icon in groupIconChoices)
                  GestureDetector(
                    onTap: () => _chooseIcon(icon),
                    child: Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _group.photoUrl == null && _group.icon == icon
                              ? AppTheme.brandTeal
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
