/// Entity API for interacting with Minecraft entities.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import 'registries.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// Base entity class representing any entity in the game.
class Entity {
  /// The entity's unique ID (Minecraft entity ID).
  final int id;

  const Entity(this.id);

  // ==========================================================================
  // Type Information
  // ==========================================================================

  /// Get the entity type identifier (e.g., "minecraft:pig", "minecraft:zombie").
  /// Alias for [type] for API consistency.
  String get entityType => type;

  /// Get the entity type identifier (e.g., "minecraft:pig", "minecraft:zombie").
  String get type {
    return GenericJniBridge.callStaticStringMethod(
          _dartBridge,
          'getEntityType',
          '(I)Ljava/lang/String;',
          [id],
        ) ??
        'minecraft:unknown';
  }

  /// Check if this entity is a living entity.
  bool get isLiving {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isLivingEntity',
      '(I)Z',
      [id],
    );
  }

  /// Check if this entity is a player.
  bool get isPlayer {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerEntity',
      '(I)Z',
      [id],
    );
  }

  /// Get the dimension/world this entity is in.
  World get dimension {
    final dimensionId = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntityDimension',
      '(I)Ljava/lang/String;',
      [id],
    );
    return World(dimensionId ?? 'minecraft:overworld');
  }

  // ==========================================================================
  // Position & Movement
  // ==========================================================================

  /// Get the entity's current position.
  Vec3 get position {
    final x = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityX',
      '(I)D',
      [id],
    );
    final y = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityY',
      '(I)D',
      [id],
    );
    final z = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityZ',
      '(I)D',
      [id],
    );
    return Vec3(x, y, z);
  }

  /// Set the entity's position.
  set position(Vec3 pos) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityPosition',
      '(IDDD)V',
      [id, pos.x, pos.y, pos.z],
    );
  }

  /// Get the entity's velocity.
  Vec3 get velocity {
    final x = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityVelocityX',
      '(I)D',
      [id],
    );
    final y = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityVelocityY',
      '(I)D',
      [id],
    );
    final z = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityVelocityZ',
      '(I)D',
      [id],
    );
    return Vec3(x, y, z);
  }

  /// Set the entity's velocity.
  set velocity(Vec3 vel) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityVelocity',
      '(IDDD)V',
      [id, vel.x, vel.y, vel.z],
    );
  }

  /// Get the entity's yaw (horizontal rotation).
  double get yaw {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityYaw',
      '(I)D',
      [id],
    );
  }

  /// Get the entity's pitch (vertical rotation).
  double get pitch {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getEntityPitch',
      '(I)D',
      [id],
    );
  }

  /// Teleport the entity to a position with optional rotation.
  void teleport(Vec3 pos, {double? yaw, double? pitch}) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'teleportEntity',
      '(IDDDFF)V',
      [id, pos.x, pos.y, pos.z, yaw ?? this.yaw, pitch ?? this.pitch],
    );
  }

  // ==========================================================================
  // State Flags
  // ==========================================================================

  /// Check if the entity is on the ground.
  bool get isOnGround {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityOnGround',
      '(I)Z',
      [id],
    );
  }

  /// Check if the entity is in water.
  bool get isInWater {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityInWater',
      '(I)Z',
      [id],
    );
  }

  /// Check if the entity is on fire.
  bool get isOnFire {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityOnFire',
      '(I)Z',
      [id],
    );
  }

  /// Set the entity on fire for a number of seconds, or extinguish.
  set isOnFire(bool value) {
    if (value) {
      GenericJniBridge.callStaticVoidMethod(
        _dartBridge,
        'setEntityOnFire',
        '(II)V',
        [id, 8], // Default 8 seconds
      );
    } else {
      GenericJniBridge.callStaticVoidMethod(
        _dartBridge,
        'extinguishEntity',
        '(I)V',
        [id],
      );
    }
  }

  /// Set the entity on fire for a specific number of seconds.
  void setOnFire(int seconds) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityOnFire',
      '(II)V',
      [id, seconds],
    );
  }

  /// Check if the entity is sneaking.
  bool get isSneaking {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntitySneaking',
      '(I)Z',
      [id],
    );
  }

  /// Check if the entity is sprinting.
  bool get isSprinting {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntitySprinting',
      '(I)Z',
      [id],
    );
  }

  /// Check if the entity is invisible.
  bool get isInvisible {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityInvisible',
      '(I)Z',
      [id],
    );
  }

  /// Set the entity's invisibility.
  set isInvisible(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityInvisible',
      '(IZ)V',
      [id, value],
    );
  }

  /// Check if the entity is glowing.
  bool get isGlowing {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityGlowing',
      '(I)Z',
      [id],
    );
  }

  /// Set the entity's glowing effect.
  set isGlowing(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityGlowing',
      '(IZ)V',
      [id, value],
    );
  }

  /// Check if the entity has no gravity.
  bool get hasNoGravity {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'entityHasNoGravity',
      '(I)Z',
      [id],
    );
  }

  /// Set whether the entity has gravity.
  set hasNoGravity(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityNoGravity',
      '(IZ)V',
      [id, value],
    );
  }

  // ==========================================================================
  // Custom Name
  // ==========================================================================

  /// Get the entity's custom name.
  String? get customName {
    final name = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntityCustomName',
      '(I)Ljava/lang/String;',
      [id],
    );
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Set the entity's custom name.
  set customName(String? name) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityCustomName',
      '(ILjava/lang/String;)V',
      [id, name ?? ''],
    );
  }

  /// Check if the entity's custom name is visible.
  bool get isCustomNameVisible {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isEntityCustomNameVisible',
      '(I)Z',
      [id],
    );
  }

  /// Set whether the entity's custom name is visible.
  set isCustomNameVisible(bool visible) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setEntityCustomNameVisible',
      '(IZ)V',
      [id, visible],
    );
  }

  /// Get the number of ticks this entity has existed.
  int get ticksExisted {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getEntityTicksExisted',
      '(I)I',
      [id],
    );
  }

  // ==========================================================================
  // Actions
  // ==========================================================================

  /// Remove the entity from the world (with death effects).
  void remove() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'removeEntity',
      '(I)V',
      [id],
    );
  }

  /// Discard the entity without death effects.
  void discard() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'discardEntity',
      '(I)V',
      [id],
    );
  }

  /// Kill the entity (applies death damage).
  /// For LivingEntity, this sets health to 0.
  void kill() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'killEntity',
      '(I)V',
      [id],
    );
  }

  // ==========================================================================
  // Tags
  // ==========================================================================

  /// Get the entity's scoreboard tags.
  Set<String> get tags {
    final tagsStr = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntityTags',
      '(I)Ljava/lang/String;',
      [id],
    );
    if (tagsStr == null || tagsStr.isEmpty) return {};
    return tagsStr.split(',').toSet();
  }

  /// Add a tag to the entity.
  bool addTag(String tag) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'addEntityTag',
      '(ILjava/lang/String;)Z',
      [id, tag],
    );
  }

  /// Remove a tag from the entity.
  bool removeTag(String tag) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'removeEntityTag',
      '(ILjava/lang/String;)Z',
      [id, tag],
    );
  }

  /// Check if the entity has a specific tag.
  bool hasTag(String tag) {
    return tags.contains(tag);
  }

  @override
  String toString() => 'Entity($id, type: $type)';

  @override
  bool operator ==(Object other) => other is Entity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Living entity (mobs, players, etc.) with health and effects.
class LivingEntity extends Entity {
  const LivingEntity(super.id);

  // ==========================================================================
  // Health
  // ==========================================================================

  /// Get the entity's current health.
  double get health {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getLivingEntityHealth',
      '(I)D',
      [id],
    );
  }

  /// Set the entity's health.
  set health(double value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setLivingEntityHealth',
      '(IF)V',
      [id, value],
    );
  }

  /// Get the entity's max health.
  double get maxHealth {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getLivingEntityMaxHealth',
      '(I)D',
      [id],
    );
  }

  /// Check if the entity is dead.
  bool get isDead {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isLivingEntityDead',
      '(I)Z',
      [id],
    );
  }

  // ==========================================================================
  // Combat
  // ==========================================================================

  /// Get the entity's armor value.
  double get armor {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getLivingEntityArmor',
      '(I)D',
      [id],
    );
  }

  /// Deal damage to the entity.
  void hurt(double amount) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'hurtEntity',
      '(ID)V',
      [id, amount],
    );
  }

  // ==========================================================================
  // Status Effects
  // ==========================================================================

  /// Add a status effect to the entity.
  void addEffect(
    StatusEffect effect,
    int duration, {
    int amplifier = 0,
    bool ambient = false,
    bool showParticles = true,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'addEntityEffect',
      '(ILjava/lang/String;IIZZ)V',
      [id, effect.id, duration, amplifier, ambient, showParticles],
    );
  }

  /// Remove a status effect from the entity.
  void removeEffect(StatusEffect effect) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'removeEntityEffect',
      '(ILjava/lang/String;)V',
      [id, effect.id],
    );
  }

  /// Check if the entity has a status effect.
  bool hasEffect(StatusEffect effect) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'entityHasEffect',
      '(ILjava/lang/String;)Z',
      [id, effect.id],
    );
  }

  /// Clear all status effects from the entity.
  void clearEffects() {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'clearEntityEffects',
      '(I)V',
      [id],
    );
  }

  // ==========================================================================
  // Looking
  // ==========================================================================

  /// Get the entity this entity is looking at (raycast).
  Entity? get lookingAt {
    final targetId = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getLivingEntityLookingAt',
      '(I)I',
      [id],
    );
    if (targetId < 0) return null;
    return Entities.getTypedEntity(targetId);
  }

  @override
  String toString() =>
      'LivingEntity($id, type: $type, health: $health/$maxHealth)';
}

/// Mob entity with AI and targeting.
class MobEntity extends LivingEntity {
  const MobEntity(super.id);

  // ==========================================================================
  // AI Control
  // ==========================================================================

  /// Check if the mob has AI enabled.
  bool get hasAI {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'mobHasAI',
      '(I)Z',
      [id],
    );
  }

  /// Set whether the mob has AI enabled.
  set hasAI(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setMobAI',
      '(IZ)V',
      [id, value],
    );
  }

  /// Get the mob's current target.
  Entity? get target {
    final targetId = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getMobTarget',
      '(I)I',
      [id],
    );
    if (targetId < 0) return null;
    return Entities.getTypedEntity(targetId);
  }

  /// Set the mob's target.
  set target(Entity? target) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setMobTarget',
      '(II)V',
      [id, target?.id ?? -1],
    );
  }

  /// Check if the mob is persistent (won't despawn naturally).
  bool get isPersistent {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isMobPersistent',
      '(I)Z',
      [id],
    );
  }

  /// Set whether the mob is persistent.
  set isPersistent(bool value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setMobPersistent',
      '(IZ)V',
      [id, value],
    );
  }

  @override
  String toString() => 'MobEntity($id, type: $type, hasAI: $hasAI)';
}

/// Represents an item entity (dropped item) in the world.
class ItemEntity extends Entity {
  const ItemEntity(super.id);

  /// Get the item stack this entity represents.
  ItemStack get itemStack {
    final itemId = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getItemEntityItemId',
      '(I)Ljava/lang/String;',
      [id],
    );
    final count = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemEntityCount',
      '(I)I',
      [id],
    );
    if (itemId == null || itemId.isEmpty) return ItemStack.empty;
    return ItemStack(Item(itemId), count);
  }

  @override
  String toString() => 'ItemEntity($id, item: $itemStack)';
}

/// Utility class for getting and managing entities.
class Entities {
  Entities._();

  /// Get an entity by ID.
  static Entity? getEntity(int id) {
    // Check if entity exists by getting its type
    final entityType = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntityType',
      '(I)Ljava/lang/String;',
      [id],
    );
    if (entityType == null || entityType.isEmpty) return null;
    return Entity(id);
  }

  /// Get a typed entity by ID (returns LivingEntity or MobEntity if applicable).
  static Entity? getTypedEntity(int id) {
    // Check if entity exists
    final entityType = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntityType',
      '(I)Ljava/lang/String;',
      [id],
    );
    if (entityType == null || entityType.isEmpty) return null;

    // Check if it's a mob (has AI capabilities)
    final isMob = GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isMobEntity',
      '(I)Z',
      [id],
    );
    if (isMob) return MobEntity(id);

    // Check if it's a living entity
    final isLiving = GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isLivingEntity',
      '(I)Z',
      [id],
    );
    if (isLiving) return LivingEntity(id);

    return Entity(id);
  }

  /// Spawn an entity in the world.
  ///
  /// Supports both vanilla entity types (e.g., "minecraft:zombie") and
  /// custom Dart-defined entities (e.g., "mymod:custom_zombie").
  static Entity? spawn(World world, String entityType, Vec3 position) {
    // Check if it's a custom Dart entity
    for (final custom in EntityRegistry.instance.allEntities) {
      if (custom.id == entityType) {
        // Spawn via custom entity system
        final entityId = GenericJniBridge.callStaticIntMethod(
          _dartBridge,
          'spawnDartEntity',
          '(Ljava/lang/String;JDDD)I',
          [world.dimensionId, custom.handlerId, position.x, position.y, position.z],
        );
        if (entityId < 0) return null;
        return getTypedEntity(entityId);
      }
    }

    // Fall back to vanilla spawn
    final entityId = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'spawnEntity',
      '(Ljava/lang/String;Ljava/lang/String;DDD)I',
      [world.dimensionId, entityType, position.x, position.y, position.z],
    );
    if (entityId < 0) return null;
    return getTypedEntity(entityId);
  }

  /// Get entities in an axis-aligned bounding box.
  static List<Entity> getEntitiesInBox(World world, Vec3 min, Vec3 max,
      {String? type}) {
    final entityIdsStr = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntitiesInBox',
      '(Ljava/lang/String;DDDDDD)Ljava/lang/String;',
      [world.dimensionId, min.x, min.y, min.z, max.x, max.y, max.z],
    );
    if (entityIdsStr == null || entityIdsStr.isEmpty) return [];

    final entities = <Entity>[];
    for (final idStr in entityIdsStr.split(',')) {
      final id = int.tryParse(idStr);
      if (id != null) {
        final entity = getTypedEntity(id);
        if (entity != null) {
          if (type == null || entity.type == type) {
            entities.add(entity);
          }
        }
      }
    }
    return entities;
  }

  /// Get entities in a radius around a point.
  static List<Entity> getEntitiesInRadius(
    World world,
    Vec3 center,
    double radius, {
    String? type,
  }) {
    final entityIdsStr = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntitiesInRadius',
      '(Ljava/lang/String;DDDD)Ljava/lang/String;',
      [world.dimensionId, center.x, center.y, center.z, radius],
    );
    if (entityIdsStr == null || entityIdsStr.isEmpty) return [];

    final entities = <Entity>[];
    for (final idStr in entityIdsStr.split(',')) {
      final id = int.tryParse(idStr);
      if (id != null) {
        final entity = getTypedEntity(id);
        if (entity != null) {
          if (type == null || entity.type == type) {
            entities.add(entity);
          }
        }
      }
    }
    return entities;
  }

  /// Get the nearest entity to a position.
  static Entity? getNearestEntity(
    World world,
    Vec3 position,
    double maxDistance, {
    String? type,
    bool excludePlayers = false,
  }) {
    final entities =
        getEntitiesInRadius(world, position, maxDistance, type: type);
    if (entities.isEmpty) return null;

    Entity? nearest;
    var nearestDistance = double.infinity;

    for (final entity in entities) {
      if (excludePlayers && entity.isPlayer) continue;

      final distance = position.distanceTo(entity.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = entity;
      }
    }

    return nearest;
  }

  /// Get all entities of a specific type in a world.
  static List<Entity> getEntitiesByType(World world, String type) {
    final entityIdsStr = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getEntitiesByType',
      '(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;',
      [world.dimensionId, type],
    );
    if (entityIdsStr == null || entityIdsStr.isEmpty) return [];

    final entities = <Entity>[];
    for (final idStr in entityIdsStr.split(',')) {
      final id = int.tryParse(idStr);
      if (id != null) {
        final entity = getTypedEntity(id);
        if (entity != null) {
          entities.add(entity);
        }
      }
    }
    return entities;
  }
}
