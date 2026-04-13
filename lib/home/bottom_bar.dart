// lib/home/bottom_bar.dart
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

class GenerationBottomBar extends StatelessWidget {
  final bool isGenerating;
  final bool serverOnline;
  final double progress;
  final String status;
  final String currentNode;
  final int elapsed;
  final String Function(int) fmtTime;
  final VoidCallback onGenerate;
  final VoidCallback onStop;
  final Uint8List? previewImage;

  const GenerationBottomBar({
    super.key,
    required this.isGenerating,
    required this.serverOnline,
    required this.progress,
    required this.status,
    required this.currentNode,
    required this.elapsed,
    required this.fmtTime,
    required this.onGenerate,
    required this.onStop,
    this.previewImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGenerating
              ? const Color(0x20FFFFFF)
              : const Color(0x12FFFFFF),
          width: 0.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGenerating && previewImage != null) _buildPreview(),
                // ── Status bar (новый) ──
                if (!isGenerating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: serverOnline
                                ? const Color(0xFF30D158)
                                : const Color(0xFFFF3B30),
                            boxShadow: [
                              BoxShadow(
                                color: (serverOnline
                                    ? const Color(0xFF30D158)
                                    : const Color(0xFFFF3B30))
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          serverOnline ? 'Ready' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: serverOnline
                                ? Colors.white.withValues(alpha: 0.4)
                                : const Color(0xFFFF3B30)
                                .withValues(alpha: 0.6),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {}, // можно привязать к настройкам
                          child: Icon(Icons.settings_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 52,
                  child: isGenerating ? _buildProgress() : _buildButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(previewImage!, fit: BoxFit.contain,
                gaplessPlayback: true),
            Positioned(
              bottom: 0, left: 0, right: 0, height: 32,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6, right: 8,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                ),
                child: const Text('PREVIEW',
                    style: TextStyle(
                        color: Color(0xFFFFD60A), fontSize: 9,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: const Color(0xFFFFD60A).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x0AFFFFFF)),
          ),
          child: Row(children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFFF0F0F0),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                value: progress > 0 ? progress : null,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$status  ${fmtTime(elapsed)}',
                      style: const TextStyle(
                          color: Color(0xFFF0F0F0), fontSize: 12,
                          fontWeight: FontWeight.w500, letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                  if (currentNode.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(currentNode,
                          style: const TextStyle(
                              color: Color(0xFF5A5A5E), fontSize: 10,
                              letterSpacing: -0.2),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onStop,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
            border: Border.all(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                width: 0.5),
          ),
          child: const Icon(Icons.stop_rounded,
              color: Color(0xFFFF3B30), size: 24),
        ),
      ),
    ]);
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: serverOnline ? onGenerate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: serverOnline
              ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0A84FF),
              Color(0xFFBF5AF2),
            ],
          )
              : null,
          color: serverOnline ? null : Colors.white.withValues(alpha: 0.03),
          border: serverOnline
              ? null
              : Border.all(color: const Color(0x08FFFFFF), width: 0.5),
          boxShadow: serverOnline
              ? [
            BoxShadow(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                serverOnline ? Icons.auto_awesome : Icons.cloud_off_outlined,
                size: 18,
                color: serverOnline
                    ? Colors.white
                    : const Color(0xFF4A4A4E),
              ),
              const SizedBox(width: 10),
              Text(
                serverOnline ? 'ГЕНЕРИРОВАТЬ' : 'Сервер недоступен',
                style: TextStyle(
                  fontSize: 14,
                  color: serverOnline ? Colors.white : const Color(0xFF4A4A4E),
                  fontWeight: FontWeight.w700,
                  letterSpacing: serverOnline ? 1.0 : -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
