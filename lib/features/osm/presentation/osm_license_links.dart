import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const odblLicenseUrl = 'https://opendatacommons.org/licenses/odbl/1-0/';

Future<void> openOsmLicenseLink(BuildContext context, String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
  }
}
