package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.AgeableMob;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.animal.Animal;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.*;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * An Animal proxy that delegates lifecycle, combat, and breeding events to Dart.
 *
 * Each instance of this class represents a Dart-defined animal entity.
 * The dartHandlerId links to the Dart-side CustomAnimal instance.
 */
public class DartAnimalProxy extends Animal {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartAnimalProxy");
    private final long dartHandlerId;
    private final Item breedingItem;

    public DartAnimalProxy(EntityType<? extends Animal> type, Level level, long dartHandlerId, Item breedingItem) {
        super(type, level);
        this.dartHandlerId = dartHandlerId;
        this.breedingItem = breedingItem;
    }

    public long getDartHandlerId() {
        return dartHandlerId;
    }

    @Override
    protected void registerGoals() {
        // Get handlerId from ThreadLocal since this is called during super() before field assignment
        Long handlerId = EntityProxyRegistry.getCurrentHandlerId();
        if (handlerId == null) {
            // Fallback to instance field (for cases where entity is created outside factory)
            handlerId = this.dartHandlerId;
        }

        // Get goal configs from registry
        String goalsJson = EntityProxyRegistry.getGoalConfig(handlerId);
        String targetGoalsJson = EntityProxyRegistry.getTargetGoalConfig(handlerId);

        // If custom goals are configured, use them instead of defaults
        if (goalsJson != null || targetGoalsJson != null) {
            GoalFactory.registerGoals(this, goalsJson);
            GoalFactory.registerTargetGoals(this, targetGoalsJson);
        } else {
            // Use default animal behaviors (keep existing hardcoded goals)
            this.goalSelector.addGoal(0, new FloatGoal(this));
            this.goalSelector.addGoal(1, new PanicGoal(this, 2.0));
            this.goalSelector.addGoal(2, new BreedGoal(this, 1.0));
            if (breedingItem != null) {
                this.goalSelector.addGoal(3, new TemptGoal(this, 1.25, Ingredient.of(breedingItem), false));
            }
            this.goalSelector.addGoal(4, new FollowParentGoal(this, 1.25));
            this.goalSelector.addGoal(5, new WaterAvoidingRandomStrollGoal(this, 1.0));
            this.goalSelector.addGoal(6, new LookAtPlayerGoal(this, Player.class, 6.0F));
            this.goalSelector.addGoal(7, new RandomLookAroundGoal(this));
        }
    }

    @Override
    public void tick() {
        super.tick();
        // NOTE: Tick callbacks disabled for performance.
        // Each tick callback requires JNI -> Native -> Dart isolate entry/exit.
        // Enable only if needsTickCallback is set on the entity.
        // TODO: Add needsTickCallback flag to EntityProxyRegistry
        // if (!level().isClientSide() && DartBridge.isInitialized()) {
        //     DartBridge.onProxyEntityTick(dartHandlerId, getId());
        // }
    }

    /**
     * Called when the entity actually takes damage after armor and resistance calculations.
     * In Minecraft 1.21+, this is the appropriate override point for damage handling
     * since hurt() is now final.
     */
    @Override
    protected void actuallyHurt(ServerLevel level, DamageSource source, float amount) {
        if (DartBridge.isInitialized()) {
            boolean allow = DartBridge.onProxyEntityDamage(
                dartHandlerId, getId(), source.getMsgId(), amount);
            if (!allow) {
                return; // Cancel the damage
            }
        }
        super.actuallyHurt(level, source, amount);
    }

    @Override
    public void die(DamageSource source) {
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityDeath(dartHandlerId, getId(), source.getMsgId());
        }
        super.die(source);
    }

    /**
     * Called when this entity attacks another entity.
     * In Minecraft 1.21+, doHurtTarget requires ServerLevel parameter.
     */
    @Override
    public boolean doHurtTarget(ServerLevel level, net.minecraft.world.entity.Entity target) {
        if (DartBridge.isInitialized()) {
            DartBridge.onProxyEntityAttack(dartHandlerId, getId(), target.getId());
        }
        return super.doHurtTarget(level, target);
    }

    @Override
    public void setTarget(LivingEntity target) {
        super.setTarget(target);
        if (target != null && !level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyEntityTarget(dartHandlerId, getId(), target.getId());
        }
    }

    /**
     * Check if the given item is a valid breeding item for this animal.
     */
    @Override
    public boolean isFood(ItemStack stack) {
        if (breedingItem == null) {
            return false;
        }
        return stack.is(breedingItem);
    }

    /**
     * Create offspring when breeding. Returns same entity type as parent.
     */
    @Override
    public AgeableMob getBreedOffspring(ServerLevel level, AgeableMob partner) {
        // Create baby of the same type - retrieve from our registry
        EntityType<?> type = this.getType();

        // Create the baby entity using the same handler ID (so Dart callbacks work)
        // The baby will have its own Minecraft entity ID but share the type definition
        DartAnimalProxy baby = new DartAnimalProxy(
            (EntityType<? extends Animal>) type,
            level,
            dartHandlerId,
            breedingItem
        );

        // Notify Dart about the breeding event
        if (DartBridge.isInitialized() && partner instanceof DartAnimalProxy partnerProxy) {
            DartBridge.onProxyAnimalBreed(
                dartHandlerId,
                getId(),
                partner.getId(),
                baby.getId()
            );
        }

        return baby;
    }

    /**
     * Create attribute supplier with custom values for Dart animal entities.
     *
     * @param maxHealth Maximum health points.
     * @param movementSpeed Movement speed multiplier.
     * @param attackDamage Base attack damage.
     * @return AttributeSupplier.Builder for entity registration.
     */
    public static AttributeSupplier.Builder createAttributes(
            double maxHealth, double movementSpeed, double attackDamage) {
        return Animal.createMobAttributes()
            .add(Attributes.MAX_HEALTH, maxHealth)
            .add(Attributes.MOVEMENT_SPEED, movementSpeed)
            .add(Attributes.ATTACK_DAMAGE, attackDamage);
    }
}
