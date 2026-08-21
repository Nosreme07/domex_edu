import 'package:flutter/material.dart';

class DomexLayoutResponsivo extends StatelessWidget {
  final Widget menuLateralWeb;
  final Widget menuInferiorMobile;
  final Widget corpoDaPagina;

  const DomexLayoutResponsivo({
    super.key,
    required this.menuLateralWeb,
    required this.menuInferiorMobile,
    required this.corpoDaPagina,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ponto de quebra (Breakpoint) para Web/Desktop
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                // Na Web, exibe o Menu Lateral (Sidebar)
                SizedBox(
                  width: 250,
                  child: menuLateralWeb,
                ),
                // O conteúdo principal ocupa o resto da tela
                Expanded(
                  child: corpoDaPagina,
                ),
              ],
            ),
          );
        } 
        // Ponto de quebra (Breakpoint) para Mobile/Tablet
        else {
          return Scaffold(
            body: corpoDaPagina,
            // No Mobile, exibe o Menu Inferior
            bottomNavigationBar: menuInferiorMobile,
          );
        }
      },
    );
  }
}