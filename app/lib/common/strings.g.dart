/// Translations from translations.csv. AUTOGENERATED, DO NOT EDIT!
/// To make changes to this file, edit translations.csv
/// and run `flutter pub run bin/generate_translations`.

// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/widgets.dart';

/// Interface for localized strings.
abstract class Strings {
  /// A [LocalizationsDelegate] for the [Strings] class.
  static final LocalizationsDelegate<Strings>  delegate = _StringsLocalizationsDelegate();
  /// The list of supported locales, the first being the default.
  static final List<Locale>  supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
  ];
  /// Returns a concrete Strings implementation based on the current locale derived from the context.
  static Strings of(BuildContext context) => Localizations.of<Strings>(context, Strings);
  /// Title of the app
  String get appTitleShort;
  /// Subtitle of the app
  String get appSubtitle;
  /// Title of the app
  String get appTitleFull;
  /// Version of the app
  String appVersion(String versionNumber);
  /// Copyright line
  String get appCopyright;
  /// Shown on the splash screen while data is being loaded
  String get loading;
  /// Menu item that opens profile selection screen
  String get switchProfile;
  /// Menu item that opens course selection screen
  String get switchCourse;
  /// Menu item that opens Settings screen
  String get settings;
  /// Menu item that opens About screen
  String get about;
  /// Title of screen listing all profiles
  String get profiles;
  /// Text at the top of the screen listing profiles
  String get profilesExplanation;
  /// Name shown for a profile that has not been given a name
  String anonymousProfileName(int number);
  /// Text describing when a profile was last accessed; the placeholder is replaced by a date and time
  String profileLastUsed(String when);
  /// Used instead of date if a profile has not been used yet
  String get profileNeverUsed;
  /// Button text for creating a new profile
  String get startCreatingProfileButton;
  /// Dialog title
  String get createProfileTitle;
  /// Dialog title
  String get editProfileTitle;
  /// Text above text input field for profile name
  String get profileNameLabel;
  /// Placeholder text in empty profile name text input
  String get profileNamePlaceholder;
  /// Text on button to delete profile
  String get deleteProfileButton;
  /// Text asking to delete a profile
  String deleteProfileConfirmation(String profileName);
  /// Title of screen listing all courses in a profile
  String get courses;
  /// Button to start course creation
  String get startCreatingCourseButton;
  /// Text asking to delete a course
  String deleteCourseConfirmation(String courseTitle);
  /// Title of screen for creating a new course
  String get createCourseTitle;
  /// Instructions on the screen for creating a new course
  String get createCourseInstructions;
  /// Instructions on the screen for creating a new course
  String get createCourseTapMap;
  /// Text for button to use current GPS location for creating a course
  String get useCurrentLocationButton;
  /// Shown on the course creation screen while bird species are being looked up
  String get courseSearchingSpecies;
  /// Shown on the course creation screen above a list of bird names
  String get courseSpecies;
  /// Button text while button is disabled
  String get createCourseButtonDisabled;
  /// Button text when enough species were found
  String createCourseButtonEnabled(int speciesCount);
  /// Title of a course, containing GPS location; keep short
  String courseTitle(String location);
  /// Number of lessons in a course
  String lessonCount(int lessonCount, int speciesCount);
  /// Title of a numbered lesson
  String lessonTitle(int lessonNumber);
  /// Text below lesson title showing how well the lesson has been learned
  String lessonProgress(int progressPercent);
  /// Text above a progress bar
  String get unlockProgress;
  /// Button text for starting a lesson
  String get startLesson;
  /// Indicates current question number (starting from 1) and the total number of questions
  String questionIndex(int current, int total);
  /// Shown at the bottom of the screen when ready to continue to the next question
  String get tapInstructions;
  /// Title of screen with quiz results
  String get quizResultsTitle;
  /// Text introducing a percentage showing how well the user scored on a quiz
  String get quizScore;
  /// Text showing how well the user scored on a quiz
  String quizScoreDetails(int correct, int total);
  /// Text introducing birds that the user is good at
  String get strongPoints;
  /// Text introducing birds that the user is not good at
  String get weakPoints;
  /// Text describing a single incorrect answer
  String confusionText(String correct, String wrong);
  /// Text on button that retries this quiz once more
  String get retryQuizButton;
  /// Text on button that goes back to the previous screen
  String get backButton;
  /// Title of dialog asking to abort the current quiz
  String get abortQuizTitle;
  /// Text of dialog asking to abort the current quiz
  String get abortQuizContent;
  /// Credit for audio recordists
  String recordingCreator(String name);
  /// Credit for photographers
  String imageCreator(String name);
  /// Shown instead of author name if author is unknown, referring to the web page where their work was found
  String get unknownCreator;
  /// Referring to a URL where source material (audio, photo) was found
  String source(String url);
  /// Referring to the name of a license, e.g. CC BY-SA
  String license(String name);
  /// Text for an OK button
  String get ok;
  /// Text for a cancel button
  String get cancel;
  /// Text for confirmation button
  String get yes;
  /// Text for rejection button
  String get no;
  /// Heading on the Settings screen
  String get speciesNameDisplay;
  /// Setting for the language in which to display bird species names
  String get primarySpeciesNameLanguage;
  /// Setting for a second language in which to display bird species names
  String get secondarySpeciesNameLanguage;
  /// Toggle for showing the scientific name of bird species
  String get showScientificName;
  /// Shown in language picker if no language has been configured
  String get languageNone;
  /// Shown in language picker for the language used by the operating system
  String get languageSystem;
  /// Name of the English language
  String get language_en;
  /// Name of the Afrikaans language
  String get language_af;
  /// Name of the Catalan language
  String get language_ca;
  /// Name of the Chinese language using the simplified script
  String get language_zh_CN;
  /// Name of the Chinese language using the traditional script
  String get language_zh_TW;
  /// Name of the Czech language
  String get language_cs;
  /// Name of the Danish language
  String get language_da;
  /// Name of the Dutch language
  String get language_nl;
  /// Name of the Estonian language
  String get language_et;
  /// Name of the Finnish language
  String get language_fi;
  /// Name of the French language
  String get language_fr;
  /// Name of the German language
  String get language_de;
  /// Name of the Hungarian language
  String get language_hu;
  /// Name of the Icelandic language
  String get language_is;
  /// Name of the Indonesian language
  String get language_id;
  /// Name of the Italian language
  String get language_it;
  /// Name of the Japanese language
  String get language_ja;
  /// Name of the Latvian language
  String get language_lv;
  /// Name of the Lithuanian language
  String get language_lt;
  /// Name of the Northern Sami language
  String get language_se;
  /// Name of the Norwegian language (either Bokmål or Nynorsk)
  String get language_no;
  /// Name of the Polish language
  String get language_pl;
  /// Name of the Portuguese language
  String get language_pt;
  /// Name of the Russian language
  String get language_ru;
  /// Name of the Slovak language
  String get language_sk;
  /// Name of the Slovenian language
  String get language_sl;
  /// Name of the Spanish language
  String get language_es;
  /// Name of the Swedish language
  String get language_sv;
  /// Name of the Thai language
  String get language_th;
  /// Name of the Ukrаiniаn language
  String get language_uk;
  /// Title of the About screen
  String get aboutTitle;
  /// Heading in About screen
  String get contributorsHeading;
  /// Heading in About screen
  String get applicationLicenseHeading;
  /// Heading in About screen
  String get mediaLicensesHeading;
  /// Heading in About screen
  String get dataLicensesHeading;
  /// Heading in About screen
  String get softwareLicensesHeading;
  /// Name in About screen
  String get thomasTenCateName;
  /// Role in About screen
  String get thomasTenCateRole;
  /// URL in About screen
  String get thomasTenCateUrl;
  /// Legalese; do not translate
  String get gplLicenseName;
  /// Legalese; do not translate
  String get gplLicenseVersion;
  /// Legalese; do not translate
  String get gplLicenseBlurb;
  /// Text of link button
  String get viewSoftwareLicenses;
  /// Link to source code on GitHub
  String get appSourceLink;
  /// URL to source code on GitHub
  String get appSourceUrl;
  /// Text in About screen
  String get xenoCantoSource;
  /// Button text in About screen
  String get recordingsLicensesText;
  /// Text in About screen
  String get wikimediaCommonsSource;
  /// Button text in About screen
  String get imagesLicensesText;
  /// Button that opens the email app to send feedback
  String get sendFeedbackButton;
  /// Explanatory text in dialog for sending feedback
  String get feedbackExplanation;
  /// Text of check box that selects whether a debug log is added to the feedback email
  String get feedbackIncludeDebugLog;
  /// Explanation in send feedback dialog
  String get feedbackIncludeDebugLogExplanation;
  /// Button that starts the email app to compose a feedback email
  String get feedbackStartEmailAppButton;
  /// Template for feedback email; only translate to English, Dutch and German!
  String get feedbackEmailTemplate;
  /// Button that opens the debug log screen
  String get debugLogButton;
  /// Title of debug log screen
  String get debugLogTitle;
  /// Returns the translation for the given key.
  /// For translations without arguments, returns a `String`.
  /// For translations with arguments, returns a `String Function(...)`.
  /// Returns `null` if the key was not found.
  dynamic operator [](String key){
    switch (key) {
      case 'appTitleShort': return appTitleShort;
      case 'appSubtitle': return appSubtitle;
      case 'appTitleFull': return appTitleFull;
      case 'appVersion': return appVersion;
      case 'appCopyright': return appCopyright;
      case 'loading': return loading;
      case 'switchProfile': return switchProfile;
      case 'switchCourse': return switchCourse;
      case 'settings': return settings;
      case 'about': return about;
      case 'profiles': return profiles;
      case 'profilesExplanation': return profilesExplanation;
      case 'anonymousProfileName': return anonymousProfileName;
      case 'profileLastUsed': return profileLastUsed;
      case 'profileNeverUsed': return profileNeverUsed;
      case 'startCreatingProfileButton': return startCreatingProfileButton;
      case 'createProfileTitle': return createProfileTitle;
      case 'editProfileTitle': return editProfileTitle;
      case 'profileNameLabel': return profileNameLabel;
      case 'profileNamePlaceholder': return profileNamePlaceholder;
      case 'deleteProfileButton': return deleteProfileButton;
      case 'deleteProfileConfirmation': return deleteProfileConfirmation;
      case 'courses': return courses;
      case 'startCreatingCourseButton': return startCreatingCourseButton;
      case 'deleteCourseConfirmation': return deleteCourseConfirmation;
      case 'createCourseTitle': return createCourseTitle;
      case 'createCourseInstructions': return createCourseInstructions;
      case 'createCourseTapMap': return createCourseTapMap;
      case 'useCurrentLocationButton': return useCurrentLocationButton;
      case 'courseSearchingSpecies': return courseSearchingSpecies;
      case 'courseSpecies': return courseSpecies;
      case 'createCourseButtonDisabled': return createCourseButtonDisabled;
      case 'createCourseButtonEnabled': return createCourseButtonEnabled;
      case 'courseTitle': return courseTitle;
      case 'lessonCount': return lessonCount;
      case 'lessonTitle': return lessonTitle;
      case 'lessonProgress': return lessonProgress;
      case 'unlockProgress': return unlockProgress;
      case 'startLesson': return startLesson;
      case 'questionIndex': return questionIndex;
      case 'tapInstructions': return tapInstructions;
      case 'quizResultsTitle': return quizResultsTitle;
      case 'quizScore': return quizScore;
      case 'quizScoreDetails': return quizScoreDetails;
      case 'strongPoints': return strongPoints;
      case 'weakPoints': return weakPoints;
      case 'confusionText': return confusionText;
      case 'retryQuizButton': return retryQuizButton;
      case 'backButton': return backButton;
      case 'abortQuizTitle': return abortQuizTitle;
      case 'abortQuizContent': return abortQuizContent;
      case 'recordingCreator': return recordingCreator;
      case 'imageCreator': return imageCreator;
      case 'unknownCreator': return unknownCreator;
      case 'source': return source;
      case 'license': return license;
      case 'ok': return ok;
      case 'cancel': return cancel;
      case 'yes': return yes;
      case 'no': return no;
      case 'speciesNameDisplay': return speciesNameDisplay;
      case 'primarySpeciesNameLanguage': return primarySpeciesNameLanguage;
      case 'secondarySpeciesNameLanguage': return secondarySpeciesNameLanguage;
      case 'showScientificName': return showScientificName;
      case 'languageNone': return languageNone;
      case 'languageSystem': return languageSystem;
      case 'language_en': return language_en;
      case 'language_af': return language_af;
      case 'language_ca': return language_ca;
      case 'language_zh_CN': return language_zh_CN;
      case 'language_zh_TW': return language_zh_TW;
      case 'language_cs': return language_cs;
      case 'language_da': return language_da;
      case 'language_nl': return language_nl;
      case 'language_et': return language_et;
      case 'language_fi': return language_fi;
      case 'language_fr': return language_fr;
      case 'language_de': return language_de;
      case 'language_hu': return language_hu;
      case 'language_is': return language_is;
      case 'language_id': return language_id;
      case 'language_it': return language_it;
      case 'language_ja': return language_ja;
      case 'language_lv': return language_lv;
      case 'language_lt': return language_lt;
      case 'language_se': return language_se;
      case 'language_no': return language_no;
      case 'language_pl': return language_pl;
      case 'language_pt': return language_pt;
      case 'language_ru': return language_ru;
      case 'language_sk': return language_sk;
      case 'language_sl': return language_sl;
      case 'language_es': return language_es;
      case 'language_sv': return language_sv;
      case 'language_th': return language_th;
      case 'language_uk': return language_uk;
      case 'aboutTitle': return aboutTitle;
      case 'contributorsHeading': return contributorsHeading;
      case 'applicationLicenseHeading': return applicationLicenseHeading;
      case 'mediaLicensesHeading': return mediaLicensesHeading;
      case 'dataLicensesHeading': return dataLicensesHeading;
      case 'softwareLicensesHeading': return softwareLicensesHeading;
      case 'thomasTenCateName': return thomasTenCateName;
      case 'thomasTenCateRole': return thomasTenCateRole;
      case 'thomasTenCateUrl': return thomasTenCateUrl;
      case 'gplLicenseName': return gplLicenseName;
      case 'gplLicenseVersion': return gplLicenseVersion;
      case 'gplLicenseBlurb': return gplLicenseBlurb;
      case 'viewSoftwareLicenses': return viewSoftwareLicenses;
      case 'appSourceLink': return appSourceLink;
      case 'appSourceUrl': return appSourceUrl;
      case 'xenoCantoSource': return xenoCantoSource;
      case 'recordingsLicensesText': return recordingsLicensesText;
      case 'wikimediaCommonsSource': return wikimediaCommonsSource;
      case 'imagesLicensesText': return imagesLicensesText;
      case 'sendFeedbackButton': return sendFeedbackButton;
      case 'feedbackExplanation': return feedbackExplanation;
      case 'feedbackIncludeDebugLog': return feedbackIncludeDebugLog;
      case 'feedbackIncludeDebugLogExplanation': return feedbackIncludeDebugLogExplanation;
      case 'feedbackStartEmailAppButton': return feedbackStartEmailAppButton;
      case 'feedbackEmailTemplate': return feedbackEmailTemplate;
      case 'debugLogButton': return debugLogButton;
      case 'debugLogTitle': return debugLogTitle;
    }
    return null;
  }
}

/// [LocalizationsDelegate] that looks up and returns the right autogenerated localization.
class _StringsLocalizationsDelegate extends LocalizationsDelegate<Strings> {
  static final  _localeMap = <Locale, Strings>{
    Locale('en'): _Strings_en(),
    Locale('nl'): _Strings_nl(),
  };
  const _StringsLocalizationsDelegate();
  @override bool isSupported(Locale locale) => Strings.supportedLocales.contains(locale);
  @override Future<Strings> load(Locale locale){
    return Future.value(_localeMap[locale] ?? _Strings_en());
  }
  @override bool shouldReload(LocalizationsDelegate<Strings> old) => false;
}

/// Translations for language code "en".
class _Strings_en extends Strings {
  @override String get appTitleShort => 'Papageno';
  @override String get appSubtitle => 'Birdsong Tutor';
  @override String get appTitleFull => 'Papageno: Birdsong Tutor';
  @override String appVersion(String versionNumber) => <String>['Version ', versionNumber].join();
  @override String get appCopyright => 'Copyright © 2020, Thomas ten Cate';
  @override String get loading => 'Loading…';
  @override String get switchProfile => 'Switch profile';
  @override String get switchCourse => 'Switch course';
  @override String get settings => 'Settings';
  @override String get about => 'About Papageno';
  @override String get profiles => 'Profiles';
  @override String get profilesExplanation => 'A profile represents a single user of the app, and records their courses and knowledge. If multiple people are using this app on this device, create a profile for each of them.';
  @override String anonymousProfileName(int number) => <String>['Unnamed profile ', number.toString()].join();
  @override String profileLastUsed(String when) => <String>['Last used: ', when].join();
  @override String get profileNeverUsed => 'never';
  @override String get startCreatingProfileButton => 'Create new profile';
  @override String get createProfileTitle => 'Create profile';
  @override String get editProfileTitle => 'Edit profile';
  @override String get profileNameLabel => 'Name';
  @override String get profileNamePlaceholder => 'For example, your name';
  @override String get deleteProfileButton => 'Delete profile';
  @override String deleteProfileConfirmation(String profileName) => <String>['The profile "', profileName, '" will be deleted, along with all its courses and progress. This cannot be undone. Are you sure?'].join();
  @override String get courses => 'Courses';
  @override String get startCreatingCourseButton => 'Start new course';
  @override String deleteCourseConfirmation(String courseTitle) => <String>['The course "', courseTitle, '" will be deleted. This cannot be undone. Are you sure?'].join();
  @override String get createCourseTitle => 'Start new course';
  @override String get createCourseInstructions => 'Choose a location. Your course will contain birds from that area, ordered from common to rare.';
  @override String get createCourseTapMap => 'Or tap the map to select another location.';
  @override String get useCurrentLocationButton => 'Use current location';
  @override String get courseSearchingSpecies => 'Searching for bird species…';
  @override String get courseSpecies => 'Common birds in this area:';
  @override String get createCourseButtonDisabled => 'Start course';
  @override String createCourseButtonEnabled(int speciesCount) => <String>['Start course (', speciesCount.toString(), ' birds)'].join();
  @override String courseTitle(String location) => <String>['Birds near ', location].join();
  @override String lessonCount(int lessonCount, int speciesCount) => <String>[lessonCount.toString(), ' chapters, ', speciesCount.toString(), ' birds'].join();
  @override String lessonTitle(int lessonNumber) => <String>['Chapter ', lessonNumber.toString()].join();
  @override String lessonProgress(int progressPercent) => <String>['Progress: ', progressPercent.toString(), '%'].join();
  @override String get unlockProgress => 'Progress towards the next chapter:';
  @override String get startLesson => 'Start';
  @override String questionIndex(int current, int total) => <String>['Question ', current.toString(), ' of ', total.toString()].join();
  @override String get tapInstructions => 'Tap anywhere to continue';
  @override String get quizResultsTitle => 'Quiz results';
  @override String get quizScore => 'Score:';
  @override String quizScoreDetails(int correct, int total) => <String>['Correctly identified ', correct.toString(), ' out of ', total.toString(), ' birds'].join();
  @override String get strongPoints => 'Strong points';
  @override String get weakPoints => 'Weak points';
  @override String confusionText(String correct, String wrong) => <String>['Took ', correct, ' to be ', wrong].join();
  @override String get retryQuizButton => 'Have another go';
  @override String get backButton => 'Back';
  @override String get abortQuizTitle => 'Abort quiz?';
  @override String get abortQuizContent => 'This will end the current quiz. Are you sure?';
  @override String recordingCreator(String name) => <String>['Audio recording by ', name].join();
  @override String imageCreator(String name) => <String>['Photo by ', name].join();
  @override String get unknownCreator => '[unknown, see source page]';
  @override String source(String url) => <String>['Source: ', url].join();
  @override String license(String name) => <String>['License: ', name].join();
  @override String get ok => 'OK';
  @override String get cancel => 'Cancel';
  @override String get yes => 'Yes';
  @override String get no => 'No';
  @override String get speciesNameDisplay => 'Display of bird names';
  @override String get primarySpeciesNameLanguage => 'First language (used for answers)';
  @override String get secondarySpeciesNameLanguage => 'Second language';
  @override String get showScientificName => 'Show scientific ("Latin") name';
  @override String get languageNone => 'None';
  @override String get languageSystem => 'Operating system language';
  @override String get language_en => 'English';
  @override String get language_af => 'Afrikaans';
  @override String get language_ca => 'Catalan';
  @override String get language_zh_CN => 'Chinese (simplified)';
  @override String get language_zh_TW => 'Chinese (traditional)';
  @override String get language_cs => 'Czech';
  @override String get language_da => 'Danish';
  @override String get language_nl => 'Dutch';
  @override String get language_et => 'Estonian';
  @override String get language_fi => 'Finnish';
  @override String get language_fr => 'French';
  @override String get language_de => 'German';
  @override String get language_hu => 'Hungarian';
  @override String get language_is => 'Icelandic';
  @override String get language_id => 'Indonesian';
  @override String get language_it => 'Italian';
  @override String get language_ja => 'Japanese';
  @override String get language_lv => 'Latvian';
  @override String get language_lt => 'Lithuanian';
  @override String get language_se => 'Northern Sami';
  @override String get language_no => 'Norwegian';
  @override String get language_pl => 'Polish';
  @override String get language_pt => 'Portuguese';
  @override String get language_ru => 'Russian';
  @override String get language_sk => 'Slovak';
  @override String get language_sl => 'Slovenian';
  @override String get language_es => 'Spanish';
  @override String get language_sv => 'Swedish';
  @override String get language_th => 'Thai';
  @override String get language_uk => 'Ukrаiniаn';
  @override String get aboutTitle => 'About Papageno';
  @override String get contributorsHeading => 'Contributors';
  @override String get applicationLicenseHeading => 'Application license';
  @override String get mediaLicensesHeading => 'Media licenses';
  @override String get dataLicensesHeading => 'Data licenses';
  @override String get softwareLicensesHeading => 'Software licenses';
  @override String get thomasTenCateName => 'Thomas ten Cate';
  @override String get thomasTenCateRole => 'Concept, design, development';
  @override String get thomasTenCateUrl => 'https://frozenfractal.com';
  @override String get gplLicenseName => 'GNU General Public License';
  @override String get gplLicenseVersion => 'Version 3, 29 June 2009';
  @override String get gplLicenseBlurb => 'This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.';
  @override String get viewSoftwareLicenses => 'View software licenses';
  @override String get appSourceLink => 'Source code available on GitHub';
  @override String get appSourceUrl => 'https://github.com/ttencate/papageno';
  @override String get xenoCantoSource => 'Audio recordings sourced from xeno-canto';
  @override String get recordingsLicensesText => 'View licenses for all recordings';
  @override String get wikimediaCommonsSource => 'Photos sourced from Wikimedia Commons';
  @override String get imagesLicensesText => 'View licenses for all photos';
  @override String get sendFeedbackButton => 'Send feedback';
  @override String get feedbackExplanation => 'This starts your email app to write a message to the developer, Thomas. I understand English, Dutch and German.';
  @override String get feedbackIncludeDebugLog => 'Include debug log';
  @override String get feedbackIncludeDebugLogExplanation => 'Adds logging information to the end of the email. Check this box if a problem just occurred with the app, and you want to report it. It greatly helps me to find and fix the issue!';
  @override String get feedbackStartEmailAppButton => 'Start email app';
  @override String get feedbackEmailTemplate => 'Hi Thomas,\n\n';
  @override String get debugLogButton => 'Debug log';
  @override String get debugLogTitle => 'Debug log';
}

/// Translations for language code "nl".
class _Strings_nl extends _Strings_en {
  @override String appVersion(String versionNumber) => <String>['Versie ', versionNumber].join();
  @override String get loading => 'Bezig met laden…';
  @override String get switchProfile => 'Profiel kiezen';
  @override String get switchCourse => 'Cursus kiezen';
  @override String get settings => 'Instellingen';
  @override String get about => 'Over Papageno';
  @override String get profiles => 'Profielen';
  @override String get profilesExplanation => 'Een profiel vertegenwoordigt een gebruiker van de app, en bevat de cursussen en kennis van die persoon. Als meerdere mensen deze app gebruiken op dit apparaat, kun je voor elk van hen een profiel maken.';
  @override String anonymousProfileName(int number) => <String>['Naamloos profiel ', number.toString()].join();
  @override String profileLastUsed(String when) => <String>['Laatst gebruikt: ', when].join();
  @override String get profileNeverUsed => 'nooit';
  @override String get startCreatingProfileButton => 'Maak nieuw profiel';
  @override String get createProfileTitle => 'Profiel maken';
  @override String get editProfileTitle => 'Profiel bewerken';
  @override String get profileNameLabel => 'Naam';
  @override String get profileNamePlaceholder => 'Bijvoorbeeld je eigen naam';
  @override String get deleteProfileButton => 'Profiel verwijderen';
  @override String deleteProfileConfirmation(String profileName) => <String>['Het profiel "', profileName, '" zal worden verwijderd, samen met al zijn cursussen en voortgang. Dit kan niet ongedaan worden gemaakt. Weet je het zeker?'].join();
  @override String get courses => 'Cursussen';
  @override String get startCreatingCourseButton => 'Nieuwe cursus beginnen';
  @override String deleteCourseConfirmation(String courseTitle) => <String>['De cursus "', courseTitle, '" zal worden verwijderd. Dit kan niet ongedaan worden gemaakt. Weet je het zeker?'].join();
  @override String get createCourseTitle => 'Nieuwe cursus beginnen';
  @override String get createCourseInstructions => 'Kies een locatie. De cursus bevat vogels uit die regio, op volgorde van meer naar minder voorkomend.';
  @override String get createCourseTapMap => 'Of tik op de kaart om een andere locatie te kiezen.';
  @override String get useCurrentLocationButton => 'Gebruik huidige locatie';
  @override String get courseSearchingSpecies => 'Vogelsoorten worden opgezocht…';
  @override String get courseSpecies => 'Veel voorkomende vogels in deze regio:';
  @override String get createCourseButtonDisabled => 'Begin cursus';
  @override String createCourseButtonEnabled(int speciesCount) => <String>['Begin cursus (', speciesCount.toString(), ' vogels)'].join();
  @override String courseTitle(String location) => <String>['Vogels rondom ', location].join();
  @override String lessonCount(int lessonCount, int speciesCount) => <String>[lessonCount.toString(), ' hoofdstukken, ', speciesCount.toString(), ' vogels'].join();
  @override String lessonTitle(int lessonNumber) => <String>['Hoofdstuk ', lessonNumber.toString()].join();
  @override String lessonProgress(int progressPercent) => <String>['Voortgang: ', progressPercent.toString(), '%'].join();
  @override String get unlockProgress => 'Voortgang tot het volgende hoofdstuk:';
  @override String get startLesson => 'Start';
  @override String questionIndex(int current, int total) => <String>['Vraag ', current.toString(), ' van ', total.toString()].join();
  @override String get tapInstructions => 'Tik ergens om verder te gaan';
  @override String get quizResultsTitle => 'Toetsuitslag';
  @override String get quizScore => 'Score:';
  @override String quizScoreDetails(int correct, int total) => <String>[correct.toString(), ' van ', total.toString(), ' vogels juist geïdentificeerd'].join();
  @override String get strongPoints => 'Sterke punten';
  @override String get weakPoints => 'Zwakke punten';
  @override String confusionText(String correct, String wrong) => <String>['Dacht dat een ', correct, ' een ', wrong, ' was'].join();
  @override String get retryQuizButton => 'Nog eens proberen';
  @override String get backButton => 'Terug';
  @override String get abortQuizTitle => 'Toets beëindigen?';
  @override String get abortQuizContent => 'Hiermee wordt de huidige toets beëindigd. Weet je het zeker?';
  @override String recordingCreator(String name) => <String>['Geluidsopname door ', name].join();
  @override String imageCreator(String name) => <String>['Foto door ', name].join();
  @override String get unknownCreator => '[onbekend, zie bronpagina]';
  @override String source(String url) => <String>['Bron: ', url].join();
  @override String license(String name) => <String>['Licensie: ', name].join();
  @override String get ok => 'OK';
  @override String get cancel => 'Annuleren';
  @override String get yes => 'Ja';
  @override String get no => 'Nee';
  @override String get speciesNameDisplay => 'Weergave van vogelnamen';
  @override String get primarySpeciesNameLanguage => 'Eerste taal (gebruikt voor antwoorden)';
  @override String get secondarySpeciesNameLanguage => 'Tweede taal';
  @override String get showScientificName => 'Toon wetenschappelijke ("latijnse") naam';
  @override String get languageNone => 'Geen';
  @override String get languageSystem => 'Taal van besturingssysteem';
  @override String get language_en => 'Engels';
  @override String get language_af => 'Afrikaans';
  @override String get language_ca => 'Catalaans';
  @override String get language_zh_CN => 'Chinees (vereenvoudigd)';
  @override String get language_zh_TW => 'Chinees (traditioneel)';
  @override String get language_cs => 'Tsjechisch';
  @override String get language_da => 'Deens';
  @override String get language_nl => 'Nederlands';
  @override String get language_et => 'Estisch';
  @override String get language_fi => 'Fins';
  @override String get language_fr => 'Frans';
  @override String get language_de => 'Duits';
  @override String get language_hu => 'Hongaars';
  @override String get language_is => 'IJslands';
  @override String get language_id => 'Indonesisch';
  @override String get language_it => 'Italiaans';
  @override String get language_ja => 'Japans';
  @override String get language_lv => 'Lets';
  @override String get language_lt => 'Litouws';
  @override String get language_se => 'Noord-Samisch';
  @override String get language_no => 'Noors';
  @override String get language_pl => 'Pools';
  @override String get language_pt => 'Portugees';
  @override String get language_ru => 'Russisch';
  @override String get language_sk => 'Slowaaks';
  @override String get language_sl => 'Sloveens';
  @override String get language_es => 'Spaans';
  @override String get language_sv => 'Zweeds';
  @override String get language_th => 'Thai';
  @override String get language_uk => 'Oekraïens';
  @override String get aboutTitle => 'Over Papageno';
  @override String get contributorsHeading => 'Medewerkers';
  @override String get applicationLicenseHeading => 'Applicatie-licensie';
  @override String get mediaLicensesHeading => 'Media-licensies';
  @override String get dataLicensesHeading => 'Data-licensies';
  @override String get softwareLicensesHeading => 'Software-licensies';
  @override String get thomasTenCateRole => 'Concept, ontwerp, ontwikkeling';
  @override String get viewSoftwareLicenses => 'Bekijk softwarelicensies';
  @override String get appSourceLink => 'Broncode beschikbaar op GitHub';
  @override String get xenoCantoSource => 'Geluidsopnames verkregen via xeno-canto';
  @override String get recordingsLicensesText => 'Bekijk licensies voor opnames';
  @override String get wikimediaCommonsSource => 'Foto\'s verkregen via Wikimedia Commons';
  @override String get imagesLicensesText => 'Bekijk licensies voor alle foto\'s';
  @override String get sendFeedbackButton => 'Feedback sturen';
  @override String get feedbackExplanation => 'Hiermee open je je email-app om de ontwikkelaar, Thomas, een mail te schrijven. Ik versta Nederlands, Engels en Duits.';
  @override String get feedbackIncludeDebugLog => 'Logbestand bijvoegen';
  @override String get feedbackIncludeDebugLogExplanation => 'Voeg het logbestand toe aan het eind van de email. Vink dit aan als er zojuist een probleem is opgetreden in de app, en je dat wilt melden. Dit helpt mij heel erg bij het vinden en verhelpen van het probleem!';
  @override String get feedbackStartEmailAppButton => 'Start email-app';
  @override String get feedbackEmailTemplate => 'Hoi Thomas,\n\n';
  @override String get debugLogButton => 'Logbestand voor debuggen';
  @override String get debugLogTitle => 'Logbestand voor debuggen';
}
