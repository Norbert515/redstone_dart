package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A Monster proxy that delegates lifecycle and combat events to Dart.
 *
 * Each instance of this class represents a Dart-defined hostile mob.
 * The dartHandlerId links to the Dart-side CustomMonster instance.
 *
 * Extends Monster which provides hostile behavior, spawns in dark,
 * and uses hostile sound category.
 */
public class DartMonsterProxy extends Monster {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartMonsterProxy");
    private final long dartHandlerId;
    private final boolean burnsInDaylight;

    public DartMonsterProxy(EntityType<? extends Monster> type, Level level, long dartHandlerId) {
        this(type, level, dartHandlerId, false);
    }

    public DartMonsterProxy(EntityType<? extends Monster> type, Level level, long dartHandlerId, boolean burnsInDaylight) {
        super(type, level);
        this.dartHandlerId = dartHandlerId;
        this.burnsInDaylight = burnsInDaylight;
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

        // If custom goals are configured, use them
        if (goalsJson != null || targetGoalsJson != null) {
            GoalFactory.registerGoals(this, goalsJson);
            GoalFactory.registerTargetGoals(this, targetGoalsJson);
        }
        // If no goals configured, monster has no AI (intentional - user must configure)
    }

    @Override
    public void tick() {
        super.tick();
        if (!level().isClientSide()) {
            // Handle burning in daylight like zombies (this is cheap, keep it)
            if (burnsInDaylight) {
                handleBurnsInDaylight();
            }
            // NOTE: Tick callbacks disabled for performance.
            // Each tick callback requires JNI -> Native -> Dart isolate entry/exit.
            // TODO: Add needsTickCallback flag to EntityProxyRegistry
            // if (DartBridge.isInitialized()) {
            //     DartBridge.onProxyEntityTick(dartHandlerId, getId());
            // }
        }
    }

    /**
     * Check if the entity should burn in sunlight and apply damage if so.
     * Modeled after Zombie's sunlight burning behavior.
     */
    private void handleBurnsInDaylight() {
        // Check if it's daytime (0-12999 is day, 13000-23999 is night in a 24000 tick day)
        long dayTime = level().getDayTime() % 24000;
        boolean isDay = dayTime < 13000;
        if (isDay && !level().isClientSide()) {
            float brightness = getLightLevelDependentMagicValue();
            // Check if exposed to sky and it's bright enough
            if (brightness > 0.5F && random.nextFloat() * 30.0F < (brightness - 0.4F) * 2.0F && level().canSeeSky(blockPosition())) {
                // Set on fire if not already and not in water or rain
                if (!isOnFire() && !isInWaterOrRain()) {
                    setRemainingFireTicks(160); // 8 seconds of fire
                }
            }
        }
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
     * Create attribute supplier with custom values for Dart monster entities.
     *
     * @param maxHealth Maximum health points.
     * @param movementSpeed Movement speed multiplier.
     * @param attackDamage Base attack damage.
     * @return AttributeSupplier.Builder for entity registration.
     */
    public static AttributeSupplier.Builder createAttributes(
            double maxHealth, double movementSpeed, double attackDamage) {
        return Monster.createMonsterAttributes()
            .add(Attributes.MAX_HEALTH, maxHealth)
            .add(Attributes.MOVEMENT_SPEED, movementSpeed)
            .add(Attributes.ATTACK_DAMAGE, attackDamage);
    }
}
