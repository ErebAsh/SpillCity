import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_db.g.dart';

// 1. Local User Profile Table
class LocalUserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get avatar => text().nullable()();
  TextColumn get localAvatar => text().nullable()();
  TextColumn get college => text().nullable()();
  TextColumn get bio => text().nullable()();
  IntColumn get followers => integer().withDefault(const Constant(0))();
  IntColumn get following => integer().withDefault(const Constant(0))();
  IntColumn get postsCount => integer().withDefault(const Constant(0))();
  BoolColumn get onboardingComplete => boolean().withDefault(const Constant(false))();
  TextColumn get lastSynced => text().nullable()();
  TextColumn get branch => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get dateOfBirth => text().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get links => text().nullable()();
  TextColumn get profilePicture => text().nullable()();
  // Settings columns
  TextColumn get role => text().withDefault(const Constant('user'))();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get showActivityStatus => boolean().withDefault(const Constant(true))();
  TextColumn get commentPrivacy => text().withDefault(const Constant('Everyone'))();
  TextColumn get mentionPrivacy => text().withDefault(const Constant('Everyone'))();
  BoolColumn get notifyLikes => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyComments => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyMentions => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyNewPosts => boolean().withDefault(const Constant(false))();
  TextColumn get callPrivacy => text().withDefault(const Constant('everyone'))();
  TextColumn get callQuality => text().withDefault(const Constant('hd'))();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Local Messages Table
class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get senderId => text().nullable()();
  TextColumn get textContent => text().named('text')();
  TextColumn get type => text().nullable()();
  TextColumn get timestamp => text().nullable()();
  TextColumn get status => text().nullable()(); // 'sent', 'pending', 'failed'
  TextColumn get tempId => text().nullable()();
  TextColumn get attachment => text().nullable()();
  TextColumn get localAttachment => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Local Posts Table (User's own published posts)
class LocalPosts extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get localImageUrl => text().nullable()();
  TextColumn get publishedAt => text().nullable()();
  IntColumn get likes => integer().withDefault(const Constant(0))();
  IntColumn get comments => integer().withDefault(const Constant(0))();
  TextColumn get category => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Global Feed Table
class GlobalFeed extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get localImageUrl => text().nullable()();
  TextColumn get publishedAt => text().nullable()();
  IntColumn get likes => integer().withDefault(const Constant(0))();
  IntColumn get comments => integer().withDefault(const Constant(0))();
  TextColumn get category => text().nullable()();
  TextColumn get authorName => text().nullable()();
  TextColumn get authorAvatar => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 5. Explore Feed Table
class ExploreFeed extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get localImageUrl => text().nullable()();
  TextColumn get category => text().nullable()();
  IntColumn get likes => integer().withDefault(const Constant(0))();
  IntColumn get comments => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Pending Offline Posts Table
class PendingPosts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get localImageUrl => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  LocalUserProfiles,
  LocalMessages,
  LocalPosts,
  GlobalFeed,
  ExploreFeed,
  PendingPosts,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // For any schema upgrade, drop all cache tables and recreate.
          // This is safe because all data is re-fetched from Supabase.
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );

  // Profile operations
  Future<void> saveUserProfile(LocalUserProfile profile) => 
      into(localUserProfiles).insertOnConflictUpdate(profile);

  Future<LocalUserProfile?> getLocalProfile(String userId) => 
      (select(localUserProfiles)..where((tbl) => tbl.id.equals(userId))).getSingleOrNull();

  // Message operations
  Future<void> saveMessage(LocalMessage msg) => 
      into(localMessages).insertOnConflictUpdate(msg);

  Future<List<LocalMessage>> getMessages(String conversationId) => 
      (select(localMessages)
        ..where((tbl) => tbl.conversationId.equals(conversationId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(50))
      .get();

  Future<List<LocalMessage>> getPendingMessages() => 
      (select(localMessages)..where((tbl) => tbl.status.equals('pending'))).get();

  // Global Feed operations
  Future<void> saveGlobalPost(GlobalFeedData post) => 
      into(globalFeed).insertOnConflictUpdate(post);

  Future<List<GlobalFeedData>> getGlobalFeed() => 
      (select(globalFeed)..orderBy([(t) => OrderingTerm(expression: t.publishedAt, mode: OrderingMode.desc)])).get();

  Future<void> clearGlobalFeed() => delete(globalFeed).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'proxypress_local.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
