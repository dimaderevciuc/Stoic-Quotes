/// Help resources shown on the crisis screen and the About screen.
library;

class HelpResource {
  const HelpResource({
    required this.name,
    required this.detail,
    required this.uri,
    required this.label,
  });

  final String name;
  final String detail;
  final Uri uri;

  /// Button text, for example "Call 142".
  final String label;
}

final helpResources = <HelpResource>[
  HelpResource(
    name: 'Emergency',
    detail: 'If you or someone else is in immediate danger.',
    uri: Uri(scheme: 'tel', path: '112'),
    label: 'Call 112',
  ),
  HelpResource(
    name: 'Telefonseelsorge (Austria)',
    detail: 'Free, anonymous, 24 hours a day. Someone will listen.',
    uri: Uri(scheme: 'tel', path: '142'),
    label: 'Call 142',
  ),
  HelpResource(
    name: 'Other countries',
    detail: 'Find a free, confidential helpline near you.',
    uri: Uri(scheme: 'https', host: 'findahelpline.com'),
    label: 'Open findahelpline.com',
  ),
];

const reflectionNotTherapy = 'This app offers reflection, not therapy.';
