import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void showCommissionsComingSoonDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F9F7),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/svg/dollar-symbol-circle-comisiones.svg',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tus comisiones estarán aquí',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF10264C),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Muy pronto podrás consultar tus comisiones, revisar el detalle de tus referencias y conocer el estado de tus pagos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF647194),
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: const Text('ENTENDIDO'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF009FA4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: const Color(0xFFF0F2F6),
                foregroundColor: const Color(0xFF647194),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
