

import 'package:flutter/material.dart';
import 'package:papageno/widgets/inner_shadow.dart';

// TODO: Currently unused.
class FancyProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color valueColor;
  final Widget child;

  const FancyProgressBar({Key key, @required this.value, this.backgroundColor, this.valueColor, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InnerShadow(
      shadows: <Shadow>[
        Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4.0, offset: Offset(0.0, 1.0)),
      ],
      child: Container(
        height: 32.0,
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: <Widget>[
              FractionallySizedBox(
                widthFactor: value,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(color: valueColor),
                ),
              ),
              if (child != null) Center(
                child: DefaultTextStyle(
                  style: theme.textTheme.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2.0),
                      Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 8.0),
                    ],
                  ),
                  child: child,
                ),
              ),
            ]
        ),
      ),
    );
  }

}