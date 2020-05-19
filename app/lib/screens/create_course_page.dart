import 'dart:developer';
import 'dart:math' hide log;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:location/location.dart';
import 'package:papageno/controller/controller.dart';
import 'package:papageno/db/app_db.dart';
import 'package:papageno/model/app_model.dart';
import 'package:papageno/model/settings.dart';
import 'package:papageno/model/user_model.dart';
import 'package:papageno/common/routes.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/widgets/menu_drawer.dart';
import 'package:papageno/widgets/zoombuttons_plugin_option.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateCoursePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {

  static const _initialRadiusKm = 10000.0 / 90.0 * sqrt1_2;

  AppDb _appDb;
  bool _searchingLocation = false;
  MapController _mapController;
  LatLng _selectedLocation;
  RankedSpecies _rankedSpecies;
  Course _course;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appDb = Provider.of<AppDb>(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final locale = WidgetsBinding.instance.window.locale;
    final settings = Provider.of<Settings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.createCourseTitle),
      ),
      drawer: MenuDrawer(),
      body: Column(
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Text(strings.useCurrentLocationButton.toUpperCase()),
                      if (_searchingLocation) CircularProgressIndicator(),
                    ],
                  ),
                  onPressed: _searchingLocation ? null : _useCurrentLocation,
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
                _buildMap(),
                if (_selectedLocation != null) Positioned(
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
                        _latLngToLatLon(_selectedLocation).toString(),
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
                if (_selectedLocation != null) Positioned(
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
                          if (_rankedSpecies == null) Text(
                            strings.courseSearchingSpecies,
                          ),
                          if (_rankedSpecies != null) Text(
                            strings.courseSpecies,
                          ),
                          if (_rankedSpecies != null) Text(
                            // 20 species should be enough to always hit the ellipsis, and if not, no big deal.
                            _rankedSpecies == null ? '' : _rankedSpecies.speciesList
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
              child: Text(
                  _rankedSpecies == null ?
                  strings.createCourseButtonDisabled.toUpperCase() :
                  strings.createCourseButtonEnabled(_rankedSpecies.length).toUpperCase()
              ),
              onPressed: _course == null ?
              null :
              _startCourse,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final theme = Theme.of(context);
    final circleColor = theme.primaryColor;
    final circleRadiusKm = _rankedSpecies?.usedRadiusKm ?? _initialRadiusKm;
    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _selectedLocation ?? LatLng(0.0, 0.0),
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
            if (_rankedSpecies != null) CircleLayerOptions(
              circles: [
                for (var f = 1.0; f > 0.0; f -= 0.25) CircleMarker(
                  point: _latLonToLatLng(_rankedSpecies.location),
                  color: circleColor.withOpacity(0.25),
                  radius: f * circleRadiusKm * 1000.0,
                  useRadiusInMeter: true,
                )
              ],
            ),
            if (_selectedLocation != null) CircleLayerOptions(
              circles: [
                CircleMarker(
                  point: _selectedLocation,
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

  void _useCurrentLocation() async {
    if (_searchingLocation) {
      return;
    }
    setState(() { _searchingLocation = true; });
    try {
      final location = Location();
      var serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }
      await location.changeSettings(accuracy: LocationAccuracy.low);
      var permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return;
        }
      }
      final locationData = await location.getLocation();
      _selectLocation(LatLng(locationData.latitude, locationData.longitude));
    } finally {
      setState(() {_searchingLocation = false;});
    }
  }

  void _onMapTap(LatLng latLng) async {
    await _selectLocation(latLng);
  }

  void _selectLocation(LatLng latLng) async {
    setState(() {
      _selectedLocation = latLng;
      _rankedSpecies = null;
      _course = null;
    });

    final location = _latLngToLatLon(latLng);
    final rankedSpecies = await rankSpecies(_appDb, location);
    setState(() { _rankedSpecies = rankedSpecies; });
    _zoomTo(latLng, 1.5 * _rankedSpecies.usedRadiusKm);

    final course = await createCourse(location, rankedSpecies);
    setState(() { _course = course; });
  }

  void _zoomTo(LatLng latLng, double radiusKm) {
    final radiusDegrees = radiusKm / 10000.0 * 90.0;
    _mapController.fitBounds(LatLngBounds.fromPoints(<LatLng>[
      _safeLatLng(latLng.latitude + radiusDegrees, latLng.longitude),
      _safeLatLng(latLng.latitude - radiusDegrees, latLng.longitude),
      _safeLatLng(latLng.latitude, latLng.longitude + radiusDegrees),
      _safeLatLng(latLng.latitude, latLng.longitude - radiusDegrees),
    ]));
  }

  static LatLng _safeLatLng(double lat, double lon) {
    // We clamp, rather than wrap, because the map isn't wrapped either and we
    // don't want to end up spanning the entire map.
    lat = max(-90, min(90, lat));
    lon = max(-180, min(180, lon));
    return LatLng(lat, lon);
  }

  static LatLon _latLngToLatLon(LatLng latLng) {
    return LatLon(latLng.latitude, latLng.longitude);
  }

  static LatLng _latLonToLatLng(LatLon latLon) {
    return LatLng(latLon.lat, latLon.lon);
  }

  void _startCourse() {
    assert(_course != null);
    Navigator.of(context).pushNamed(Routes.course, arguments: _course);
  }
}

// TODO deduplicate with similar code from question.dart (something like LinkedTextWidget)
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
              ..onTap = () { _openUrl('https://www.openstreetmap.org/copyright'); },
          ),
          TextSpan(
            text: ' contributors',
            style: textStyle,
          )
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      log('Could not launch URL ${url}');
    }
  }
}