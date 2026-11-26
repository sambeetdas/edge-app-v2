import 'dart:io';

import '../../core/utils/formatters.dart';
import '../../data/services/agent_service.dart';
import '../../data/services/chat_history_service.dart';
import '../../data/services/knowledge_service.dart';
import '../../data/services/proactive_service.dart';
import '../models/chat_models.dart';
import 'chat_engine.dart';
import 'vision_engine.dart';

class AgentStepEvent {
  final int stepIndex;
  final String agentId;
  final String agentName;
  final String agentIcon;
  final String targetLabel;
  final String output;
  final bool isStreaming;
  final String? actionLabel;
  final String? actionUrl;

  const AgentStepEvent({
    required this.stepIndex,
    required this.agentId,
    required this.agentName,
    required this.agentIcon,
    required this.targetLabel,
    required this.output,
    required this.isStreaming,
    this.actionLabel,
    this.actionUrl,
  });
}

/// Runs single Agents and sequential Agent-to-Agent (A2A) handoff chains
/// 100% offline using ChatEngine, KnowledgeService, VisionEngine, and ProactiveService.
class AgentOrchestrator {
  final ChatEngine _chatEngine;
  final AgentService _agentService;
  final KnowledgeService _knowledgeService;
  final VisionEngine _visionEngine;
  final ProactiveService _proactiveService;
  final ChatHistoryService _chatHistoryService;

  static const int maxHops = 4;

  AgentOrchestrator({
    required ChatEngine chatEngine,
    required AgentService agentService,
    required KnowledgeService knowledgeService,
    required VisionEngine visionEngine,
    required ProactiveService proactiveService,
    required ChatHistoryService chatHistoryService,
  })  : _chatEngine = chatEngine,
        _agentService = agentService,
        _knowledgeService = knowledgeService,
        _visionEngine = visionEngine,
        _proactiveService = proactiveService,
        _chatHistoryService = chatHistoryService;

  Stream<AgentStepEvent> runAgentChain({
    required AgentDefinition primaryAgent,
    required String userInput,
    AgentDefinition? handoffAgent,
    File? imageFile,
    String? recipientTarget,
    Duration? scheduleDelay,
  }) async* {
    final runId = await _agentService.createRun(primaryAgent.name);
    final chain = await _buildChain(primaryAgent, handoffAgent);
    var currentPayload = userInput.trim();

    for (var i = 0; i < chain.length; i++) {
      final agent = chain[i];
      final nextAgent = (i + 1 < chain.length) ? chain[i + 1] : null;
      final targetLabel = nextAgent != null
          ? 'Handoff → ${nextAgent.icon} ${nextAgent.name}'
          : 'Final Output';

      final prompt = await _preparePrompt(
        agent: agent,
        input: currentPayload,
        imageFile: i == 0 ? imageFile : null,
      );

      final request = ChatRequest(
        systemPrompt: agent.systemPrompt,
        messages: [ChatMessage(role: ChatRole.user, content: prompt)],
        temperature: 0.35,
        maxTokens: 512,
      );

      final sb = StringBuffer();
      int lastEmitMs = DateTime.now().millisecondsSinceEpoch;
      await for (final token in _chatEngine.generateStream(request)) {
        sb.write(token);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastEmitMs >= 80) {
          lastEmitMs = nowMs;
          yield AgentStepEvent(
            stepIndex: i,
            agentId: agent.id,
            agentName: agent.name,
            agentIcon: agent.icon,
            targetLabel: targetLabel,
            output: Formatters.stripMarkdown(sb.toString()),
            isStreaming: true,
          );
        }
      }

      final cleanOutput = Formatters.stripMarkdown(sb.toString());
      final action = await _executeToolActions(
        agent: agent,
        output: cleanOutput,
        recipientTarget: recipientTarget,
        scheduleDelay: scheduleDelay,
      );

      await _agentService.logAgentMessage(
        runId: runId,
        fromAgent: agent.name,
        toAgent: nextAgent?.name ?? 'User',
        content: cleanOutput,
        actionType: action.label,
        actionPayload: action.url,
      );

      yield AgentStepEvent(
        stepIndex: i,
        agentId: agent.id,
        agentName: agent.name,
        agentIcon: agent.icon,
        targetLabel: targetLabel,
        output: cleanOutput,
        isStreaming: false,
        actionLabel: action.label,
        actionUrl: action.url,
      );

      // Compact handoff payload passed to the next agent in the chain.
      currentPayload = cleanOutput.length > 1800
          ? cleanOutput.substring(0, 1800)
          : cleanOutput;
    }
  }

  Future<List<AgentDefinition>> _buildChain(
    AgentDefinition primary,
    AgentDefinition? explicitHandoff,
  ) async {
    final chain = <AgentDefinition>[primary];
    final visited = <String>{primary.id};

    if (explicitHandoff != null && !visited.contains(explicitHandoff.id)) {
      chain.add(explicitHandoff);
      visited.add(explicitHandoff.id);
    }

    while (chain.length < maxHops) {
      final nextId = chain.last.nextAgentId;
      if (nextId == null || nextId.isEmpty || visited.contains(nextId)) break;
      final next = await _agentService.getAgentById(nextId);
      if (next == null) break;
      chain.add(next);
      visited.add(next.id);
    }
    return chain;
  }

  Future<String> _preparePrompt({
    required AgentDefinition agent,
    required String input,
    File? imageFile,
  }) async {
    final parts = <String>[];

    if (agent.hasTool(AgentTool.rag)) {
      final matches =
          await _knowledgeService.searchChunks(input, topK: 4);
      if (matches.isNotEmpty) {
        final excerpts = matches
            .map((m) => '[${m.citationLabel}]\n${m.content}')
            .join('\n\n---\n\n');
        parts.add('Knowledge Base Excerpts:\n$excerpts');
      } else {
        parts.add('Note: No indexed Knowledge Base documents matched.');
      }
    }

    if (agent.hasTool(AgentTool.ocr) && imageFile != null) {
      final ocrText = await _visionEngine.extractText(imageFile);
      parts.add(
        ocrText.isNotEmpty
            ? 'Extracted Image OCR Text:\n$ocrText'
            : 'Note: No readable text was detected in the selected image.',
      );
    }

    if (agent.id == 'daily_briefing') {
      final sessions = await _chatHistoryService.getSessions();
      final docs = await _knowledgeService.getDocuments();
      final reminders = await _proactiveService.getReminders();
      final workspace = [
        if (sessions.isNotEmpty)
          'Recent Chats: ${sessions.take(4).map((s) => s.title).join(', ')}',
        if (docs.isNotEmpty)
          'Docs: ${docs.take(4).map((d) => d.fileName).join(', ')}',
        if (reminders.where((r) => !r.isCompleted).isNotEmpty)
          'Pending Reminders: ${reminders.where((r) => !r.isCompleted).take(4).map((r) => r.title).join(', ')}',
      ].join('\n');
      if (workspace.isNotEmpty) {
        parts.add('Offline Workspace:\n$workspace');
      }
    }

    if (input.isNotEmpty) {
      parts.add('Input:\n$input');
    }
    return parts.join('\n\n');
  }

  Future<({String? label, String? url})> _executeToolActions({
    required AgentDefinition agent,
    required String output,
    String? recipientTarget,
    Duration? scheduleDelay,
  }) async {
    final delay = scheduleDelay ?? Duration.zero;
    final target = (recipientTarget ?? '').trim();

    if (agent.hasTool(AgentTool.email)) {
      final subjectMatch =
          RegExp(r'^SUBJECT:\s*(.+)$', multiLine: true, caseSensitive: false)
              .firstMatch(output);
      final subject =
          subjectMatch?.group(1)?.trim() ?? 'Message from Edged';
      final body = output
          .replaceFirst(
            RegExp(r'^SUBJECT:.*\n?', multiLine: true, caseSensitive: false),
            '',
          )
          .replaceFirst(
            RegExp(r'^BODY:\s*\n?', multiLine: true, caseSensitive: false),
            '',
          )
          .trim();
      final uri = Uri(
        scheme: 'mailto',
        path: target,
        queryParameters: {'subject': subject, 'body': body},
      ).toString();

      if (delay > Duration.zero) {
        await _proactiveService.scheduleActionNotification(
          title: 'Scheduled Email Ready',
          body: 'Tap to open & send: $subject',
          delay: delay,
          actionUrl: uri,
        );
        return (
          label: 'Scheduled Email (${_delayLabel(delay)}) · Open Now',
          url: uri,
        );
      }
      return (label: 'Open Email App', url: uri);
    }

    if (agent.hasTool(AgentTool.whatsapp)) {
      final digits = target.replaceAll(RegExp(r'[^\d]'), '');
      final encoded = Uri.encodeComponent(output);
      final url = digits.isNotEmpty
          ? 'https://wa.me/$digits?text=$encoded'
          : 'https://wa.me/?text=$encoded';

      if (delay > Duration.zero) {
        await _proactiveService.scheduleActionNotification(
          title: 'Scheduled WhatsApp Ready',
          body: output.length > 80 ? '${output.substring(0, 80)}…' : output,
          delay: delay,
          actionUrl: url,
        );
        return (
          label: 'Scheduled WhatsApp (${_delayLabel(delay)}) · Open Now',
          url: url,
        );
      }
      return (label: 'Open WhatsApp', url: url);
    }

    if (agent.hasTool(AgentTool.reminder)) {
      final firstLine = output
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => 'Agent Reminder');
      final title =
          firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
      await _proactiveService.addReminder(
        title: title,
        delay: delay > Duration.zero ? delay : const Duration(minutes: 15),
      );
      return (label: 'Reminder Scheduled', url: null);
    }

    return (label: null, url: null);
  }

  String _delayLabel(Duration d) {
    if (d.inHours >= 24) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}
