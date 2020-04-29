import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:papageno/ui/course.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/controller.dart';
import '../db/appdb.dart';
import '../model/model.dart';
import 'strings.dart';

class CreateCoursePage extends StatefulWidget {
  static const route = '/createCourse';

  @override
  State<StatefulWidget> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {

  AppDb _appDb;
  LatLng _selectedLocation;
  List<Species> _rankedSpecies;
  Course _course;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appDb = Provider.of<AppDb>(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.createCourseTitle),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(strings.createCourseInstructions),
          ),
          Expanded(
            child: _buildMap(),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _selectedLocation == null ?
                  '—' :
                  strings.courseLocation(strings.latLon(_latLngToLatLon(_selectedLocation))),
                ),
                if (_selectedLocation != null) Text(
                  _rankedSpecies == null ?
                  strings.courseSearchingSpecies :
                  strings.courseSpecies(
                      // TODO take language code from settings
                      _rankedSpecies.take(5).map((species) => species.commonNameIn(LanguageCode.language_nl)).join(', '),
                      _rankedSpecies.length),
                ),
                SizedBox(
                  height: 16.0,
                ),
                RaisedButton(
                  color: Colors.blue, // TODO take from theme
                  textColor: Colors.white,
                  child: Text(strings.createCourseButton.toUpperCase()),
                  onPressed: _course == null ?
                      null :
                      _startCourse,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMap() {
    final circleColor = Colors.green; // TODO Take from theme
    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            center: _selectedLocation ?? LatLng(0.0, 0.0),
            zoom: 1.0,
            minZoom: 1.0,
            maxZoom: 10.0,
            interactive: true,
            onTap: _onMapTap,
          ),
          layers: <LayerOptions>[
            TileLayerOptions(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
            ),
            // TODO when the map size changes (due to bottom text size changing), the circle jumps around. Probably a bug in flutter_map.
            CircleLayerOptions(
              circles: <CircleMarker>[
                if (_selectedLocation != null) CircleMarker(
                  point: _selectedLocation,
                  color: circleColor.withOpacity(0.3),
                  borderStrokeWidth: 2,
                  borderColor: circleColor,
                  radius: 62.7e3, // Radius of circle of area equal to one grid tile (at the equator).
                  useRadiusInMeter: true,
                ),
              ],
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

  void _onMapTap(LatLng latLng) async {
    setState(() {
      _selectedLocation = latLng;
      _rankedSpecies = null;
      _course = null;
    });

    final location = _latLngToLatLon(latLng);
    final rankedSpecies = await rankSpecies(_appDb, location);
    setState(() { _rankedSpecies = rankedSpecies; });

    final course = await createCourse(location, rankedSpecies);
    setState(() { _course = course; });
  }

  static LatLon _latLngToLatLon(LatLng latLng) {
    return LatLon(latLng.latitude, latLng.longitude);
  }

  void _startCourse() {
    assert(_course != null);
    Navigator.of(context).pushNamed(CoursePage.route, arguments: _course);
  }
}

// TODO deduplicate with similar code from question.dart (something like LinkedTextWidget)
class _OpenStreetMapCopyright extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style
        .copyWith(fontSize: 12.0);
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