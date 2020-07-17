import 'dart:math' hide log;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/controller/create_course_controller.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/services/app_db.dart';
import 'package:papageno/services/user_db.dart';
import 'package:papageno/utils/url_utils.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:papageno/widgets/zoombuttons_plugin_option.dart';
import 'package:provider/provider.dart';

class CreateCoursePage extends StatefulWidget {
  final Profile profile;

  const CreateCoursePage(this.profile);

  @override
  State<StatefulWidget> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  CreateCourseController _controller;

  static const _initialRadiusKm = 10000.0 / 90.0 * sqrt1_2;

  MapController _mapController;

  @override
  void initState() {
    super.initState();

    final appDb = Provider.of<AppDb>(context, listen: false);
    final userDb = Provider.of<UserDb>(context, listen: false);

    _controller = CreateCourseController(appDb, userDb, widget.profile);
    _mapController = MapController();

    _controller.stateUpdates
        .where((state) => state.selectedLocation != null)
        .distinct((a, b) => a.selectedLocation == b.selectedLocation && a.rankedSpecies == b.rankedSpecies)
        .listen((state) {
          if (state.rankedSpecies == null) {
            _panTo(state.selectedLocation);
          } else {
            _zoomTo(state.selectedLocation, 1.5 * state.rankedSpecies.usedRadiusKm);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.courseNameFunc = Strings.of(context).courseName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final locale = WidgetsBinding.instance.window.locale;
    final settings = widget.profile.settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.createCourseTitle),
      ),
      drawer: MenuDrawer(profile: widget.profile),
      body: StreamBuilder<CreateCourseState>(
        stream: _controller.stateUpdates,
        initialData: CreateCourseState(),
        builder: (context, snapshot) {
          final state = snapshot.data;
          return Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(strings.createCourseInstructions),
                    ),
                    SizedBox(height: 8.0),
                    RaisedButton(
                      onPressed: state.searchingLocation ? null : _controller.useCurrentLocation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Text(strings.useCurrentLocationButton.toUpperCase()),
                          if (state.searchingLocation) CircularProgressIndicator(),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(strings.createCourseTapMap),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _buildMap(state.selectedLocation, state.rankedSpecies),
                    if (state.selectedLocation != null) Positioned(
                      top: 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8.0),
                            bottomRight: Radius.circular(8.0),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                          child: Text(
                            // TODO convert lat/lon to string in a locale-dependent way
                            state.selectedLocation.toString(),
                            style: TextStyle(
                              color: Colors.black,
                              shadows: <Shadow>[
                                Shadow(color: Colors.white, blurRadius: 2.0),
                                Shadow(color: Colors.white, blurRadius: 4.0),
                              ]
                            ),
                          ),
                        ),
                      ),
                    ),
                    // This panel showing common species in put in the Stack on top of the map
                    // (rather than in the containing Column) because flutter_map has problems
                    // with resizing: it makes the CircleMarker jump around.
                    if (state.selectedLocation != null) Positioned(
                      left: 0.0,
                      right: 0.0,
                      bottom: 0.0,
                      child: Container(
                        color: Color.lerp(Colors.white, theme.primaryColor, 0.2).withOpacity(0.8),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (state.cityName != null) Text(
                                strings.courseSpecies(state.cityName),
                              ),
                              Text(
                                state.rankedSpecies == null ?
                                  strings.courseSearchingSpecies :
                                  // 20 species should be enough to always hit the ellipsis, and if not, no big deal.
                                  state.rankedSpecies.speciesList
                                      .take(20)
                                      .map((species) => species.commonNameIn(settings.primarySpeciesLanguage.value.resolve(locale)))
                                      .join(', '),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: TextStyle(fontWeight: FontWeight.w300),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: RaisedButton(
                  onPressed: state.course == null ?
                  null :
                  () { _createCourse(state.course); },
                  child: Text(
                      state.rankedSpecies == null ?
                      strings.createCourseButtonDisabled.toUpperCase() :
                      strings.createCourseButtonEnabled(state.rankedSpecies.length).toUpperCase()
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildMap(LatLon selectedLocation, RankedSpecies rankedSpecies) {
    final theme = Theme.of(context);
    final circleColor = theme.primaryColor;
    final circleRadiusKm = rankedSpecies?.usedRadiusKm ?? _initialRadiusKm;
    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _latLonToLatLng(selectedLocation ?? LatLon(0.0, 0.0)),
            zoom: 1.0,
            minZoom: 1.0,
            maxZoom: 7.0,
            interactive: true,
            onTap: _onMapTap,
            plugins: [
              ZoomButtonsPlugin(),
            ],
          ),
          layers: <LayerOptions>[
            TileLayerOptions(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
              tileProvider: NonCachingNetworkTileProvider(),
            ),
            if (rankedSpecies != null) CircleLayerOptions(
              circles: [
                for (var f = 1.0; f > 0.0; f -= 0.25) CircleMarker(
                  point: _latLonToLatLng(rankedSpecies.location),
                  color: circleColor.withOpacity(0.25),
                  radius: f * circleRadiusKm * 1000.0,
                  useRadiusInMeter: true,
                )
              ],
            ),
            if (selectedLocation != null) CircleLayerOptions(
              circles: [
                CircleMarker(
                  point: _latLonToLatLng(selectedLocation),
                  color: circleColor.withOpacity(0.75),
                  borderColor: Colors.white.withOpacity(0.75),
                  borderStrokeWidth: 1.0,
                  radius: 4.0,
                ),
              ],
            ),
            ZoomButtonsPluginOption(
              margin: 8.0,
              alignment: Alignment.topRight,
            ),
          ],
        ),
        Positioned(
            right: 0.0,
            bottom: 0.0,
            child: Container(
              color: Colors.white.withOpacity(0.3),
              child: Padding(
                padding: EdgeInsets.all(2.0),
                child: _OpenStreetMapCopyright(),
              ),
            )
        )
      ],
    );
  }

  void _onMapTap(LatLng latLng) {
    final location = _latLngToLatLon(latLng);
    _controller.selectLocation(location);
  }

  void _panTo(LatLon location) {
    final latLng = _latLonToLatLng(location);
    _mapController.move(latLng, _mapController.zoom);
  }

  void _zoomTo(LatLon location, double radiusKm) {
    final latLng = _latLonToLatLng(location);
    final radiusDegrees = radiusKm / 10000.0 * 90.0;
    _mapController.fitBounds(LatLngBounds.fromPoints(<LatLng>[
      _safeLatLng(latLng.latitude + radiusDegrees, latLng.longitude),
      _safeLatLng(latLng.latitude - radiusDegrees, latLng.longitude),
      _safeLatLng(latLng.latitude, latLng.longitude + radiusDegrees),
      _safeLatLng(latLng.latitude, latLng.longitude - radiusDegrees),
    ]));
  }

  Future<void> _createCourse(Course course) async {
    assert(course != null);
    await _controller.saveCourse();
    Navigator.of(context).pop(course);
  }
}

LatLng _safeLatLng(double lat, double lon) {
  // We clamp, rather than wrap, because the map isn't wrapped either and we
  // don't want to end up spanning the entire map.
  lat = max(-90, min(90, lat));
  lon = max(-180, min(180, lon));
  return LatLng(lat, lon);
}

LatLon _latLngToLatLon(LatLng latLng) {
  return LatLon(latLng.latitude, latLng.longitude);
}

LatLng _latLonToLatLng(LatLon latLon) {
  return LatLng(latLon.lat, latLon.lon);
}

// TODO deduplicate with similar code from quiz_page.dart (something like LinkedTextWidget)
class _OpenStreetMapCopyright extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.caption;
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: '© ',
            style: textStyle,
          ),
          TextSpan(
            text: 'OpenStreetMap',
            style: textStyle.copyWith(color: Colors.blue, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () { openUrl('https://www.openstreetmap.org/copyright'); },
          ),
          TextSpan(
            text: ' contributors',
            style: textStyle,
          )
        ],
      ),
    );
  }
}