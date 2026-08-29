import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '../models/alarm.dart';
import '../utils/photo_similarity.dart';

class PhotoMission extends StatefulWidget {
  final MissionDifficulty difficulty;
  final String? referencePhotoPath;
  final VoidCallback onComplete;

  const PhotoMission({
    super.key,
    required this.difficulty,
    required this.referencePhotoPath,
    required this.onComplete,
  });

  @override
  State<PhotoMission> createState() => _PhotoMissionState();
}

class _PhotoMissionState extends State<PhotoMission> {
  final _picker = ImagePicker();
  XFile? _photo;
  bool _capturing = false;
  bool _checking = false;
  bool? _matched;
  String? _error;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    setState(() {
      _capturing = true;
      _error = null;
      _matched = null;
    });
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (photo == null) {
        setState(() {
          _capturing = false;
          _error = 'No photo taken — try again';
        });
        return;
      }
      setState(() {
        _photo = photo;
        _capturing = false;
      });
      await _checkMatch();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Could not open camera — try again';
      });
    }
  }

  Future<void> _checkMatch() async {
    final referencePath = widget.referencePhotoPath;
    final photo = _photo;
    if (referencePath == null || photo == null) {
      // No reference was saved for this alarm (older alarm created before
      // this feature) — fall back to honor system.
      setState(() => _matched = true);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final match = await PhotoSimilarity.isSimilar(referencePath, photo.path);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _matched = match;
      if (!match) _failedAttempts++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_capturing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Opening camera...', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    if (_checking) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Checking your photo...', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    if (_photo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 64, color: context.wake.physics),
            const SizedBox(height: 16),
            Text(
              'Take a photo of your notes to match the one you set',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.wake.accent)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            ),
          ],
        ),
      );
    }

    final matched = _matched ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_photo!.path), height: 220, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          if (matched) ...[
            Icon(Icons.check_circle, color: context.wake.done, size: 32),
            const SizedBox(height: 8),
            Text(
              'Matches your notes!',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ] else ...[
            Icon(Icons.error_outline, color: context.wake.accent, size: 32),
            const SizedBox(height: 8),
            Text(
              "Doesn't look like the same notes — retake in better light",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 20),
          if (matched)
            FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                minimumSize: const Size(240, 52),
                backgroundColor: context.wake.done,
              ),
              child: const Text('Confirm & Stop Alarm'),
            )
          else
            FilledButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Retake Photo'),
              style: FilledButton.styleFrom(minimumSize: const Size(240, 52)),
            ),
          if (!matched && _failedAttempts >= 1) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onComplete,
              child: Text(
                "Still not matching? Override & stop alarm",
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
