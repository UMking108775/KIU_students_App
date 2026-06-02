import 'package:flutter/material.dart';

/// Controller for SlideDrawer to manage open/close state
class ZoomDrawerController extends ChangeNotifier {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void open() {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
  }

  void close() {
    if (_isOpen) {
      _isOpen = false;
      notifyListeners();
    }
  }
}

/// A simple slide drawer that pushes main screen to the right
class ZoomDrawer extends StatefulWidget {
  final Widget menuScreen;
  final Widget mainScreen;
  final ZoomDrawerController controller;
  final double drawerWidth;
  final Color backgroundColor;
  final Duration duration;

  const ZoomDrawer({
    super.key,
    required this.menuScreen,
    required this.mainScreen,
    required this.controller,
    this.drawerWidth = 280.0,
    this.backgroundColor = Colors.white,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<ZoomDrawer> createState() => _ZoomDrawerState();
}

class _ZoomDrawerState extends State<ZoomDrawer> with TickerProviderStateMixin {
  AnimationController? _animationController;
  double _slideValue = 0.0;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    widget.controller.addListener(_handleControllerChange);
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animationController!.addListener(() {
      if (mounted) {
        setState(() {
          _slideValue = widget.drawerWidth * _animationController!.value;
        });
      }
    });
  }

  void _handleControllerChange() {
    if (_animationController == null) return;
    if (widget.controller.isOpen) {
      _animationController!.forward();
    } else {
      _animationController!.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationController == null) {
      // Fallback - shouldn't happen but safe
      return widget.mainScreen;
    }

    final animValue = _animationController!.value;

    return Stack(
      children: [
        // Drawer Menu (Left side, fixed position)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.drawerWidth,
          child: Material(
            color: widget.backgroundColor,
            elevation: 0,
            child: widget.menuScreen,
          ),
        ),

        // Main Screen (Slides to the right)
        Transform.translate(
          offset: Offset(_slideValue, 0),
          child: Stack(
            children: [
              // Main content with shadow when open
              Container(
                decoration: BoxDecoration(
                  boxShadow: animValue > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(-5, 0),
                          ),
                        ]
                      : null,
                ),
                child: widget.mainScreen,
              ),
              // Tap overlay to close drawer
              if (animValue > 0.01)
                GestureDetector(
                  onTap: () => widget.controller.close(),
                  onHorizontalDragUpdate: (details) {
                    if (details.delta.dx < -8) {
                      widget.controller.close();
                    }
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2 * animValue),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
