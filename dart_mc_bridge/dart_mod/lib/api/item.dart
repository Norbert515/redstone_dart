/// Item API for interacting with Minecraft items.
library;

import '../src/jni/generic_bridge.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/example/dartbridge/DartBridge';

/// Item type (like Block, represents an item type).
class Item {
  /// The Minecraft item identifier (e.g., "minecraft:stone").
  final String id;

  const Item(this.id);

  // ==========================================================================
  // Common Items
  // ==========================================================================

  static const Item air = Item('minecraft:air');
  static const Item stone = Item('minecraft:stone');
  static const Item dirt = Item('minecraft:dirt');
  static const Item grass = Item('minecraft:grass_block');
  static const Item cobblestone = Item('minecraft:cobblestone');
  static const Item oakLog = Item('minecraft:oak_log');
  static const Item oakPlanks = Item('minecraft:oak_planks');

  // ==========================================================================
  // Tools - Swords
  // ==========================================================================

  static const Item woodenSword = Item('minecraft:wooden_sword');
  static const Item stoneSword = Item('minecraft:stone_sword');
  static const Item ironSword = Item('minecraft:iron_sword');
  static const Item goldenSword = Item('minecraft:golden_sword');
  static const Item diamondSword = Item('minecraft:diamond_sword');
  static const Item netheriteSword = Item('minecraft:netherite_sword');

  // ==========================================================================
  // Tools - Pickaxes
  // ==========================================================================

  static const Item woodenPickaxe = Item('minecraft:wooden_pickaxe');
  static const Item stonePickaxe = Item('minecraft:stone_pickaxe');
  static const Item ironPickaxe = Item('minecraft:iron_pickaxe');
  static const Item goldenPickaxe = Item('minecraft:golden_pickaxe');
  static const Item diamondPickaxe = Item('minecraft:diamond_pickaxe');
  static const Item netheritePickaxe = Item('minecraft:netherite_pickaxe');

  // ==========================================================================
  // Tools - Axes
  // ==========================================================================

  static const Item woodenAxe = Item('minecraft:wooden_axe');
  static const Item stoneAxe = Item('minecraft:stone_axe');
  static const Item ironAxe = Item('minecraft:iron_axe');
  static const Item goldenAxe = Item('minecraft:golden_axe');
  static const Item diamondAxe = Item('minecraft:diamond_axe');
  static const Item netheriteAxe = Item('minecraft:netherite_axe');

  // ==========================================================================
  // Tools - Shovels
  // ==========================================================================

  static const Item woodenShovel = Item('minecraft:wooden_shovel');
  static const Item stoneShovel = Item('minecraft:stone_shovel');
  static const Item ironShovel = Item('minecraft:iron_shovel');
  static const Item goldenShovel = Item('minecraft:golden_shovel');
  static const Item diamondShovel = Item('minecraft:diamond_shovel');
  static const Item netheriteShovel = Item('minecraft:netherite_shovel');

  // ==========================================================================
  // Tools - Hoes
  // ==========================================================================

  static const Item woodenHoe = Item('minecraft:wooden_hoe');
  static const Item stoneHoe = Item('minecraft:stone_hoe');
  static const Item ironHoe = Item('minecraft:iron_hoe');
  static const Item goldenHoe = Item('minecraft:golden_hoe');
  static const Item diamondHoe = Item('minecraft:diamond_hoe');
  static const Item netheriteHoe = Item('minecraft:netherite_hoe');

  // ==========================================================================
  // Armor - Leather
  // ==========================================================================

  static const Item leatherHelmet = Item('minecraft:leather_helmet');
  static const Item leatherChestplate = Item('minecraft:leather_chestplate');
  static const Item leatherLeggings = Item('minecraft:leather_leggings');
  static const Item leatherBoots = Item('minecraft:leather_boots');

  // ==========================================================================
  // Armor - Iron
  // ==========================================================================

  static const Item ironHelmet = Item('minecraft:iron_helmet');
  static const Item ironChestplate = Item('minecraft:iron_chestplate');
  static const Item ironLeggings = Item('minecraft:iron_leggings');
  static const Item ironBoots = Item('minecraft:iron_boots');

  // ==========================================================================
  // Armor - Golden
  // ==========================================================================

  static const Item goldenHelmet = Item('minecraft:golden_helmet');
  static const Item goldenChestplate = Item('minecraft:golden_chestplate');
  static const Item goldenLeggings = Item('minecraft:golden_leggings');
  static const Item goldenBoots = Item('minecraft:golden_boots');

  // ==========================================================================
  // Armor - Diamond
  // ==========================================================================

  static const Item diamondHelmet = Item('minecraft:diamond_helmet');
  static const Item diamondChestplate = Item('minecraft:diamond_chestplate');
  static const Item diamondLeggings = Item('minecraft:diamond_leggings');
  static const Item diamondBoots = Item('minecraft:diamond_boots');

  // ==========================================================================
  // Armor - Netherite
  // ==========================================================================

  static const Item netheriteHelmet = Item('minecraft:netherite_helmet');
  static const Item netheriteChestplate = Item('minecraft:netherite_chestplate');
  static const Item netheriteLeggings = Item('minecraft:netherite_leggings');
  static const Item netheriteBoots = Item('minecraft:netherite_boots');

  // ==========================================================================
  // Armor - Chainmail
  // ==========================================================================

  static const Item chainmailHelmet = Item('minecraft:chainmail_helmet');
  static const Item chainmailChestplate = Item('minecraft:chainmail_chestplate');
  static const Item chainmailLeggings = Item('minecraft:chainmail_leggings');
  static const Item chainmailBoots = Item('minecraft:chainmail_boots');

  // ==========================================================================
  // Food
  // ==========================================================================

  static const Item apple = Item('minecraft:apple');
  static const Item bread = Item('minecraft:bread');
  static const Item cookedBeef = Item('minecraft:cooked_beef');
  static const Item cookedPorkchop = Item('minecraft:cooked_porkchop');
  static const Item cookedChicken = Item('minecraft:cooked_chicken');
  static const Item cookedMutton = Item('minecraft:cooked_mutton');
  static const Item cookedSalmon = Item('minecraft:cooked_salmon');
  static const Item cookedCod = Item('minecraft:cooked_cod');
  static const Item goldenApple = Item('minecraft:golden_apple');
  static const Item enchantedGoldenApple = Item('minecraft:enchanted_golden_apple');
  static const Item goldenCarrot = Item('minecraft:golden_carrot');
  static const Item carrot = Item('minecraft:carrot');
  static const Item potato = Item('minecraft:potato');
  static const Item bakedPotato = Item('minecraft:baked_potato');
  static const Item melon = Item('minecraft:melon_slice');
  static const Item sweetBerries = Item('minecraft:sweet_berries');

  // ==========================================================================
  // Common Materials
  // ==========================================================================

  static const Item stick = Item('minecraft:stick');
  static const Item coal = Item('minecraft:coal');
  static const Item charcoal = Item('minecraft:charcoal');
  static const Item ironIngot = Item('minecraft:iron_ingot');
  static const Item goldIngot = Item('minecraft:gold_ingot');
  static const Item diamond = Item('minecraft:diamond');
  static const Item emerald = Item('minecraft:emerald');
  static const Item netheriteIngot = Item('minecraft:netherite_ingot');
  static const Item netheriteScrap = Item('minecraft:netherite_scrap');
  static const Item copperIngot = Item('minecraft:copper_ingot');
  static const Item rawIron = Item('minecraft:raw_iron');
  static const Item rawGold = Item('minecraft:raw_gold');
  static const Item rawCopper = Item('minecraft:raw_copper');
  static const Item lapisLazuli = Item('minecraft:lapis_lazuli');
  static const Item redstone = Item('minecraft:redstone');
  static const Item quartzItem = Item('minecraft:quartz');
  static const Item amethystShard = Item('minecraft:amethyst_shard');
  static const Item glowstoneDust = Item('minecraft:glowstone_dust');
  static const Item string = Item('minecraft:string');
  static const Item leather = Item('minecraft:leather');
  static const Item feather = Item('minecraft:feather');
  static const Item flint = Item('minecraft:flint');
  static const Item bone = Item('minecraft:bone');
  static const Item gunpowder = Item('minecraft:gunpowder');
  static const Item blazeRod = Item('minecraft:blaze_rod');
  static const Item blazePowder = Item('minecraft:blaze_powder');
  static const Item enderPearl = Item('minecraft:ender_pearl');
  static const Item eyeOfEnder = Item('minecraft:ender_eye');
  static const Item netherStar = Item('minecraft:nether_star');

  // ==========================================================================
  // Combat & Misc
  // ==========================================================================

  static const Item bow = Item('minecraft:bow');
  static const Item crossbow = Item('minecraft:crossbow');
  static const Item arrow = Item('minecraft:arrow');
  static const Item spectralArrow = Item('minecraft:spectral_arrow');
  static const Item shield = Item('minecraft:shield');
  static const Item trident = Item('minecraft:trident');
  static const Item totemOfUndying = Item('minecraft:totem_of_undying');
  static const Item elytra = Item('minecraft:elytra');
  static const Item fishingRod = Item('minecraft:fishing_rod');
  static const Item flintAndSteel = Item('minecraft:flint_and_steel');
  static const Item shears = Item('minecraft:shears');
  static const Item compass = Item('minecraft:compass');
  static const Item clock = Item('minecraft:clock');
  static const Item spyglass = Item('minecraft:spyglass');
  static const Item bucket = Item('minecraft:bucket');
  static const Item waterBucket = Item('minecraft:water_bucket');
  static const Item lavaBucket = Item('minecraft:lava_bucket');
  static const Item milkBucket = Item('minecraft:milk_bucket');

  /// Get the max stack size for this item type.
  int get maxStackSize {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemMaxStackSize',
      '(Ljava/lang/String;)I',
      [id],
    );
  }

  /// Get the default display name for this item type.
  String get displayName {
    return GenericJniBridge.callStaticStringMethod(
          _dartBridge,
          'getItemDisplayName',
          '(Ljava/lang/String;)Ljava/lang/String;',
          [id],
        ) ??
        id;
  }

  @override
  bool operator ==(Object other) => other is Item && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Item($id)';
}

/// An item stack (item + count + NBT).
class ItemStack {
  /// The item type.
  final Item item;

  /// The stack count.
  final int count;

  /// Optional NBT data (not fully implemented yet).
  final Map<String, dynamic>? nbt;

  /// Internal: player ID for querying stack properties.
  final int? playerId;

  /// Internal: slot index for querying stack properties.
  final int? slot;

  const ItemStack(this.item, [this.count = 1, this.nbt])
      : playerId = null,
        slot = null;

  /// Constructor with player/slot context for property queries.
  /// Used internally by PlayerInventory to provide full ItemStack info.
  const ItemStack.withContext(
    this.item,
    this.count,
    this.nbt,
    this.playerId,
    this.slot,
  );

  /// Empty/air stack.
  static const ItemStack empty = ItemStack(Item.air, 0);

  /// Check if this stack is empty (air or count <= 0).
  bool get isEmpty => item == Item.air || count <= 0;

  /// Check if this stack is not empty.
  bool get isNotEmpty => !isEmpty;

  /// Max stack size for this item type.
  int get maxStackSize => item.maxStackSize;

  /// Is stack full.
  bool get isFull => count >= maxStackSize;

  /// Get the damage/durability for tools (requires player/slot context).
  int get damage {
    if (playerId == null || slot == null) return 0;
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemStackDamage',
      '(II)I',
      [playerId!, slot!],
    );
  }

  /// Get the max damage for this item (requires player/slot context).
  int get maxDamage {
    if (playerId == null || slot == null) return 0;
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getItemStackMaxDamage',
      '(II)I',
      [playerId!, slot!],
    );
  }

  /// Check if this item is damageable (tools, armor, etc.).
  bool get isDamageable {
    if (playerId == null || slot == null) return false;
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isItemStackDamageable',
      '(II)Z',
      [playerId!, slot!],
    );
  }

  /// Check if this item is damaged.
  bool get isDamaged => damage > 0;

  /// Get durability as a percentage (1.0 = full, 0.0 = broken).
  double get durabilityPercent {
    final max = maxDamage;
    if (max <= 0) return 1.0;
    return 1.0 - (damage / max);
  }

  /// Get the display name (custom or default).
  String get displayName {
    if (playerId != null && slot != null) {
      return GenericJniBridge.callStaticStringMethod(
            _dartBridge,
            'getItemStackDisplayName',
            '(II)Ljava/lang/String;',
            [playerId!, slot!],
          ) ??
          item.displayName;
    }
    return item.displayName;
  }

  /// Copy with modifications.
  ItemStack copyWith({int? count, Map<String, dynamic>? nbt}) {
    return ItemStack(item, count ?? this.count, nbt ?? this.nbt);
  }

  /// Create stack from item ID.
  factory ItemStack.of(String itemId, [int count = 1]) {
    return ItemStack(Item(itemId), count);
  }

  @override
  String toString() => isEmpty ? 'ItemStack.empty' : 'ItemStack(${item.id} x$count)';

  @override
  bool operator ==(Object other) =>
      other is ItemStack && other.item == item && other.count == count;

  @override
  int get hashCode => Object.hash(item, count);
}

/// Equipment slots.
enum EquipmentSlot {
  mainHand,
  offHand,
  head,
  chest,
  legs,
  feet;

  /// Convert to Minecraft slot index for player inventory.
  /// Returns the inventory slot index for this equipment slot.
  int toSlotIndex(int selectedSlot) {
    return switch (this) {
      EquipmentSlot.mainHand => selectedSlot,
      EquipmentSlot.offHand => 40,
      EquipmentSlot.head => 39,
      EquipmentSlot.chest => 38,
      EquipmentSlot.legs => 37,
      EquipmentSlot.feet => 36,
    };
  }
}
