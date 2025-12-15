# Phase 1: Custom Entity Registration Implementation Plan

## Overview

Implement basic custom entity registration following the established `CustomBlock`/`DartBlockProxy` pattern. This enables Dart developers to define custom mobs with lifecycle and combat hooks that are backed by Java proxy entities.

## Architecture Summary

```
Dart Side                      C++ Layer                     Java Side
───────────────────────────────────────────────────────────────────────
CustomEntity                   Callback registration        DartEntityProxy
  ├── id                       & dispatch functions           ├── extends PathAwareEntity
  ├── EntitySettings           ───────────────────►           ├── dartHandlerId
  └── lifecycle hooks                                         └── calls DartBridge on events

EntityRegistry                                               EntityProxyRegistry
  ├── register()               ◄───JNI calls───►              ├── createEntity()
  └── getEntity()                                             └── registerEntity()
```

## Files to Create/Modify

### Dart Side

| File | Action | Purpose |
|------|--------|---------|
| `dart_mc_bridge/dart_mod/lib/api/custom_entity.dart` | **CREATE** | CustomEntity abstract class & EntitySettings |
| `dart_mc_bridge/dart_mod/lib/api/entity_registry.dart` | **CREATE** | EntityRegistry singleton for registration |
| `dart_mc_bridge/dart_mod/lib/api/api.dart` | MODIFY | Export new files |
| `dart_mc_bridge/dart_mod/lib/src/bridge.dart` | MODIFY | Add entity callback typedefs and registration methods |
| `dart_mc_bridge/dart_mod/lib/src/events.dart` | MODIFY | Add entity proxy callback registration |
| `dart_mc_bridge/dart_mod/lib/dart_mod.dart` | MODIFY | Register entity proxy handlers in main() |

### C++ Layer

| File | Action | Purpose |
|------|--------|---------|
| `dart_mc_bridge/native/src/dart_bridge.h` | MODIFY | Add entity callback typedefs & dispatch declarations |
| `dart_mc_bridge/native/src/dart_bridge.cpp` | MODIFY | Add callback registration & dispatch implementations |
| `dart_mc_bridge/native/src/callback_registry.h` | MODIFY | Add entity callback storage & dispatch |

### Java Side

| File | Action | Purpose |
|------|--------|---------|
| `myfirstmod/.../proxy/DartEntityProxy.java` | **CREATE** | PathAwareEntity subclass for Dart entities |
| `myfirstmod/.../proxy/EntityProxyRegistry.java` | **CREATE** | Registry managing entity types & settings |
| `myfirstmod/.../DartBridge.java` | MODIFY | Add JNI natives for entity dispatch, spawn method update |

---

## Implementation Steps

### Step 1: Create EntitySettings and CustomEntity (Dart)

**File:** `dart_mc_bridge/dart_mod/lib/api/custom_entity.dart`

```dart
/// Settings for creating a custom entity.
class EntitySettings {
  final double width;
  final double height;
  final double maxHealth;
  final double movementSpeed;
  final double attackDamage;
  final SpawnGroup spawnGroup;

  const EntitySettings({
    this.width = 0.6,
    this.height = 1.8,
    this.maxHealth = 20.0,
    this.movementSpeed = 0.25,
    this.attackDamage = 2.0,
    this.spawnGroup = SpawnGroup.creature,
  });
}

/// Spawn groups for entity category.
enum SpawnGroup {
  monster,
  creature,
  ambient,
  waterCreature,
  misc,
}

/// Base class for Dart-defined entities.
abstract class CustomEntity {
  final String id;  // e.g., "mymod:custom_zombie"
  final EntitySettings settings;
  int? _handlerId;

  CustomEntity({required this.id, required this.settings});

  int get handlerId => _handlerId ?? (throw StateError('Entity not registered: $id'));
  bool get isRegistered => _handlerId != null;
  void setHandlerId(int id) => _handlerId = id;

  // Lifecycle hooks
  void onSpawn(int entityId, int worldId) {}
  void onTick(int entityId) {}
  void onDeath(int entityId, String damageSource) {}

  // Combat hooks
  bool onDamage(int entityId, String damageSource, double amount) => true;
  void onAttack(int entityId, int targetId) {}

  // AI hooks
  void onTargetAcquired(int entityId, int targetId) {}
}
```

### Step 2: Create EntityRegistry (Dart)

**File:** `dart_mc_bridge/dart_mod/lib/api/entity_registry.dart`

Follow the pattern from `block_registry.dart`:

```dart
class EntityRegistry {
  static final Map<int, CustomEntity> _entities = {};
  static bool _frozen = false;

  EntityRegistry._();

  static int register(CustomEntity entity) {
    if (_frozen) throw StateError('Cannot register entities after initialization');
    if (entity.isRegistered) throw StateError('Entity already registered: ${entity.id}');

    final parts = entity.id.split(':');
    if (parts.length != 2) throw ArgumentError('Invalid entity ID: ${entity.id}');

    // Call Java to create entity type
    final handlerId = GenericJniBridge.callStaticLongMethod(
      'com/example/dartbridge/proxy/EntityProxyRegistry',
      'createEntity',
      '(FFFFFI)J',  // width, height, maxHealth, movementSpeed, attackDamage, spawnGroup
      [
        entity.settings.width,
        entity.settings.height,
        entity.settings.maxHealth,
        entity.settings.movementSpeed,
        entity.settings.attackDamage,
        entity.settings.spawnGroup.index,
      ],
    );

    // Register with Minecraft's registry
    final namespace = parts[0];
    final path = parts[1];
    final success = GenericJniBridge.callStaticBoolMethod(
      'com/example/dartbridge/proxy/EntityProxyRegistry',
      'registerEntity',
      '(JLjava/lang/String;Ljava/lang/String;)Z',
      [handlerId, namespace, path],
    );

    if (!success) throw StateError('Failed to register entity: ${entity.id}');

    entity.setHandlerId(handlerId);
    _entities[handlerId] = entity;
    return handlerId;
  }

  static CustomEntity? getEntity(int handlerId) => _entities[handlerId];
  static Iterable<CustomEntity> get allEntities => _entities.values;
  static int get entityCount => _entities.length;
  static void freeze() => _frozen = true;
  static bool get isFrozen => _frozen;

  // Dispatch methods (called from native callbacks)
  static void dispatchSpawn(int handlerId, int entityId, int worldId) {
    _entities[handlerId]?.onSpawn(entityId, worldId);
  }

  static void dispatchTick(int handlerId, int entityId) {
    _entities[handlerId]?.onTick(entityId);
  }

  static void dispatchDeath(int handlerId, int entityId, String damageSource) {
    _entities[handlerId]?.onDeath(entityId, damageSource);
  }

  static bool dispatchDamage(int handlerId, int entityId, String damageSource, double amount) {
    return _entities[handlerId]?.onDamage(entityId, damageSource, amount) ?? true;
  }

  static void dispatchAttack(int handlerId, int entityId, int targetId) {
    _entities[handlerId]?.onAttack(entityId, targetId);
  }

  static void dispatchTargetAcquired(int handlerId, int entityId, int targetId) {
    _entities[handlerId]?.onTargetAcquired(entityId, targetId);
  }
}
```

### Step 3: Add C++ Callback Types (dart_bridge.h)

Add to `dart_mc_bridge/native/src/dart_bridge.h`:

```cpp
// Entity proxy callbacks (called from Dart via FFI)
typedef void (*ProxyEntitySpawnCallback)(int64_t handler_id, int32_t entity_id, int64_t world_id);
typedef void (*ProxyEntityTickCallback)(int64_t handler_id, int32_t entity_id);
typedef void (*ProxyEntityDeathCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source);
typedef bool (*ProxyEntityDamageCallback)(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
typedef void (*ProxyEntityAttackCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);
typedef void (*ProxyEntityTargetCallback)(int64_t handler_id, int32_t entity_id, int32_t target_id);

// Registration functions
void register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb);
void register_proxy_entity_tick_handler(ProxyEntityTickCallback cb);
void register_proxy_entity_death_handler(ProxyEntityDeathCallback cb);
void register_proxy_entity_damage_handler(ProxyEntityDamageCallback cb);
void register_proxy_entity_attack_handler(ProxyEntityAttackCallback cb);
void register_proxy_entity_target_handler(ProxyEntityTargetCallback cb);

// Dispatch functions (called from Java via JNI)
void dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id);
void dispatch_proxy_entity_tick(int64_t handler_id, int32_t entity_id);
void dispatch_proxy_entity_death(int64_t handler_id, int32_t entity_id, const char* damage_source);
bool dispatch_proxy_entity_damage(int64_t handler_id, int32_t entity_id, const char* damage_source, double amount);
void dispatch_proxy_entity_attack(int64_t handler_id, int32_t entity_id, int32_t target_id);
void dispatch_proxy_entity_target(int64_t handler_id, int32_t entity_id, int32_t target_id);
```

### Step 4: Implement C++ Dispatch Functions (dart_bridge.cpp)

Add implementations following the existing pattern (`dispatch_proxy_block_use` at line 280-292):

```cpp
void register_proxy_entity_spawn_handler(ProxyEntitySpawnCallback cb) {
    dart_mc_bridge::CallbackRegistry::instance().setProxyEntitySpawnHandler(cb);
}
// ... similar for other register functions

void dispatch_proxy_entity_spawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
    if (!g_initialized || g_isolate == nullptr) return;
    bool did_enter = safe_enter_isolate();
    Dart_EnterScope();
    dart_mc_bridge::CallbackRegistry::instance().dispatchProxyEntitySpawn(handler_id, entity_id, world_id);
    Dart_ExitScope();
    safe_exit_isolate(did_enter);
}
// ... similar for tick, death, damage (returns bool), attack, target
```

### Step 5: Update CallbackRegistry (callback_registry.h)

Add to the `CallbackRegistry` class following existing patterns:

```cpp
// Entity proxy handlers (private)
ProxyEntitySpawnCallback proxy_entity_spawn_handler_ = nullptr;
ProxyEntityTickCallback proxy_entity_tick_handler_ = nullptr;
ProxyEntityDeathCallback proxy_entity_death_handler_ = nullptr;
ProxyEntityDamageCallback proxy_entity_damage_handler_ = nullptr;
ProxyEntityAttackCallback proxy_entity_attack_handler_ = nullptr;
ProxyEntityTargetCallback proxy_entity_target_handler_ = nullptr;

// Setters (public)
void setProxyEntitySpawnHandler(ProxyEntitySpawnCallback cb) { /* lock_guard + assign */ }
// ... similar for others

// Dispatch (public)
void dispatchProxyEntitySpawn(int64_t handler_id, int32_t entity_id, int64_t world_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (proxy_entity_spawn_handler_) {
        proxy_entity_spawn_handler_(handler_id, entity_id, world_id);
    }
}
// ... similar for others, damage returns bool
```

### Step 6: Create DartEntityProxy (Java)

**File:** `myfirstmod/src/main/java/com/example/dartbridge/proxy/DartEntityProxy.java`

```java
package com.example.dartbridge.proxy;

import com.example.dartbridge.DartBridge;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DartEntityProxy extends PathfinderMob {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartEntityProxy");
    private final long dartHandlerId;

    public DartEntityProxy(EntityType<? extends PathfinderMob> type, Level level, long dartHandlerId) {
        super(type, level);
        this.dartHandlerId = dartHandlerId;
    }

    public long getDartHandlerId() {
        return dartHandlerId;
    }

    @Override
    public void tick() {
        super.tick();
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityTick(dartHandlerId, getId());
        }
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            boolean allow = DartBridge.onProxyEntityDamage(
                dartHandlerId, getId(), source.getMsgId(), amount);
            if (!allow) return false;
        }
        return super.hurt(source, amount);
    }

    @Override
    public void die(DamageSource source) {
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityDeath(dartHandlerId, getId(), source.getMsgId());
        }
        super.die(source);
    }

    @Override
    public boolean doHurtTarget(net.minecraft.world.entity.Entity target) {
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityAttack(dartHandlerId, getId(), target.getId());
        }
        return super.doHurtTarget(target);
    }

    @Override
    public void setTarget(net.minecraft.world.entity.LivingEntity target) {
        super.setTarget(target);
        if (target != null && !level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityTarget(dartHandlerId, getId(), target.getId());
        }
    }

    public static AttributeSupplier.Builder createAttributes(
            double maxHealth, double movementSpeed, double attackDamage) {
        return PathfinderMob.createMobAttributes()
            .add(Attributes.MAX_HEALTH, maxHealth)
            .add(Attributes.MOVEMENT_SPEED, movementSpeed)
            .add(Attributes.ATTACK_DAMAGE, attackDamage);
    }
}
```

### Step 7: Create EntityProxyRegistry (Java)

**File:** `myfirstmod/src/main/java/com/example/dartbridge/proxy/EntityProxyRegistry.java`

```java
package com.example.dartbridge.proxy;

import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.core.registries.Registries;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

public class EntityProxyRegistry {
    private static final Logger LOGGER = LoggerFactory.getLogger("EntityProxyRegistry");
    private static final Map<Long, EntityType<DartEntityProxy>> entityTypes = new HashMap<>();
    private static final Map<Long, EntitySettings> pendingSettings = new HashMap<>();
    private static long nextHandlerId = 1;

    private record EntitySettings(
        float width, float height, double maxHealth,
        double movementSpeed, double attackDamage, int spawnGroup
    ) {}

    public static long createEntity(float width, float height, float maxHealth,
                                     float movementSpeed, float attackDamage, int spawnGroup) {
        long handlerId = nextHandlerId++;
        pendingSettings.put(handlerId, new EntitySettings(
            width, height, maxHealth, movementSpeed, attackDamage, spawnGroup));
        LOGGER.info("Created entity slot with handler ID: {}", handlerId);
        return handlerId;
    }

    public static boolean registerEntity(long handlerId, String namespace, String path) {
        EntitySettings settings = pendingSettings.get(handlerId);
        if (settings == null) {
            LOGGER.error("No pending entity settings for handler ID: {}", handlerId);
            return false;
        }

        try {
            MobCategory category = switch (settings.spawnGroup()) {
                case 0 -> MobCategory.MONSTER;
                case 1 -> MobCategory.CREATURE;
                case 2 -> MobCategory.AMBIENT;
                case 3 -> MobCategory.WATER_CREATURE;
                default -> MobCategory.MISC;
            };

            ResourceKey<EntityType<?>> key = ResourceKey.create(
                Registries.ENTITY_TYPE,
                Identifier.fromNamespaceAndPath(namespace, path)
            );

            EntityType<DartEntityProxy> entityType = FabricEntityTypeBuilder.create(category,
                (type, level) -> new DartEntityProxy(type, level, handlerId))
                .dimensions(EntityDimensions.fixed(settings.width(), settings.height()))
                .build();

            Registry.register(BuiltInRegistries.ENTITY_TYPE, key.location(), entityType);

            // Register attributes
            FabricDefaultAttributeRegistry.register(entityType,
                DartEntityProxy.createAttributes(
                    settings.maxHealth(), settings.movementSpeed(), settings.attackDamage()));

            entityTypes.put(handlerId, entityType);
            pendingSettings.remove(handlerId);

            LOGGER.info("Registered entity {}:{} with handler ID {}", namespace, path, handlerId);
            return true;
        } catch (Exception e) {
            LOGGER.error("Failed to register entity: {}", e.getMessage());
            return false;
        }
    }

    public static EntityType<DartEntityProxy> getEntityType(long handlerId) {
        return entityTypes.get(handlerId);
    }

    public static long getHandlerIdByType(EntityType<?> type) {
        for (var entry : entityTypes.entrySet()) {
            if (entry.getValue() == type) return entry.getKey();
        }
        return -1;
    }
}
```

### Step 8: Add JNI Native Methods to DartBridge (Java)

Add to `DartBridge.java` after existing proxy block methods (around line 159):

```java
// Entity proxy native methods - called by DartEntityProxy
public static native void onProxyEntitySpawn(long handlerId, int entityId, long worldId);
public static native void onProxyEntityTick(long handlerId, int entityId);
public static native void onProxyEntityDeath(long handlerId, int entityId, String damageSource);
public static native boolean onProxyEntityDamage(long handlerId, int entityId, String damageSource, float amount);
public static native void onProxyEntityAttack(long handlerId, int entityId, int targetId);
public static native void onProxyEntityTarget(long handlerId, int entityId, int targetId);
```

### Step 9: Add Dart FFI Bindings (bridge.dart)

Add callback types and registration methods following the existing pattern:

```dart
// Entity proxy callback types
typedef ProxyEntitySpawnCallbackNative = Void Function(Int64 handlerId, Int32 entityId, Int64 worldId);
typedef ProxyEntityTickCallbackNative = Void Function(Int64 handlerId, Int32 entityId);
typedef ProxyEntityDeathCallbackNative = Void Function(Int64 handlerId, Int32 entityId, Pointer<Utf8> damageSource);
typedef ProxyEntityDamageCallbackNative = Bool Function(Int64 handlerId, Int32 entityId, Pointer<Utf8> damageSource, Double amount);
typedef ProxyEntityAttackCallbackNative = Void Function(Int64 handlerId, Int32 entityId, Int32 targetId);
typedef ProxyEntityTargetCallbackNative = Void Function(Int64 handlerId, Int32 entityId, Int32 targetId);

// In Bridge class, add registration methods following registerProxyBlockBreakHandler pattern
```

### Step 10: Register Entity Proxy Handlers (events.dart / dart_mod.dart)

Add `Events.registerProxyEntityHandlers()` similar to `registerProxyBlockHandlers()`:

```dart
static void registerProxyEntityHandlers() {
    _proxyEntitySpawnCallback = NativeCallable<ProxyEntitySpawnCallbackNative>.listener(
        _onProxyEntitySpawn);
    Bridge.registerProxyEntitySpawnHandler(_proxyEntitySpawnCallback!.nativeFunction);
    // ... similar for tick, death, damage, attack, target
}

static void _onProxyEntitySpawn(int handlerId, int entityId, int worldId) {
    EntityRegistry.dispatchSpawn(handlerId, entityId, worldId);
}
// ... similar for others
```

### Step 11: Update Entities.spawn() (entity.dart)

Modify to support custom entity types:

```dart
static Entity? spawn(World world, String entityType, Vec3 position) {
    // Check if it's a custom Dart entity
    for (final custom in EntityRegistry.allEntities) {
        if (custom.id == entityType) {
            // Spawn via custom entity system
            final entityId = GenericJniBridge.callStaticIntMethod(
                _dartBridge,
                'spawnDartEntity',
                '(Ljava/lang/String;JLjava/lang/String;DDD)I',
                [world.dimensionId, custom.handlerId, entityType, position.x, position.y, position.z],
            );
            if (entityId < 0) return null;
            return getTypedEntity(entityId);
        }
    }

    // Fall back to vanilla spawn
    // ... existing code
}
```

### Step 12: Export New Files (api.dart)

```dart
export 'custom_entity.dart';
export 'entity_registry.dart';
```

---

## Implementation Order (Dependencies)

1. **C++ Layer First** (no dependencies):
   - `dart_bridge.h` - callback types and declarations
   - `callback_registry.h` - storage and dispatch
   - `dart_bridge.cpp` - implementations

2. **Java Side** (depends on C++):
   - `EntityProxyRegistry.java` - entity type creation
   - `DartEntityProxy.java` - entity implementation
   - `DartBridge.java` - JNI natives

3. **Dart Side** (depends on Java + C++):
   - `custom_entity.dart` - CustomEntity class
   - `entity_registry.dart` - EntityRegistry
   - `bridge.dart` - FFI bindings
   - `events.dart` - callback registration
   - `api.dart` - exports
   - `dart_mod.dart` - initialization

4. **Integration**:
   - Update `entity.dart` Entities.spawn()
   - Create example custom entity

---

## Testing Strategy

### Unit Tests

1. **EntitySettings** - Validate defaults and custom values
2. **CustomEntity** - Test ID parsing and handler ID management
3. **EntityRegistry** - Test registration flow and dispatch routing

### Integration Tests

1. Create test custom entity:
```dart
class TestZombie extends CustomEntity {
  TestZombie() : super(
    id: 'dartmod:test_zombie',
    settings: EntitySettings(
      maxHealth: 40.0,
      attackDamage: 4.0,
      movementSpeed: 0.3,
    ),
  );

  @override
  void onSpawn(int entityId, int worldId) {
    print('TestZombie spawned: $entityId');
  }

  @override
  void onTick(int entityId) {
    // Custom behavior every tick
  }
}
```

2. Register and spawn:
```dart
void main() {
  EntityRegistry.register(TestZombie());
  EntityRegistry.freeze();

  // In-game: spawn via command or Entities.spawn()
}
```

### Manual Testing

1. Start Minecraft server with mod
2. Spawn custom entity: `/summon dartmod:test_zombie`
3. Verify lifecycle hooks fire (check logs)
4. Attack entity, verify onDamage returns correctly
5. Kill entity, verify onDeath fires

---

## Critical Files Reference

| File | Lines to Study |
|------|----------------|
| `custom_block.dart` | 45-99 - CustomBlock pattern |
| `block_registry.dart` | 32-88 - Two-phase registration |
| `DartBlockProxy.java` | 20-87 - Proxy delegation pattern |
| `ProxyRegistry.java` | 54-126 - Java registry pattern |
| `dart_bridge.cpp` | 210-292 - Callback pattern |
| `callback_registry.h` | 230-248 - Dispatch pattern |
| `bridge.dart` | 519-558 - FFI registration |
| `events.dart` | Proxy block callback setup |

---

## Risks and Considerations

1. **Entity Registration Timing** - Must happen during mod init, before Fabric's registry freeze
2. **Thread Safety** - All callbacks use mutex in CallbackRegistry
3. **Entity Type Caching** - EntityProxyRegistry stores EntityType references for spawning
4. **Attribute Registration** - Fabric requires explicit attribute registration via FabricDefaultAttributeRegistry
5. **Handler ID Lookup** - Need bidirectional mapping between EntityType and handlerId for spawn callbacks
