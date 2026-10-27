import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_feedback.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/app_buttons.dart';
import '../theme/app_colors.dart' show ink, muted, violet, violetDark;
import '../models/avatar_traits.dart';
import '../services/dicebear_generator.dart';

// TODO: Firebase wiring pending - load saved avatar on init.
class AvatarBackgroundOption {
  final String id;
  final String label;
  final String hex;
  const AvatarBackgroundOption({
    required this.id,
    required this.label,
    required this.hex,
  });
}

const List<AvatarBackgroundOption> avatarBackgroundOptions = [
  AvatarBackgroundOption(id: 'red', label: 'Red', hex: 'ef4444'),
  AvatarBackgroundOption(id: 'white', label: 'White', hex: 'ffffff'),
  AvatarBackgroundOption(id: 'black', label: 'Black', hex: '000000'),
  AvatarBackgroundOption(id: 'lightBlue', label: 'Light blue', hex: '38bdf8'),
  AvatarBackgroundOption(id: 'darkBlue', label: 'Dark blue', hex: '1e40af'),
  AvatarBackgroundOption(id: 'teal', label: 'Teal', hex: '2dd4bf'),
  AvatarBackgroundOption(id: 'green', label: 'Green', hex: '22c55e'),
  AvatarBackgroundOption(id: 'lemon', label: 'Lemon', hex: 'fde047'),
  AvatarBackgroundOption(id: 'pink', label: 'Pink', hex: 'f472b6'),
];

class _StudioSection {
  final String label;
  final List<List<dynamic>> icon;
  final String? traitKey;
  final String? colorKey;
  final bool colorOnly;
  const _StudioSection({
    required this.label,
    required this.icon,
    this.traitKey,
    this.colorKey,
    this.colorOnly = false,
  });
}

const List<_StudioSection> _sections = [
  _StudioSection(
    label: 'Skin',
    icon: HugeIcons.strokeRoundedFaceId,
    traitKey: 'skinColor',
    colorOnly: true,
  ),
  _StudioSection(
    label: 'Eyes',
    icon: HugeIcons.strokeRoundedEye,
    traitKey: 'eyes',
  ),
  _StudioSection(
    label: 'Mouth',
    icon: HugeIcons.strokeRoundedSmile,
    traitKey: 'mouth',
  ),
  _StudioSection(
    label: 'Brows',
    icon: HugeIcons.strokeRoundedFaceMimic,
    traitKey: 'eyebrows',
  ),
  _StudioSection(
    label: 'Hair',
    icon: HugeIcons.strokeRoundedHairDryer,
    traitKey: 'top',
    colorKey: 'hairColor',
  ),
  _StudioSection(
    label: 'Beard',
    icon: HugeIcons.strokeRoundedChairBarber,
    traitKey: 'facialHair',
    colorKey: 'facialHairColor',
  ),
  _StudioSection(
    label: 'Outfit',
    icon: HugeIcons.strokeRoundedTShirt,
    traitKey: 'clothes',
    colorKey: 'clothesColor',
  ),
  _StudioSection(
    label: 'Glasses',
    icon: HugeIcons.strokeRoundedGlasses,
    traitKey: 'accessories',
    colorKey: 'accessoriesColor',
  ),
  _StudioSection(
    label: 'Stage',
    icon: HugeIcons.strokeRoundedImage01,
    traitKey: 'backgroundColor',
    colorOnly: true,
  ),
];

class AvatarSelectionScreen extends StatefulWidget {
  final Map<String, String>? initialOpts;
  final void Function(Map<String, String> opts)? onSaved;
  const AvatarSelectionScreen({super.key, this.initialOpts, this.onSaved});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  late Map<String, String> _opts;
  bool _isSaving = false;
  int _section = 4;
  int _batchToken = 0;
  bool _batchReady = false;
  Future<Map<String, String>>? _batchFuture;
  String? _shownSvg;

  static const Set<String> _colorTraits = {
    'skinColor',
    'hairColor',
    'hatColor',
    'facialHairColor',
    'clothesColor',
    'accessoriesColor',
    'backgroundColor',
  };

  @override
  void initState() {
    super.initState();
    _opts = Map<String, String>.of(
      widget.initialOpts ?? AvatarTraits.defaults(),
    );
    // TODO: Firebase wiring pending - load saved avatar:
    // final user = FirebaseAuth.instance.currentUser;
    // final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    // _opts = AvatarTraits.fromFirestore(doc.data()?['avatarOptions']);
    _refireBatch();
  }

  void _pickSection(int i) {
    if (_section == i) return;
    setState(() => _section = i);
    _refireBatch();
  }

  List<Map<String, String>> _batchOpts() {
    final out = <Map<String, String>>[
      DicebearGenerator.withoutBackground(_opts),
    ];
    final sec = _sections[_section];
    final traitKey = sec.traitKey;
    if (traitKey != null && !_colorTraits.contains(traitKey)) {
      for (final opt in AvatarTraits.traits[traitKey] ?? []) {
        out.add(
          DicebearGenerator.withoutBackground({..._opts, traitKey: opt.value}),
        );
      }
    }
    return out;
  }

  void _refireBatch() {
    final token = ++_batchToken;
    final future = DicebearGenerator.generateManyAsync(_batchOpts());
    _batchFuture = future;
    void markReady() {
      if (!mounted || token != _batchToken) return;
      setState(() => _batchReady = true);
    }

    future.then((_) => markReady(), onError: (_) => markReady());
  }

  Future<String> _previewFor(Map<String, String> opts) {
    final display = DicebearGenerator.withoutBackground(opts);
    final hit = DicebearGenerator.cachedSvg(display);
    if (hit != null) return Future.value(hit);
    final batch = _batchFuture;
    if (batch == null) return Future.value('');
    return batch.then((m) => m[display.toString()] ?? '');
  }

  Color _stageColor() {
    final hex = (_opts['backgroundColor'] ?? 'ffffff').trim();
    final argb = int.tryParse('FF$hex', radix: 16);
    if (argb == null) return Colors.white;
    return Color(argb);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // TODO: Firebase wiring pending - persist to Firestore:
      // final user = FirebaseAuth.instance.currentUser;
      // final avatarUrl = AvatarTraits.buildDicebearUrl(_opts);
      // await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      //   'avatarOptions': _opts,
      //   'avatar_url': avatarUrl,
      // });
      widget.onSaved?.call(Map<String, String>.of(_opts));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_batchReady) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SafeArea(child: _ForgeLoader()),
      );
    }
    final sec = _sections[_section];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onClose: () {
                AppFeedback.light();
                Navigator.pop(context);
              },
              onSave: _isSaving
                  ? null
                  : () {
                      AppFeedback.light();
                      _save();
                    },
              isSaving: _isSaving,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      child: _Stage(
                        color: _stageColor(),
                        svgFuture: _previewFor(_opts),
                        optsKey: _opts.toString(),
                        fallbackSvg: _shownSvg,
                        onSvg: (svg) => _shownSvg = svg,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionRail(
                      active: _section,
                      onPick: _pickSection,
                    ),
                    const SizedBox(height: 12),
                    if (sec.colorKey != null)
                      _ColorStrip(
                        title: '${sec.label} color',
                        values:
                            AvatarTraits.traits[sec.colorKey!]!
                                .map((e) => e.value)
                                .toList(),
                        selected: _opts[sec.colorKey!],
                        onPick: (v) {
                          setState(() => _opts[sec.colorKey!] = v);
                          _refireBatch();
                        },
                      ),
                    _GridTitle(
                      title: sec.colorOnly
                          ? '${sec.label} tone'
                          : 'Pick your ${sec.label.toLowerCase()}',
                      count: sec.colorOnly
                          ? _colorValues(sec).length
                          : (AvatarTraits.traits[sec.traitKey] ?? const [])
                                .length,
                    ),
                    if (sec.colorOnly)
                      _BigSwatchGrid(
                        values: _colorValues(sec),
                        selected: sec.traitKey == 'backgroundColor'
                            ? _opts['backgroundColor']
                            : _opts[sec.traitKey!],
                        onPick: (v) {
                          setState(
                            () => _opts[sec.traitKey!] = v,
                          );
                          _refireBatch();
                        },
                      )
                    else
                      _OptionGrid(
                        traitKey: sec.traitKey!,
                        opts: _opts,
                        previewFor: _previewFor,
                        stageColor: _stageColor(),
                        onPick: (v) {
                          setState(() => _opts[sec.traitKey!] = v);
                          _refireBatch();
                        },
                      ),
                    if (sec.traitKey == 'clothes' &&
                        _opts['clothes'] == 'graphicShirt')
                      _GraphicStrip(
                        selected: _opts['clothesGraphic'],
                        onPick: (v) {
                          setState(() => _opts['clothesGraphic'] = v);
                          _refireBatch();
                        },
                      ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              isSaving: _isSaving,
              onSave: () {
                AppFeedback.light();
                _save();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _colorValues(_StudioSection sec) {
    if (sec.traitKey == 'backgroundColor') {
      return avatarBackgroundOptions.map((e) => e.hex).toList();
    }
    return AvatarTraits.traits[sec.traitKey]!.map((e) => e.value).toList();
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onSave;
  final bool isSaving;
  const _Header({
    required this.onClose,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          EngramBackButton.close(
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Avatar studio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Make it yours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          EngramIconButton(
            icon: HugeIcons.strokeRoundedTick02,
            onTap: onSave,
            size: 52,
            background: isSaving ? context.mutedText : violet,
            foreground: Colors.white,
            shadowColor: isSaving ? context.hairline : violetDark,
            isLoading: isSaving,
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  final Color color;
  final Future<String> svgFuture;
  final String optsKey;
  final String? fallbackSvg;
  final void Function(String svg)? onSvg;
  const _Stage({
    required this.color,
    required this.svgFuture,
    required this.optsKey,
    this.fallbackSvg,
    this.onSvg,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 308,
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.hairline, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: CustomPaint(
                  painter: _DotsPainter(dot: Colors.white.withValues(alpha: 0.35)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    color: color,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: FutureBuilder<String>(
                              key: ValueKey(optsKey),
                              future: svgFuture,
                              builder: (context, snapshot) {
                                var svg = snapshot.data;
                                if (snapshot.hasError ||
                                    (svg != null && svg.isEmpty)) {
                                  final fb = fallbackSvg;
                                  if (fb != null && fb.isNotEmpty) {
                                    svg = fb;
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 24),
                                      child: HugeIcon(
                                        icon: HugeIcons
                                            .strokeRoundedUserCircle,
                                        size: 150,
                                        color: Colors.white,
                                        strokeWidth: 1.6,
                                      ),
                                    );
                                  }
                                }
                                if (svg == null || svg.isEmpty) {
                                  final fb = fallbackSvg;
                                  if (fb != null && fb.isNotEmpty) {
                                    svg = fb;
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 100),
                                      child: SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                final ready = svg;
                                final cb = onSvg;
                                if (snapshot.hasData && cb != null) {
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => cb(ready),
                                  );
                                }
                                return SvgPicture.string(
                                  ready,
                                  width: 250,
                                  height: 250,
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color dot;
  const _DotsPainter({required this.dot});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dot;
    const gap = 18.0;
    for (var y = 10.0; y < size.height; y += gap) {
      for (var x = 10.0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.dot != dot;
}

class _SectionRail extends StatelessWidget {
  final int active;
  final void Function(int) onPick;
  const _SectionRail({required this.active, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = _sections[i];
          final sel = i == active;
          return GestureDetector(
            onTap: () => onPick(i),
            child: SizedBox(
              width: 68,
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? violetDark : context.hairline,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? violet : context.cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? violet : context.hairline,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: s.icon,
                            color: sel ? Colors.white : context.inkText,
                            size: 22,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: sel
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: sel ? context.cardBg : context.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorStrip extends StatelessWidget {
  final String title;
  final List<String> values;
  final String? selected;
  final void Function(String) onPick;
  const _ColorStrip({
    required this.title,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  Color _c(String hex) {
    final argb = int.tryParse('FF$hex', radix: 16);
    if (argb == null) return muted;
    return Color(argb);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final v = values[i];
              final sel = selected == v;
              return GestureDetector(
                onTap: () => onPick(v),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 3,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? violetDark : context.hairline,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _c(v),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? violet : Colors.white,
                              width: sel ? 3 : 2,
                            ),
                          ),
                          child: sel
                              ? const HugeIcon(
                                  icon: HugeIcons.strokeRoundedTick02,
                                  color: Colors.white,
                                  size: 10,
                                  strokeWidth: 2.5,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridTitle extends StatelessWidget {
  final String title;
  final int count;
  const _GridTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.inkText.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigSwatchGrid extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final void Function(String) onPick;
  const _BigSwatchGrid({
    required this.values,
    required this.selected,
    required this.onPick,
  });

  Color _c(String hex) {
    final argb = int.tryParse('FF$hex', radix: 16);
    if (argb == null) return muted;
    return Color(argb);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: values.length,
        itemBuilder: (context, i) {
          final v = values[i];
          final sel = selected == v;
          return GestureDetector(
            onTap: () => onPick(v),
            child: SizedBox(
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? violetDark : context.hairline,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _c(v),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? violet : Colors.white,
                          width: sel ? 3 : 2,
                        ),
                      ),
                      child: sel
                          ? const HugeIcon(
                              icon: HugeIcons.strokeRoundedTick02,
                              color: Colors.white,
                              size: 11,
                              strokeWidth: 2.5,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final String traitKey;
  final Map<String, String> opts;
  final Future<String> Function(Map<String, String>) previewFor;
  final Color stageColor;
  final void Function(String) onPick;
  const _OptionGrid({
    required this.traitKey,
    required this.opts,
    required this.previewFor,
    required this.stageColor,
    required this.onPick,
  });

  String _label(TraitOption o) =>
      o.labelEn.isNotEmpty ? o.labelEn : o.label;

  @override
  Widget build(BuildContext context) {
    final options = AvatarTraits.traits[traitKey] ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final opt = options[i];
          final sel = opts[traitKey] == opt.value;
          return GestureDetector(
            onTap: () => onPick(opt.value),
            child: SizedBox(
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? violetDark : context.hairline,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? violet : context.hairline,
                          width: sel ? 3 : 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                              decoration: BoxDecoration(
                                color: stageColor,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: FutureBuilder<String>(
                                  future: previewFor({
                                    ...opts,
                                    traitKey: opt.value,
                                  }),
                                  builder: (context, snapshot) {
                                    final svg = snapshot.data;
                                    if (snapshot.hasError ||
                                        (svg != null && svg.isEmpty)) {
                                      return const Center(
                                        child: HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedUserCircle,
                                          size: 40,
                                          color: Colors.white,
                                          strokeWidth: 2.0,
                                        ),
                                      );
                                    }
                                    if (svg == null) {
                                      return const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: violet,
                                          ),
                                        ),
                                      );
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(4, 6, 4, 0),
                                      child: SvgPicture.string(
                                        svg,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                            child: Text(
                              _label(opt),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: sel
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: sel
                                    ? context.inkText
                                    : context.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GraphicStrip extends StatelessWidget {
  final String? selected;
  final void Function(String) onPick;
  const _GraphicStrip({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final options = AvatarTraits.traits['clothesGraphic'] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Text(
            'Shirt print',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final o = options[i];
              final label = o.labelEn.isNotEmpty ? o.labelEn : o.label;
              final sel = selected == o.value;
              return GestureDetector(
                onTap: () => onPick(o.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? ink : context.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel ? ink : context.hairline,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: sel ? Colors.white : context.mutedText,
                      fontWeight:
                          sel ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;
  const _BottomBar({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.hairline, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: EngramButton(
            label: 'Save avatar',
            onPressed: isSaving ? null : onSave,
            isLoading: isSaving,
          ),
        ),
      ),
    );
  }
}

class _ForgeLoader extends StatelessWidget {
  const _ForgeLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: violet),
            ),
            SizedBox(height: 16),
            Text(
              'Building avatar…',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
