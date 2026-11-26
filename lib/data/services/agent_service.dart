import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../../engine/services/skills_engine.dart';

enum AgentTool {
  llm('AI Reasoning'),
  rag('Knowledge RAG'),
  ocr('Scan OCR'),
  email('Email Draft'),
  whatsapp('WhatsApp Draft'),
  reminder('Local Reminder');

  final String label;
  const AgentTool(this.label);

  static List<AgentTool> parseList(String raw) {
    if (raw.trim().isEmpty) return const [AgentTool.llm];
    final items = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((name) {
          for (final t in AgentTool.values) {
            if (t.name == name) return t;
          }
          return null;
        })
        .whereType<AgentTool>()
        .toList();
    return items.isEmpty ? const [AgentTool.llm] : items;
  }

  static String encodeList(List<AgentTool> tools) =>
      tools.map((t) => t.name).join(',');
}

class AgentDefinition {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String systemPrompt;
  final String inputPlaceholder;
  final List<AgentTool> tools;
  final String? nextAgentId;
  final bool isBuiltIn;

  const AgentDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.systemPrompt,
    required this.inputPlaceholder,
    this.tools = const [AgentTool.llm],
    this.nextAgentId,
    this.isBuiltIn = true,
  });

  bool hasTool(AgentTool tool) => tools.contains(tool);
}

class AgentMessageRecord {
  final String id;
  final String runId;
  final String fromAgent;
  final String toAgent;
  final String content;
  final String? actionType;
  final String? actionPayload;
  final DateTime createdAt;

  const AgentMessageRecord({
    required this.id,
    required this.runId,
    required this.fromAgent,
    required this.toAgent,
    required this.content,
    this.actionType,
    this.actionPayload,
    required this.createdAt,
  });

  factory AgentMessageRecord.fromMap(Map<String, Object?> map) {
    return AgentMessageRecord(
      id: map['Id'] as String,
      runId: map['RunId'] as String,
      fromAgent: map['FromAgent'] as String,
      toAgent: map['ToAgent'] as String,
      content: map['Content'] as String,
      actionType: map['ActionType'] as String?,
      actionPayload: map['ActionPayload'] as String?,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
    );
  }
}

/// Manages predefined Agents (including classic Skills), custom SQLite Agents,
/// and Agent-to-Agent (A2A) message logs.
class AgentService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  AgentService(this._db);

  static final List<AgentDefinition> builtInAgents = [
    const AgentDefinition(
      id: 'scheduled_email',
      name: 'Scheduled Email',
      description: 'Draft an email offline & schedule a 1-tap send reminder',
      icon: '📧',
      category: 'Automation',
      tools: [AgentTool.llm, AgentTool.email],
      inputPlaceholder:
          'Describe the email you want to send (topic, key points, tone)...',
      systemPrompt:
          'You are Edged Email Agent. Draft a clear, polite email using ONLY:\n'
          'SUBJECT: <concise subject>\n'
          'BODY:\n<email body>',
    ),
    const AgentDefinition(
      id: 'scheduled_whatsapp',
      name: 'Scheduled WhatsApp',
      description: 'Draft a WhatsApp message & schedule a 1-tap send alert',
      icon: '💬',
      category: 'Automation',
      tools: [AgentTool.llm, AgentTool.whatsapp],
      inputPlaceholder:
          'What message should I draft for WhatsApp? (e.g. Confirm tomorrow 10 AM call)',
      systemPrompt:
          'You are Edged WhatsApp Agent. Write a concise, natural WhatsApp message '
          'ready to send. Output ONLY the message text with no markdown or quotes.',
    ),
    const AgentDefinition(
      id: 'rag_researcher',
      name: 'Knowledge RAG',
      description: 'Search indexed docs & produce cited answers or handoffs',
      icon: '📚',
      category: 'Knowledge',
      tools: [AgentTool.rag, AgentTool.llm],
      inputPlaceholder:
          'Ask a question across your indexed Knowledge Base documents...',
      systemPrompt:
          'You are Edged Knowledge Agent. Answer strictly using the retrieved excerpts '
          'and cite sources like [filename §chunk]. Be concise and accurate.',
    ),
    const AgentDefinition(
      id: 'ocr_extractor',
      name: 'Image & Text OCR',
      description: 'Read text from any photo, document, screenshot, or receipt offline',
      icon: '🧾',
      category: 'Vision',
      tools: [AgentTool.ocr, AgentTool.llm],
      inputPlaceholder:
          'What should I extract or answer from this image? (e.g. Summarize, key points, or totals)',
      systemPrompt:
          'You are Edged OCR Agent. Read the extracted OCR text from the image '
          '(which may be a document, note, screenshot, sign, or receipt) and answer '
          'the user\'s request directly using only what is in the text. Do not assume '
          'or complain about missing receipt fields like merchant or total unless the user specifically asks for them.',
    ),
    const AgentDefinition(
      id: 'action_reminder',
      name: 'Action & Reminder',
      description: 'Extract tasks from notes & schedule local reminders',
      icon: '⏰',
      category: 'Automation',
      tools: [AgentTool.llm, AgentTool.reminder],
      inputPlaceholder:
          'Paste meeting notes or tasks to turn into a scheduled reminder...',
      systemPrompt:
          'You are Edged Reminder Agent. Extract the single most important action item '
          'in under 12 words on the first line, followed by a brief 1-sentence note.',
    ),
    const AgentDefinition(
      id: 'daily_briefing',
      name: 'Daily Briefing',
      description: 'Summarize local chats, docs, and due reminders on-device',
      icon: '✨',
      category: 'Automation',
      tools: [AgentTool.llm],
      inputPlaceholder:
          'Optional focus (e.g. Focus on pending deadlines and top docs)...',
      systemPrompt:
          'You are Edged Proactive Assistant. Write a crisp daily briefing with:\n'
          'OVERVIEW:\n<1-2 sentences>\n\n'
          'HIGHLIGHTS:\n• <point>\n\n'
          'NEXT ACTIONS:\n• <action>',
    ),
    // Classic built-in Skills folded into Agents
    for (final s in SkillsEngine.builtInSkills)
      AgentDefinition(
        id: s.id,
        name: s.name,
        description: s.description,
        icon: s.icon,
        category: s.category,
        systemPrompt: s.systemPrompt,
        inputPlaceholder: s.inputPlaceholder,
        tools: const [AgentTool.llm],
        isBuiltIn: true,
      ),
  ];

  static AgentDefinition? getBuiltInById(String id) {
    for (final a in builtInAgents) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<List<AgentDefinition>> getCustomAgents() async {
    final db = await _db.database;
    final agentRows = await db.query(
      'CustomAgentEntity',
      orderBy: 'CreatedAt DESC',
    );
    final agents = agentRows
        .map(
          (r) => AgentDefinition(
            id: r['Id'] as String,
            name: r['Name'] as String,
            description: r['Description'] as String,
            icon: r['Icon'] as String,
            category: r['Category'] as String,
            systemPrompt: r['SystemPrompt'] as String,
            inputPlaceholder: r['InputPlaceholder'] as String,
            tools: AgentTool.parseList(r['Tools'] as String? ?? 'llm'),
            nextAgentId: r['NextAgentId'] as String?,
            isBuiltIn: false,
          ),
        )
        .toList();

    // Preserve legacy CustomSkillEntity rows seamlessly as Custom Agents.
    final skillRows = await db.query(
      'CustomSkillEntity',
      orderBy: 'CreatedAt DESC',
    );
    final existingIds = agents.map((a) => a.id).toSet();
    for (final r in skillRows) {
      final id = r['Id'] as String;
      if (existingIds.contains(id)) continue;
      agents.add(
        AgentDefinition(
          id: id,
          name: r['Name'] as String,
          description: r['Description'] as String,
          icon: r['Icon'] as String,
          category: r['Category'] as String,
          systemPrompt: r['SystemPrompt'] as String,
          inputPlaceholder: r['InputPlaceholder'] as String,
          tools: const [AgentTool.llm],
          isBuiltIn: false,
        ),
      );
    }
    return agents;
  }

  Future<AgentDefinition?> getAgentById(String id) async {
    final builtIn = getBuiltInById(id);
    if (builtIn != null) return builtIn;
    final custom = await getCustomAgents();
    for (final a in custom) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<AgentDefinition> createCustomAgent({
    required String name,
    required String description,
    required String icon,
    required String category,
    required String systemPrompt,
    required String inputPlaceholder,
    required List<AgentTool> tools,
    String? nextAgentId,
  }) async {
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final effectiveTools = tools.isEmpty ? [AgentTool.llm] : tools;

    await db.insert('CustomAgentEntity', {
      'Id': id,
      'Name': name.trim(),
      'Description': description.trim(),
      'Icon': icon.trim().isEmpty ? '🤖' : icon.trim(),
      'Category': category.trim().isEmpty ? 'Custom' : category.trim(),
      'SystemPrompt': systemPrompt.trim(),
      'InputPlaceholder': inputPlaceholder.trim().isEmpty
          ? 'Enter instructions for this agent...'
          : inputPlaceholder.trim(),
      'Tools': AgentTool.encodeList(effectiveTools),
      'NextAgentId': (nextAgentId != null && nextAgentId.isNotEmpty)
          ? nextAgentId
          : null,
      'CreatedAt': now,
    });

    return AgentDefinition(
      id: id,
      name: name.trim(),
      description: description.trim(),
      icon: icon.trim().isEmpty ? '🤖' : icon.trim(),
      category: category.trim().isEmpty ? 'Custom' : category.trim(),
      systemPrompt: systemPrompt.trim(),
      inputPlaceholder: inputPlaceholder.trim().isEmpty
          ? 'Enter instructions for this agent...'
          : inputPlaceholder.trim(),
      tools: effectiveTools,
      nextAgentId: (nextAgentId != null && nextAgentId.isNotEmpty)
          ? nextAgentId
          : null,
      isBuiltIn: false,
    );
  }

  Future<void> deleteCustomAgent(String id) async {
    final db = await _db.database;
    await db.delete('CustomAgentEntity', where: 'Id = ?', whereArgs: [id]);
    await db.delete('CustomSkillEntity', where: 'Id = ?', whereArgs: [id]);
  }

  Future<String> createRun(String title) async {
    final db = await _db.database;
    final id = _uuid.v4();
    await db.insert('AgentRunEntity', {
      'Id': id,
      'Title': title,
      'CreatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<void> logAgentMessage({
    required String runId,
    required String fromAgent,
    required String toAgent,
    required String content,
    String? actionType,
    String? actionPayload,
  }) async {
    final db = await _db.database;
    await db.insert('AgentMessageEntity', {
      'Id': _uuid.v4(),
      'RunId': runId,
      'FromAgent': fromAgent,
      'ToAgent': toAgent,
      'Content': content,
      'ActionType': actionType,
      'ActionPayload': actionPayload,
      'CreatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
