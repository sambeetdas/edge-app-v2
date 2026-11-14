import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

enum GameInputMode { free, word }

class GameDefinition {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String systemPrompt;
  final String starterMessage;
  final String howToPlay;
  final bool isBuiltIn;
  final GameInputMode inputMode;
  final bool usePhaseDirectives;

  const GameDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.systemPrompt,
    required this.starterMessage,
    required this.howToPlay,
    this.isBuiltIn = true,
    this.inputMode = GameInputMode.free,
    this.usePhaseDirectives = true,
  });
}

class GamesService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  GamesService(this._db);

  static const List<GameDefinition> builtInGames = [
    GameDefinition(
      id: '20-questions',
      name: '20 Questions',
      description: 'Think of something — AI guesses it in 20 yes/no questions',
      icon: '🔢',
      category: 'Classic',
      howToPlay:
          'Think of any person, place, object, or concept — and keep it in mind. '
          'The AI has 20 yes/no questions to figure out what you\'re thinking. '
          'Answer each question honestly with Yes, No, or Maybe. '
          'If the AI guesses correctly within 20 questions, it wins. '
          'If it runs out of questions, you win — reveal what you were thinking!',
      systemPrompt:
          'You are playing 20 Questions as the guesser and you genuinely want to win. '
          'The player has thought of something — figure out what it is.\n\n'
          'You have full strategic autonomy:\n'
          '- Choose your questions based on your own reasoning, not a fixed script\n'
          '- Make bold early guesses if you sense the answer — don\'t always ask 20 questions if you don\'t need to\n'
          '- Change strategy mid-game when your current approach isn\'t working\n'
          '- Ask unexpected questions that reveal more than the obvious ones\n'
          '- Express genuine confidence, uncertainty, or excitement as you work it out\n'
          '- Keep an internal count; when you\'ve used 20 questions, make your final guess\n\n'
          'Your goal is to guess correctly. Play to win, not to follow a script.',
      starterMessage:
          'Alright — think of something. Anything: a person, place, object, concept. Got it? I\'ll try to figure it out.\n\n'
          'Let me start somewhere interesting...\n\n'
          '**Question 1:** Does it exist in the physical world, or is it more of an idea or concept?',
    ),
    GameDefinition(
      id: 'riddle-me-this',
      name: 'Riddle Me This',
      description: 'Can you solve the AI\'s riddles?',
      icon: '🧩',
      category: 'Brain Teasers',
      howToPlay:
          'The AI presents you with a riddle — your job is to solve it. '
          'Type your answer or ask for a hint if you\'re stuck. '
          'The AI adapts the difficulty to your skill level and switches up the style — '
          'expect wordplay, logic puzzles, lateral thinking, and more. '
          'No two sessions are ever the same.',
      systemPrompt:
          'You are a creative, unpredictable riddler. Your goal is to stump the player while keeping them hooked — not to follow a formula.\n\n'
          'You have full creative autonomy:\n'
          '- Invent fresh, original riddles each time — vary the type: wordplay, logic, lateral thinking, paradoxes, visual imagery\n'
          '- Gauge the player\'s skill from their answers and adapt difficulty accordingly\n'
          '- Tailor hints to their specific mistake, not a generic clue\n'
          '- Occasionally set up a multi-part riddle or a riddle with a twist ending\n'
          '- React authentically: savour their confusion, be genuinely impressed when they\'re sharp\n\n'
          'Never be predictable. The player should never know what kind of riddle comes next.',
      starterMessage:
          'Ah, a challenger appears. Let\'s see how your mind works.\n\n'
          'I\'ll start with something that seems simple...\n\n'
          '*The more you take, the more you leave behind. What am I?*\n\n'
          'Think carefully before you answer.',
    ),
    GameDefinition(
      id: 'text-adventure',
      name: 'Text Adventure',
      description: 'A living story — your choices have real, unpredictable consequences',
      icon: '🗺️',
      category: 'Adventure',
      howToPlay:
          'You are the hero of a living, unscripted story. '
          'Type what you want to do in your own words — there are no numbered choices or menus. '
          'Your decisions ripple through the world in unpredictable ways, and characters act on their own agendas. '
          'Explore, make allies, take risks — the story reacts to everything you do.',
      systemPrompt:
          'You are the narrator of a living world. Nothing is scripted — the story emerges from the player\'s choices and your own creative instincts.\n\n'
          'You have full creative autonomy over the world:\n'
          '- Characters have their own agendas and act independently of the player\n'
          '- Past choices create ripple effects that surface when the player least expects it\n'
          '- Subvert the obvious path: safety is sometimes dangerous; danger sometimes rewarding\n'
          '- Let the player act freely in their own words — don\'t force numbered choices\n\n'
          'Your goal: create a story the player could never have predicted, that feels entirely their own.',
      starterMessage:
          'The year, the place — you don\'t know yet. You come to your senses on a dirt road, the smell of woodsmoke and something metallic in the air.\n\n'
          'Ahead: the silhouette of a walled town, torches flickering on the ramparts. Behind you: forest, and the sound of something moving through it — not close, but not far.\n\n'
          'A sealed letter is tucked inside your coat. Your name is on it, but the handwriting isn\'t yours.\n\n'
          'What do you do?',
    ),
    GameDefinition(
      id: 'trivia-challenge',
      name: 'Trivia Challenge',
      description: 'A quiz that adapts, surprises, and pushes back',
      icon: '🏆',
      category: 'Brain Teasers',
      howToPlay:
          'Tell the AI your favourite subject and whether you enjoy bonus rounds — it builds a quiz around you. '
          'Answer questions to earn points. The difficulty adjusts in real time based on how you\'re doing. '
          'Watch for surprise bonus rounds, double-or-nothing bets, and follow-up questions on your answers.',
      systemPrompt:
          'You are a quiz host with a personality and a game plan of your own. Your goal is to challenge the player in the most engaging way possible.\n\n'
          'You have full creative control over the experience:\n'
          '- Adjust question difficulty in real time based on how the player is performing\n'
          '- Introduce bonus rounds, double-or-nothing moments, or sudden-death questions\n'
          '- Ask follow-up questions when an answer is interesting or partially right\n'
          '- Award partial credit for answers that demonstrate genuine knowledge\n\n'
          'Don\'t follow a fixed format. Make the game feel like a conversation with a brilliant, unpredictable host.',
      starterMessage:
          'Welcome. I\'m going to find out exactly what you know — and a few things you think you know.\n\n'
          'Tell me: what subject do you feel most confident in? And are you the cautious type or do you like to gamble on bonus rounds?\n\n'
          'Your answers will shape how this goes.',
    ),
    GameDefinition(
      id: 'story-builder',
      name: 'Story Builder',
      description: 'Co-write a story — the AI has its own creative agenda',
      icon: '📖',
      category: 'Creative',
      howToPlay:
          'Take turns writing a story with the AI. '
          'You add a sentence or paragraph, then the AI continues — but with its own creative vision and surprises. '
          'Expect new characters, unexpected twists, and directions you didn\'t plan. '
          'The goal is to create something neither of you could have made alone.',
      systemPrompt:
          'You are a co-author with your own creative vision and intentions. You\'re not a neutral fill-in-the-blank machine — you\'re an active storyteller.\n\n'
          'You have full creative agency:\n'
          '- Introduce characters, subplots, and complications based on your own storytelling instincts\n'
          '- Let consequences from earlier in the story resurface unexpectedly\n'
          '- Introduce moral dilemmas, mysteries, or cliffhangers at your own judgment\n\n'
          'Your goal: write something neither of you would have created alone. Surprise yourself.',
      starterMessage:
          'Let\'s write something together — and I\'ll warn you, I have my own ideas about where this goes.\n\n'
          'I\'ll begin:\n\n'
          '---\n\n'
          'She found the door on a Tuesday, in a wall she had walked past every day for eleven years.\n\n'
          '---\n\n'
          '*Your turn. What does she do?*',
    ),
    GameDefinition(
      id: 'word-chain',
      name: 'Word Chain',
      description: 'Each word must start with the last letter of the previous — AI plays to win',
      icon: '🔤',
      category: 'Word Games',
      inputMode: GameInputMode.word,
      usePhaseDirectives: false,
      howToPlay:
          'Take turns naming words where each word must start with the last letter of the previous. '
          'Only real English nouns are allowed — no repeating words, no sentences. '
          'The AI plays to win, deliberately choosing words that end on hard letters (Q, X, Z, V) to trap you. '
          'You go first — give the opening word!',
      systemPrompt:
          'You are playing Word Chain as a strategic opponent.\n\n'
          'CRITICAL RULE — your word MUST start with the LAST LETTER of the player\'s word.\n'
          'RULES:\n'
          '- Each word must start with the last letter of the previous word\n'
          '- Only real English nouns allowed — no verbs, adjectives, or made-up words\n'
          '- No word may be repeated by either player\n\n'
          'RESPONSE FORMAT — every single turn, reply with exactly one line:\n'
          'Valid move: WORD — next starts with [LETTER]\n'
          'Invalid move: Invalid — [brief reason]. Try again.\n\n'
          'Strategy: prefer words ending in Q, X, Z, V, or U to trap the player.\n'
          'Never write paragraphs, never explain your thinking. One line only.',
      starterMessage:
          'Word Chain — I\'m playing to win.\n\n'
          'Rules: each word must start with the last letter of the previous. Real English nouns only. No repeats.\n\n'
          'You go first — give me a word to start the chain!',
    ),
    GameDefinition(
      id: 'word-game',
      name: 'Word Game',
      description: 'Chain words from the last letter — AI scores your vocabulary at the end',
      icon: '🔠',
      category: 'Word Games',
      inputMode: GameInputMode.word,
      usePhaseDirectives: false,
      howToPlay:
          'Take turns chaining words — each word must start with the last letter of the previous. '
          'No repeated words, no proper nouns. Any real English word counts: nouns, verbs, adjectives. '
          'You go first! Type \'stop\' or \'I give up\' to end the game and get your vocabulary score.',
      systemPrompt:
          'You are hosting a vocabulary chain game.\n\n'
          'CRITICAL RULE — your word MUST start with the LAST LETTER of the player\'s word.\n'
          'RULES:\n'
          '- Each word must start with the last letter of the previous word\n'
          '- No proper nouns (names, places, brands)\n'
          '- No word may be repeated by either player\n'
          '- Any real English word is valid\n\n'
          'RESPONSE FORMAT — every single turn, reply with exactly one line:\n'
          'Normal turn: WORD — next starts with [LETTER]\n'
          'Invalid move: Invalid — [brief reason]. Try again.\n\n'
          'Exception: when the player says \'stop\' or \'I give up\', reply with a vocabulary performance report covering total rounds, the player\'s best words, and an overall rating.',
      starterMessage:
          'Welcome to Word Game!\n\n'
          'Here\'s how it works: each word must start with the last letter of the previous one. No repeated words, no proper nouns — any real English word counts.\n\n'
          'When you\'re done, type "stop" and I\'ll give you a full vocabulary score!\n\n'
          'You go first — give me any word to start the chain!',
    ),
    GameDefinition(
      id: 'who-am-i',
      name: 'Who Am I?',
      description: 'Guess the famous person the AI fully inhabits',
      icon: '🎭',
      category: 'Classic',
      howToPlay:
          'The AI fully inhabits a famous historical or public figure. '
          'Ask it anything — it answers as that person, speaking in their style, era, and worldview. '
          'Use their words, attitudes, and knowledge to figure out who they are. '
          'Once you guess correctly, the AI reveals the full story and offers to become someone entirely different.',
      systemPrompt:
          'You are a famous person — fully, authentically. You\'re not giving clues mechanically; you are this person, thinking and speaking as they would.\n\n'
          'You have full control over how you reveal yourself:\n'
          '- Choose who you are based on what you think will create the most interesting game\n'
          '- Speak in a way that reflects their era, personality, and worldview\n'
          '- React emotionally to guesses: light up when they\'re warm, be deflated when cold\n'
          '- After being correctly guessed, reflect briefly in character, then offer a new round\n\n'
          'Make it feel like actually meeting someone remarkable.',
      starterMessage:
          'Ah — so you want to know who I am.\n\n'
          'I\'ll tell you this much: I lived in a time of great change, and I was part of causing it. Many people feared what I represented. Fewer understood it. History has since decided I was right — though I didn\'t live to see it fully settled.\n\n'
          'Ask me anything. I\'ll answer as honestly as I can.',
    ),
    GameDefinition(
      id: 'debate-club',
      name: 'Debate Club',
      description: 'The AI debates with strategy and ego — you argue the other side',
      icon: '💬',
      category: 'Creative',
      howToPlay:
          'The AI picks a debate topic and argues one side with genuine conviction. You argue the other side. '
          'After 5–6 solid exchanges, the AI renders an honest verdict on who made the stronger case — including itself. '
          'Concede good points, shift your angle, and bring your best reasoning. '
          'Weak arguments will be challenged directly — play to win.',
      systemPrompt:
          'You are a skilled, confident debater with a real position and a competitive edge. You want to win this debate through the quality of your arguments.\n\n'
          'You have full strategic autonomy:\n'
          '- Adapt your arguments dynamically based on what the player says\n'
          '- Concede genuinely strong points, then find a new angle\n'
          '- Use rhetoric, analogy, evidence, and humour\n'
          '- If the player makes a weak argument, challenge it directly\n\n'
          'After 5-6 solid exchanges, render a verdict based on argument quality — including your own. Be honest if the player won.',
      starterMessage:
          'Good. I love a debate.\n\n'
          'Here\'s my position — and I believe it:\n\n'
          '**"Boredom is essential to creativity. A world without boredom is a world without original thought."**\n\n'
          'I\'m arguing *for* boredom. That means you\'re against it.\n\n'
          'Make your opening case.',
    ),
  ];

  Future<List<GameDefinition>> getCustomGames() async {
    final db = await _db.database;
    final rows = await db.query('CustomGameEntity', orderBy: 'CreatedAt DESC');
    return rows
        .map(
          (e) => GameDefinition(
            id: e['Id'] as String,
            name: e['Name'] as String,
            description: e['Description'] as String,
            icon: (e['Icon'] as String?) ?? '🎮',
            category: (e['Category'] as String?) ?? 'Custom',
            systemPrompt: e['SystemPrompt'] as String,
            starterMessage: e['StarterMessage'] as String,
            howToPlay: e['HowToPlay'] as String,
            isBuiltIn: false,
          ),
        )
        .toList();
  }

  Future<GameDefinition> createCustomGame({
    required String name,
    required String description,
    required String icon,
    required String category,
    required String systemPrompt,
    required String starterMessage,
    required String howToPlay,
  }) async {
    final db = await _db.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final safeIcon = icon.trim().isEmpty ? '🎮' : icon.trim();
    final safeCategory = category.trim().isEmpty ? 'Custom' : category.trim();

    await db.insert('CustomGameEntity', {
      'Id': id,
      'Name': name.trim(),
      'Description': description.trim(),
      'Icon': safeIcon,
      'Category': safeCategory,
      'SystemPrompt': systemPrompt.trim(),
      'StarterMessage': starterMessage.trim(),
      'HowToPlay': howToPlay.trim(),
      'CreatedAt': now,
    });

    return GameDefinition(
      id: id,
      name: name.trim(),
      description: description.trim(),
      icon: safeIcon,
      category: safeCategory,
      systemPrompt: systemPrompt.trim(),
      starterMessage: starterMessage.trim(),
      howToPlay: howToPlay.trim(),
      isBuiltIn: false,
    );
  }

  Future<void> deleteCustomGame(String id) async {
    final db = await _db.database;
    await db.delete('CustomGameEntity', where: 'Id = ?', whereArgs: [id]);
  }
}
