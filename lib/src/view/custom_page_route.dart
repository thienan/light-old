import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// Fractional offset from 1/4 screen below the top to fully on screen.
final Tween<Offset> _kBottomUpTween = new Tween<Offset>(
  begin: const Offset(0.0, 0.25),
  end: Offset.zero,
);

// Used for Android and Fuchsia.
class _MountainViewPageTransition extends StatelessWidget {
  _MountainViewPageTransition({
    Key key,
    @required bool fade,
    @required Animation<double> routeAnimation,
    @required this.child,
  }) : _positionAnimation = _kBottomUpTween.animate(new CurvedAnimation(
    parent: routeAnimation, // The route's linear 0.0 - 1.0 animation.
    curve: Curves.fastOutSlowIn,
  )),
        _opacityAnimation = fade ? new CurvedAnimation(
          parent: routeAnimation,
          curve: Curves.easeIn, // Eyeballed from other Material apps.
        ) : const AlwaysStoppedAnimation<double>(1.0),
        super(key: key);

  final Animation<Offset> _positionAnimation;
  final Animation<double> _opacityAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TODO(ianh): tell the transform to be un-transformed for hit testing
    return new FadeTransition(
      opacity: _opacityAnimation,
      child: child,
    );
  }
}

class CustomPageRoute<T> extends PageRoute<T> {
  CustomPageRoute({
    @required this.builder,
    RouteSettings settings: const RouteSettings(),
    this.maintainState: true,
    bool fullscreenDialog: false,
  }) : assert(builder != null),
        super(settings: settings, fullscreenDialog: fullscreenDialog) {
    // ignore: prefer_asserts_in_initializer_lists , https://github.com/dart-lang/sdk/issues/31223
    assert(opaque);
  }

  /// Turns on the fading of routes during page transitions.
  ///
  /// This is currently disabled by default because of performance issues on
  /// low-end phones. Eventually these issues will be resolved and this flag
  /// will be removed.
  @Deprecated('This flag will eventually be removed once the performance issues are resolved. See: https://github.com/flutter/flutter/issues/13736')
  static bool debugEnableFadingRoutes = false;

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  /// A delegate PageRoute to which iOS themed page operations are delegated to.
  /// It's lazily created on first use.
  CupertinoPageRoute<T> get _cupertinoPageRoute {
    assert(_useCupertinoTransitions);
    _internalCupertinoPageRoute ??= new CupertinoPageRoute<T>(
      builder: builder, // Not used.
      fullscreenDialog: fullscreenDialog,
      hostRoute: this,
    );
    return _internalCupertinoPageRoute;
  }
  CupertinoPageRoute<T> _internalCupertinoPageRoute;

  /// Whether we should currently be using Cupertino transitions. This is true
  /// if the theme says we're on iOS, or if we're in an active gesture.
  bool get _useCupertinoTransitions {
    return _internalCupertinoPageRoute?.popGestureInProgress == true
        || Theme.of(navigator.context).platform == TargetPlatform.iOS;
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    return previousRoute is MaterialPageRoute || previousRoute is CupertinoPageRoute;
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Don't perform outgoing animation if the next route is a fullscreen dialog.
    return (nextRoute is MaterialPageRoute && !nextRoute.fullscreenDialog)
        || (nextRoute is CupertinoPageRoute && !nextRoute.fullscreenDialog);
  }

  @override
  void dispose() {
    _internalCupertinoPageRoute?.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final Widget result = builder(context);
    assert(() {
      if (result == null) {
        throw new FlutterError(
            'The builder for route "${settings.name}" returned null.\n'
                'Route builders must never return null.'
        );
      }
      return true;
    }());
    return result;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_useCupertinoTransitions) {
      return _cupertinoPageRoute.buildTransitions(context, animation, secondaryAnimation, child);
    } else {
      return new _MountainViewPageTransition(
        routeAnimation: animation,
        child: child,
        fade: debugEnableFadingRoutes, // ignore: deprecated_member_use
      );
    }
  }

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}