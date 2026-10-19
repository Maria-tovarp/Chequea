import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppBottomMenuSection { home, sent, references }

class AppBottomMenu extends StatelessWidget {
  const AppBottomMenu({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onSent,
    required this.onReferences,
    required this.onCommissions,
  });

  final AppBottomMenuSection selected;
  final VoidCallback onHome;
  final VoidCallback onSent;
  final VoidCallback onReferences;
  final VoidCallback onCommissions;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD5DEF0))),
      ),
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: _MenuItem(
              label: 'Inicio',
              asset: 'assets/svg/Icono-Inactivo-Inicio-Botonera.svg',
              selected: selected == AppBottomMenuSection.home,
              onPressed: onHome,
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _MenuItem(
              label: 'Enviados',
              asset: 'assets/svg/Icono de enviados - líneas celeste.svg',
              selected: selected == AppBottomMenuSection.sent,
              onPressed: onSent,
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _MenuItem(
              label: 'Referencias',
              asset: 'assets/svg/Icono de referencias - líneas celestes.svg',
              selected: selected == AppBottomMenuSection.references,
              onPressed: onReferences,
            ),
          ),
          const _MenuDivider(),
          Expanded(
            child: _MenuItem(
              label: 'Comisiones',
              asset: 'assets/svg/Icono de comisiones - líneas gris.svg',
              onPressed: onCommissions,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 42,
    child: VerticalDivider(color: Color(0xFFD5DEF0)),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.asset,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final String asset;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF009FA4) : const Color(0xFF10264C);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: 29,
            height: 29,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
