package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * An Entity proxy that delegates lifecycle and combat events to Dart.
 *
 * Each instance of this class represents a Dart-defined entity.
 * The dartHandlerId links to the Dart-side CustomEntity instance.
 */
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
        // NOTE: Tick callbacks disabled for performance.
        // Each tick callback requires JNI -> Native -> Dart isolate entry/exit.
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
     * Create attribute supplier with custom values for Dart entities.
     *
     * @param maxHealth Maximum health points.
     * @param movementSpeed Movement speed multiplier.
     * @param attackDamage Base attack damage.
     * @return AttributeSupplier.Builder for entity registration.
     */
    public static AttributeSupplier.Builder createAttributes(
            double maxHealth, double movementSpeed, double attackDamage) {
        return PathfinderMob.createMobAttributes()
            .add(Attributes.MAX_HEALTH, maxHealth)
            .add(Attributes.MOVEMENT_SPEED, movementSpeed)
            .add(Attributes.ATTACK_DAMAGE, attackDamage);
    }
}
