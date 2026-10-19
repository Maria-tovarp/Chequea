import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HeaderNoticeActions extends StatelessWidget {
  const HeaderNoticeActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Regalos',
        onPressed: () => showAppNoticeDialog(
          context,
          message:
              'En esta sección podrás recibir regalos por utilizar CHEQUEA.',
        ),
        icon: SvgPicture.asset(
          'assets/svg/giftbox-header.svg',
          width: 22,
          height: 22,
        ),
      ),
      IconButton(
        tooltip: 'Notificaciones',
        onPressed: () => showAppNoticeDialog(
          context,
          message: 'Esta función estará disponible pronto.',
        ),
        icon: SvgPicture.asset(
          'assets/svg/notification-4-svgrepo-com.svg',
          width: 34,
          height: 34,
        ),
      ),
    ],
  );
}

void showAppNoticeDialog(BuildContext context, {required String message}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 38),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 68,
              height: 68,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE5F8F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF009FA4),
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Próximamente',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF10264C),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF435678),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009FA4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
