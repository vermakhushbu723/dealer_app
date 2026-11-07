import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/app_bottom_nav.dart';

/// From this width on (a laptop or desktop browser) the app gets a web layout: a sidebar
/// instead of the bottom bar, with the pages in a centred column. Phones keep the app look.
const double wideLayoutWidth = 900;

/// Tells the tab shell whether the sidebar is showing, so it can hide the bottom bar.
class WideLayout extends InheritedWidget {
  const WideLayout({super.key, required this.wide, required super.child});

  final bool wide;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WideLayout>()?.wide ?? false;

  @override
  bool updateShouldNotify(WideLayout old) => old.wide != wide;
}

class WebFrame extends StatefulWidget {
  const WebFrame({
    super.key,
    required this.router,
    required this.tabs,
    required this.tabRoutes,
    required this.signedOutRoutes,
    required this.child,
  });

  final GoRouter router;
  final List<NavTab> tabs;
  final List<String> tabRoutes;

  /// Login and other screens shown before the user is signed in: no sidebar there.
  final Set<String> signedOutRoutes;
  final Widget child;

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  String _location = '';
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  @override
  void didUpdateWidget(WebFrame old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_onRoute);
      widget.router.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final config = widget.router.routerDelegate.currentConfiguration;
    final location = config.isEmpty ? '' : config.uri.path;
    var selected = _selected;
    // A page inside a tab, such as /orders/42, keeps that tab lit.
    for (final (i, route) in widget.tabRoutes.indexed) {
      if (location == route || (route != '/' && location.startsWith('$route/'))) selected = i;
    }
    if (location == _location && selected == _selected) return;
    // The delegate can notify while a frame is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _location = location;
        _selected = selected;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    if (!wide) return WideLayout(wide: false, child: widget.child);

    final signedOut = _location.isEmpty || widget.signedOutRoutes.contains(_location);
    final page = ColoredBox(
      color: const Color(0xFFEEF3F8),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: signedOut ? 520 : 1040),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24)],
            ),
            child: ClipRect(child: widget.child),
          ),
        ),
      ),
    );
    if (signedOut) return WideLayout(wide: true, child: page);
    return WideLayout(
      wide: true,
      child: Row(
        children: [
          _Sidebar(
            tabs: widget.tabs,
            selected: _selected,
            onTap: (i) => widget.router.go(widget.tabRoutes[i]),
          ),
          Expanded(child: page),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.tabs, required this.selected, required this.onTap});

  final List<NavTab> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 248,
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(AppConstants.logo, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppConstants.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.headingFont,
                          fontSize: AppTextStyles.lg,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, tab) in tabs.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: _SideItem(tab: tab, selected: i == selected, onTap: () => onTap(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.tab, required this.selected, required this.onTap});

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.sky700 : AppColors.neutral500;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.sky100 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                tab.label,
                style: TextStyle(
                  fontFamily: AppTextStyles.bodyFont,
                  fontSize: AppTextStyles.sm,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
