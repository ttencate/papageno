import 'dart:convert';
import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

final _log = Logger('email_utils');

Future<void> openEmailApp({@required String toAddress, String subject, String body, List<Attachment> attachments}) async {
  await FlutterEmailSender.send(Email(
    recipients: <String>[toAddress],
    subject: subject,
    body: body,
    isHTML: false, // HTML does not work with the Gmail app anyway.
    attachmentPaths: attachments?.map((attachment) => attachment._fileName)?.toList(),
  ));
}

class Attachment {
  final String _fileName;

  Attachment._create(this._fileName);

  static Future<Attachment> fromString(String name, String contents) async {
    return await fromBytes(name, utf8.encode(contents));
  }

  static Future<Attachment> fromBytes(String name, List<int> contents) async {
    // Attachment file name is propagated to the email, so to avoid clashes
    // we need to put it into a directory of its own.
    final tempDir = await getTemporaryDirectory();
    final attachmentDir = await tempDir.createTemp('attachment');
    final file = File(join(attachmentDir.path, name));
    _log.fine('Writing attachment data to ${file.path}');
    await file.writeAsBytes(contents);
    return Attachment._create(file.path);
  }
}

/*
/// Workaround for https://github.com/taljacobson/flutter_mailer/issues/36
class PatchedMailOptions extends MailOptions {
  PatchedMailOptions({
    String subject = '',
    List<String> recipients = const <String>[],
    List<String> ccRecipients = const <String>[],
    List<String> bccRecipients = const <String>[],
    List<String> attachments,
    bool isHTML = false,
    String appSchema,
  }) : super(
      subject: subject,
      recipients: recipients,
      ccRecipients: ccRecipients,
      bccRecipients: bccRecipients,
      attachments: attachments,
      isHTML: isHTML,
      appSchema: appSchema,
  );

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
        ..remove('body');
  }
}
*/