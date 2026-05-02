import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final ChildSummary? child = ref.watch(activeChildProvider);
    final AsyncValue<List<ChatMessage>> messages = ref.watch(
      assistantMessagesProvider,
    );
    final bool sending = messages.isLoading && messages.valueOrNull != null;
    final List<String> prompts = <String>[
      tr(language, 'Explain the latest scan', 'اشرح آخر فحص'),
      tr(language, 'Why do models disagree?', 'لماذا تختلف النماذج؟'),
      tr(language, 'When should I go to ER?', 'متى أذهب للطوارئ؟'),
    ];

    ref.listen<AsyncValue<List<ChatMessage>>>(assistantMessagesProvider, (
      AsyncValue<List<ChatMessage>>? previous,
      AsyncValue<List<ChatMessage>> next,
    ) {
      if (next.valueOrNull?.length != previous?.valueOrNull?.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return SafeArea(
      child: Column(
        children: <Widget>[
          Expanded(
            child: messages.when(
              data: (List<ChatMessage> data) => ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                tr(
                                  language,
                                  'Gemini 2.5 Flash for ${child?.name ?? 'your child'}',
                                  'Gemini 2.5 Flash لـ ${child?.name ?? 'طفلك'}',
                                ),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  language,
                                  'Uses live vitals, backend prediction, device prediction, and recent alerts.',
                                  'يستخدم العلامات المباشرة وتنبؤ الخادم وتنبؤ الجهاز وآخر التنبيهات.',
                                ),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prompts
                        .map(
                          (String prompt) => ActionChip(
                            label: Text(prompt),
                            onPressed: sending ? null : () => _send(prompt),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  for (final ChatMessage message in data)
                    Align(
                      alignment: message.isUser
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: message.isUser ? null : AppColors.cardShadow,
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser
                                ? Colors.white
                                : AppColors.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  if (sending)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Text(
                          tr(language, 'Thinking...', 'جارٍ التفكير...'),
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text(
                  tr(
                    language,
                    'Unable to load assistant.',
                    'تعذر تحميل المساعد.',
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: tr(
                        language,
                        'Ask about the latest scan...',
                        'اسأل عن آخر فحص...',
                      ),
                    ),
                    onSubmitted: sending ? null : _send,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: sending ? null : () => _send(_controller.text),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(54, 54),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _controller.clear();
    await ref.read(assistantMessagesProvider.notifier).send(trimmed);
  }
}
