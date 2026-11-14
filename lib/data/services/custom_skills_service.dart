import 'package:uuid/uuid.dart';

import '../../engine/models/chat_models.dart';
import '../database/app_database.dart';

class CustomSkillsService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  CustomSkillsService(this._db);

  Future<List<SkillDefinition>> getCustomSkills() async {
    final db = await _db.database;
    final rows = await db.query(
      'CustomSkillEntity',
      orderBy: 'CreatedAt DESC',
    );
    return rows
        .map(
          (row) => SkillDefinition(
            id: row['Id'] as String,
            name: row['Name'] as String,
            description: row['Description'] as String,
            icon: (row['Icon'] as String?) ?? '⚡',
            systemPrompt: row['SystemPrompt'] as String,
            inputPlaceholder:
                (row['InputPlaceholder'] as String?) ?? 'Enter your input...',
            category: (row['Category'] as String?) ?? 'Custom',
            isBuiltIn: false,
          ),
        )
        .toList();
  }

  Future<SkillDefinition> createCustomSkill({
    required String name,
    required String description,
    required String icon,
    required String systemPrompt,
    required String inputPlaceholder,
    String category = 'Custom',
  }) async {
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final safeIcon = icon.trim().isEmpty ? '⚡' : icon.trim();
    final safePlaceholder = inputPlaceholder.trim().isEmpty
        ? 'Enter your input...'
        : inputPlaceholder.trim();
    final safeCategory = category.trim().isEmpty ? 'Custom' : category.trim();

    await db.insert('CustomSkillEntity', {
      'Id': id,
      'Name': name.trim(),
      'Description': description.trim(),
      'Icon': safeIcon,
      'SystemPrompt': systemPrompt.trim(),
      'InputPlaceholder': safePlaceholder,
      'Category': safeCategory,
      'CreatedAt': now,
    });

    return SkillDefinition(
      id: id,
      name: name.trim(),
      description: description.trim(),
      icon: safeIcon,
      category: safeCategory,
      systemPrompt: systemPrompt.trim(),
      inputPlaceholder: safePlaceholder,
      isBuiltIn: false,
    );
  }

  Future<void> deleteCustomSkill(String id) async {
    final db = await _db.database;
    await db.delete('CustomSkillEntity', where: 'Id = ?', whereArgs: [id]);
  }
}
