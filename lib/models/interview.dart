library;

import '../l10n/app_localizations.dart';

class InterviewOption {
  final String labelKey;
  final Map<int, int> weights;
  const InterviewOption(this.labelKey, this.weights);

  String get label => enText(labelKey);
}

class InterviewQuestion {
  final String id;
  final String promptKey;
  final String hintKey;

  final String constructKey;

  final String sourceKey;
  final List<InterviewOption> options;
  const InterviewQuestion({
    required this.id,
    required this.promptKey,
    required this.hintKey,
    this.constructKey = '',
    this.sourceKey = '',
    required this.options,
  });

  String get prompt => enText(promptKey);
  String get hint => enText(hintKey);
  String get construct => constructKey.isEmpty ? '' : enText(constructKey);
  String get source => sourceKey.isEmpty ? '' : enText(sourceKey);
}

const interviewQuestions = [
  InterviewQuestion(
    id: 'q1-face',
    promptKey: 'iv_q1_prompt',
    hintKey: 'iv_q1_hint',
    constructKey: 'iv_q1_construct',
    sourceKey: 'iv_q1_source',
    options: [
      InterviewOption(
        'iv_q1_opt0',
        {3: 2, 2: 1},
      ),
      InterviewOption(
        'iv_q1_opt1',
        {3: 1, 4: 1},
      ),
      InterviewOption(
        'iv_q1_opt2',
        {0: 1, 5: 1},
      ),
      InterviewOption(
        'iv_q1_opt3',
        {5: 2, 1: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q2-house-walk',
    promptKey: 'iv_q2_prompt',
    hintKey: 'iv_q2_hint',
    constructKey: 'iv_q2_construct',
    sourceKey: 'iv_q2_source',
    options: [
      InterviewOption(
        'iv_q2_opt0',
        {2: 2, 3: 1},
      ),
      InterviewOption(
        'iv_q2_opt1',
        {2: 1, 4: 1},
      ),
      InterviewOption(
        'iv_q2_opt2',
        {5: 2},
      ),
      InterviewOption(
        'iv_q2_opt3',
        {0: 1, 1: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q3-number',
    promptKey: 'iv_q3_prompt',
    hintKey: 'iv_q3_hint',
    constructKey: 'iv_q3_construct',
    sourceKey: 'iv_q3_source',
    options: [
      InterviewOption(
        'iv_q3_opt0',
        {0: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q3_opt1',
        {3: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q3_opt2',
        {1: 2, 5: 1},
      ),
      InterviewOption(
        'iv_q3_opt3',
        {4: 1, 5: 2},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q4-yesterday',
    promptKey: 'iv_q4_prompt',
    hintKey: 'iv_q4_hint',
    constructKey: 'iv_q4_construct',
    sourceKey: 'iv_q4_source',
    options: [
      InterviewOption(
        'iv_q4_opt0',
        {4: 2, 3: 1},
      ),
      InterviewOption(
        'iv_q4_opt1',
        {4: 1, 0: 1},
      ),
      InterviewOption(
        'iv_q4_opt2',
        {5: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q4_opt3',
        {1: 1, 0: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q5-new-word',
    promptKey: 'iv_q5_prompt',
    hintKey: 'iv_q5_hint',
    constructKey: 'iv_q5_construct',
    sourceKey: 'iv_q5_source',
    options: [
      InterviewOption(
        'iv_q5_opt0',
        {3: 2, 5: 1},
      ),
      InterviewOption(
        'iv_q5_opt1',
        {0: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q5_opt2',
        {5: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q5_opt3',
        {2: 2, 4: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q6-new-place',
    promptKey: 'iv_q6_prompt',
    hintKey: 'iv_q6_hint',
    constructKey: 'iv_q6_construct',
    sourceKey: 'iv_q6_source',
    options: [
      InterviewOption(
        'iv_q6_opt0',
        {2: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q6_opt1',
        {3: 2, 2: 1},
      ),
      InterviewOption(
        'iv_q6_opt2',
        {1: 2, 5: 1},
      ),
      InterviewOption(
        'iv_q6_opt3',
        {4: 2, 0: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q7-tomorrow-call',
    promptKey: 'iv_q7_prompt',
    hintKey: 'iv_q7_hint',
    constructKey: 'iv_q7_construct',
    sourceKey: 'iv_q7_source',
    options: [
      InterviewOption(
        'iv_q7_opt0',
        {4: 2, 2: 1},
      ),
      InterviewOption(
        'iv_q7_opt1',
        {1: 2, 0: 1},
      ),
      InterviewOption(
        'iv_q7_opt2',
        {3: 2, 4: 1},
      ),
      InterviewOption(
        'iv_q7_opt3',
        {0: 2, 1: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q8-gathering',
    promptKey: 'iv_q8_prompt',
    hintKey: 'iv_q8_hint',
    constructKey: 'iv_q8_construct',
    sourceKey: 'iv_q8_source',
    options: [
      InterviewOption(
        'iv_q8_opt0',
        {3: 2, 2: 1},
      ),
      InterviewOption(
        'iv_q8_opt1',
        {0: 2, 1: 1},
      ),
      InterviewOption(
        'iv_q8_opt2',
        {2: 2, 4: 1},
      ),
      InterviewOption(
        'iv_q8_opt3',
        {4: 2, 5: 1},
      ),
    ],
  ),
];
