/// Licenses for bundled things pub.dev does not report: fonts, model, runtime.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerExtraLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Lora font',
    ], await rootBundle.loadString('assets/fonts/Lora-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Inter font',
    ], await rootBundle.loadString('assets/fonts/Inter-OFL.txt'));
    yield const LicenseEntryWithLineBreaks(['gte-small model'], _gteSmall);
    yield const LicenseEntryWithLineBreaks(['ONNX Runtime'], _onnxRuntime);
    yield const LicenseEntryWithLineBreaks(['Quote texts'], _texts);
  });
}

const _gteSmall = '''
thenlper/gte-small (int8 ONNX conversion by Xenova), MIT License.
Copyright (c) Alibaba DAMO Academy.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files, to deal in the software without
restriction, subject to the following conditions: the above copyright notice and this
permission notice shall be included in all copies or substantial portions of the
software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.''';

const _onnxRuntime = '''
ONNX Runtime, MIT License. Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files, to deal in the software without
restriction, subject to the following conditions: the above copyright notice and this
permission notice shall be included in all copies or substantial portions of the
software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.''';

const _texts = '''
All quotes come from public domain editions: Marcus Aurelius, Meditations, tr. George
Long; Epictetus, Discourses and Enchiridion, tr. George Long; Seneca, Moral Letters to
Lucilius, tr. Richard M. Gummere; Seneca, Dialogues, tr. Aubrey Stewart; James Allen,
As a Man Thinketh. Sources: Project Gutenberg and Wikisource.''';
