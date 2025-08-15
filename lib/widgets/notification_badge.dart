import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../core/theme.dart';

class NotificationBadge extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool showBadge;
  final int? badgeCount;
  final double badgeSize;
  final Color badgeColor;
  final String? tooltip;

  const NotificationBadge({
    super.key,
    required this.icon,
    this.iconSize = 24,
    this.iconColor = Colors.grey,
    this.onTap,
    this.showBadge = true,
    this.badgeCount,
    this.badgeSize = 20,
    this.badgeColor = Colors.red,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.subscribeToChatNotifications(),
      builder: (context, snapshot) {
        final unreadCount = badgeCount ?? snapshot.data?.length ?? 0;
        final shouldShowBadge = showBadge && unreadCount > 0;

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                icon,
                size: iconSize,
                color: iconColor,
              ),
              onPressed: onTap,
              tooltip: tooltip,
            ),
            if (shouldShowBadge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(badgeSize / 2),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  constraints: BoxConstraints(
                    minWidth: badgeSize,
                    minHeight: badgeSize,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: badgeSize * 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AnimatedNotificationBadge extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool showBadge;
  final int? badgeCount;
  final double badgeSize;
  final Color badgeColor;
  final String? tooltip;
  final Duration animationDuration;

  const AnimatedNotificationBadge({
    super.key,
    required this.icon,
    this.iconSize = 24,
    this.iconColor = Colors.grey,
    this.onTap,
    this.showBadge = true,
    this.badgeCount,
    this.badgeSize = 20,
    this.badgeColor = Colors.red,
    this.tooltip,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedNotificationBadge> createState() => _AnimatedNotificationBadgeState();
}

class _AnimatedNotificationBadgeState extends State<AnimatedNotificationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.bounceOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.subscribeToChatNotifications(),
      builder: (context, snapshot) {
        final unreadCount = widget.badgeCount ?? snapshot.data?.length ?? 0;
        final shouldShowBadge = widget.showBadge && unreadCount > 0;

        // Trigger animation when badge appears
        if (shouldShowBadge && _animationController.status == AnimationStatus.dismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerAnimation();
          });
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
              onPressed: widget.onTap,
              tooltip: widget.tooltip,
            ),
            if (shouldShowBadge)
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: widget.badgeColor,
                          borderRadius: BorderRadius.circular(widget.badgeSize / 2),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.badgeColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minWidth: widget.badgeSize,
                          minHeight: widget.badgeSize,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: widget.badgeSize * 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationIndicator extends StatelessWidget {
  final Widget child;
  final bool showIndicator;
  final Color indicatorColor;
  final double indicatorSize;

  const NotificationIndicator({
    super.key,
    required this.child,
    this.showIndicator = false,
    this.indicatorColor = Colors.red,
    this.indicatorSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showIndicator)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
} 