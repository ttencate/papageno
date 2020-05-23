import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info/package_info.dart';
import 'package:papageno/common/strings.g.dart';
import 'package:papageno/model/app_model.dart' hide Image;
import 'package:papageno/services/app_db.dart';
import 'package:papageno/utils/url_utils.dart';
import 'package:provider/provider.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final packageInfo = Provider.of<PackageInfo>(context);
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.aboutTitle),
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image(
              image: AssetImage('assets/logo.png'),
              width: 128.0,
              height: 128.0,
            ),
          ),
          Text(
            strings.appTitleShort,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 40.0,
              color: Colors.black87,
            ),
          ),
          Text(
            strings.appSubtitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 16.0,
              letterSpacing: 3.6,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            strings.appVersion(packageInfo.version),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 16.0,
            ),
          ),
          SizedBox(height: 16.0),
          Text(
            strings.appCopyright,
            textAlign: TextAlign.center,
            style: theme.textTheme.caption,
          ),
          SizedBox(height: 16.0),

          Divider(),

          _HeadingTile(title: strings.contributorsHeading),
          _ContributorTile(name: strings.thomasTenCateName, role: strings.thomasTenCateRole, url: strings.thomasTenCateUrl),

          Divider(),

          _HeadingTile(title: strings.applicationLicenseHeading),
          _CitationTile(title: strings.gplLicenseBlurb),
          _SourceTile(title: strings.appSourceLink, url: strings.appSourceUrl),
          _LicenseTile(title: strings.gplLicenseName, subtitle: strings.gplLicenseVersion, fullTextAsset: 'assets/licenses/gplv3.txt'),

          Divider(),

          _HeadingTile(title: strings.mediaLicensesHeading),
          _CitationTile(title: strings.xenoCantoSource),
          _SourceTile(title: 'xeno-canto', url: 'https://www.xeno-canto.org'),
          _ViewAttributablesTile(title: strings.recordingsLicensesText, load: () => _loadRecordingItems(context)),
          _CitationTile(title: strings.wikimediaCommonsSource),
          _SourceTile(title: 'Wikimedia Commons', url: 'https://commons.wikimedia.org'),
          _ViewAttributablesTile(title: strings.imagesLicensesText, load: () => _loadImageItems(context)),

          Divider(),

          _HeadingTile(title: strings.dataLicensesHeading),
          _CitationTile(title: 'IOC World Bird List v 9.1 by Frank Gill & David Donsker (Eds)'),
          _SourceTile(title: 'IOC World Bird List', url: 'https://www.worldbirdnames.org'),
          _LicenseTile(title: 'Creative Commons Attribution 3.0', fullTextUrl: 'https://creativecommons.org/licenses/by/3.0/legalcode'),
          _CitationTile(title: 'Levatich T, Padilla F (2019). EOD - eBird Observation Dataset. Cornell Lab of Ornithology. Occurrence dataset accessed via GBIF.org on 2020-04-20'),
          _SourceTile(title: 'EOD - eBird Observation Dataset', url: 'https://doi.org/10.15468/aomfnb'),
          _LicenseTile(title: 'Creative Commons Zero 1.0', fullTextUrl: 'https://creativecommons.org/publicdomain/zero/1.0/legalcode'),

          Divider(),

          _HeadingTile(title: strings.softwareLicensesHeading),
          ListTile(
            leading: Icon(Icons.list),
            title: Text(strings.viewSoftwareLicenses),
            onTap: () { _showLicensePage(context); },
          ),
        ],
      ),
    );
  }

  Future<List<Attributable>> _loadRecordingItems(BuildContext context) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final recordings = await appDb.allRecordings();
    return recordings;
  }

  Future<List<Attributable>> _loadImageItems(BuildContext context) async {
    final appDb = Provider.of<AppDb>(context, listen: false);
    final images = await appDb.allImages();
    return images;
  }

  void _showLicensePage(BuildContext context) {
    final packageInfo = Provider.of<PackageInfo>(context, listen: false);
    final strings = Strings.of(context);
    showLicensePage(
      context: context,
      applicationName: strings.appTitleFull,
      applicationVersion: strings.appVersion(packageInfo.version),
      applicationLegalese: strings.appCopyright,
      applicationIcon: Image(image: AssetImage('assets/logo.png'), width: 64.0, height: 64.0),
    );
  }
}

class _HeadingTile extends StatelessWidget {
  final String title;

  const _HeadingTile({Key key, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        title.toUpperCase(),
        style: theme.textTheme.headline6.copyWith(color: theme.textTheme.caption.color),
      ),
    );
  }
}

class _CitationTile extends StatelessWidget {
  final String title;

  const _CitationTile({Key key, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
    );
  }
}

class _ContributorTile extends StatelessWidget {
  final String name;
  final String role;
  final String url;

  const _ContributorTile({Key key, @required this.name, @required this.role, this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(child: Text(name)),
          url == null ? null : Text(prettyUrl(url), style: theme.textTheme.bodyText2.copyWith(color: Colors.blue)),
        ],
      ),
      subtitle: Text(role),
      onTap: url == null ? null : () { openUrl(url); },
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String fullTextAsset;
  final String fullTextUrl;

  const _LicenseTile({Key key, @required this.title, this.subtitle, this.fullTextAsset, this.fullTextUrl}) :
      assert(fullTextAsset == null || fullTextUrl == null), // Mutually exclusive.
      super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.description),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: fullTextAsset != null || fullTextUrl != null ? () { _viewFullText(context); } : null,
    );
  }

  void _viewFullText(BuildContext context) async {
    if (fullTextAsset != null) {
      final text = await DefaultAssetBundle.of(context).loadString(fullTextAsset, cache: false);
      await showDialog<void>(
        context: context,
        builder: (context) => _LicenseDialog(text: text),
      );
    } else if (fullTextUrl != null) {
      await openUrl(fullTextUrl);
    }
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String url;

  const _SourceTile({Key key, this.title, this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.link),
      title: Text(title),
      subtitle: Text(prettyUrl(url)),
      onTap: () { openUrl(url); },
    );
  }
}

class _LicenseDialog extends StatelessWidget {
  final String text;

  const _LicenseDialog({Key key, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      child: SingleChildScrollView(
        child: Text(
          text,
          softWrap: true,
        ),
      ),
    );
  }
}

class _ViewAttributablesTile extends StatelessWidget {
  final String title;
  final Future<List<Attributable>> Function() load;

  const _ViewAttributablesTile({Key key, @required this.title, @required this.load}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.list),
      title: Text(title),
      onTap: () { _showPopup(context); },
    );
  }

  Future<void> _showPopup(BuildContext context) async {
    final attributablesFuture = load();
    await showDialog<void>(
      context: context,
      builder: (context) => _AttributablesDialog(attributables: attributablesFuture),
    );
  }
}

class _AttributablesDialog extends StatelessWidget {
  final Future<List<Attributable>> attributables;

  const _AttributablesDialog({Key key, this.attributables}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      child: FutureBuilder<List<Attributable>>(
        future: attributables,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final attributables = snapshot.data;
          return ListView.builder(
            itemCount: attributables.length,
            itemBuilder: (context, index) {
              final item = attributables[index ~/ 3];
              switch (index % 3) {
                case 0: return _CitationTile(title: item.attribution);
                case 1: return _SourceTile(title: item.nameForAttribution, url: item.sourceUrl);
                case 2: return _LicenseTile(title: item.licenseName, fullTextUrl: item.licenseUrl);
              }
              return null; // Should not happen.
            },
          );
        },
      ),
    );
  }
}

class _BaseDialog extends StatelessWidget {
  final Widget child;

  const _BaseDialog({Key key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    return Dialog(
      insetPadding: EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
            children: <Widget>[
              Expanded(
                child: child,
              ),
              SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FlatButton(
                    child: Text(strings.ok.toUpperCase()),
                    onPressed: () { Navigator.of(context).pop(); },
                  ),
                ],
              ),
            ]
        ),
      ),
    );
  }
}