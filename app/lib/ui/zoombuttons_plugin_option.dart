import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

/// Taken and adapted from flutter_map example:
/// https://github.com/johnpryan/flutter_map/blob/master/example/lib/pages/plugin_zoombuttons.dart
/// https://github.com/johnpryan/flutter_map/blob/master/example/lib/pages/zoombuttons_plugin_option.dart
class ZoomButtonsPluginOption extends LayerOptions {
  final double margin;
  final Alignment alignment;

  ZoomButtonsPluginOption({
      this.margin = 2.0,
      this.alignment = Alignment.topRight,
  });
}

class ZoomButtonsPlugin implements MapPlugin {
  @override
  Widget createLayer(LayerOptions options, MapState mapState, Stream<Null> stream) {
    if (options is ZoomButtonsPluginOption) {
      return ZoomButtons(options, mapState, stream);
    }
    throw Exception('Unknown options type for ZoomButtonsPlugin: $options');
  }

  @override
  bool supportsLayer(LayerOptions options) {
    return options is ZoomButtonsPluginOption;
  }
}

class ZoomButtons extends StatelessWidget {
  final ZoomButtonsPluginOption zoomButtonsOpts;
  final MapState map;
  final Stream<Null> stream;
  final FitBoundsOptions options = const FitBoundsOptions(padding: EdgeInsets.zero);

  ZoomButtons(this.zoomButtonsOpts, this.map, this.stream);

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
      minWidth: 0.0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.all(8.0),
      child: Align(
        alignment: zoomButtonsOpts.alignment,
        // For some reason, disabled zoom buttons pass the tap through to the underlying map.
        // Not a great user experience, so we catch it here.
        child: GestureDetector(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.all(zoomButtonsOpts.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FlatButton(
                  color: Colors.grey.shade100,
                  disabledColor: Colors.grey.shade300,
                  onPressed: _zoomFunc(1.0),
                  child: Icon(Icons.zoom_in),
                ),
                SizedBox(
                  height: 4.0,
                ),
                FlatButton(
                  color: Colors.grey.shade100,
                  disabledColor: Colors.grey.shade300,
                  onPressed: _zoomFunc(-1.0),
                  child: Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void Function() _zoomFunc(double delta) {
    final bounds = map.getBounds();
    final centerZoom = map.getBoundsCenterZoom(bounds, options);
    final zoom = map.fitZoomToBounds(centerZoom.zoom + delta);
    if (zoom == centerZoom.zoom) {
      return null;
    } else {
      return () {
        map.move(centerZoom.center, zoom);
      };
    }
  }
}
