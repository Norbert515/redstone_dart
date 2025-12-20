package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.projectile.ThrowableProjectile;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.EntityHitResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A Projectile proxy that delegates hit and tick events to Dart.
 *
 * Each instance of this class represents a Dart-defined projectile entity.
 * The dartHandlerId links to the Dart-side CustomProjectile instance.
 */
public class DartProjectileProxy extends ThrowableProjectile {
    private static final Logger LOGGER = LoggerFactory.getLogger("DartProjectileProxy");
    private final long dartHandlerId;

    public DartProjectileProxy(EntityType<? extends ThrowableProjectile> type, Level level, long dartHandlerId) {
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
    protected void onHitEntity(EntityHitResult result) {
        super.onHitEntity(result);
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyProjectileHitEntity(
                dartHandlerId,
                getId(),
                result.getEntity().getId()
            );
        }
    }

    @Override
    protected void onHitBlock(BlockHitResult result) {
        super.onHitBlock(result);
        if (!level().isClientSide() && DartBridge.isInitialized()) {
            DartBridge.onProxyProjectileHitBlock(
                dartHandlerId,
                getId(),
                result.getBlockPos().getX(),
                result.getBlockPos().getY(),
                result.getBlockPos().getZ(),
                result.getDirection().getName()
            );
        }
    }

    @Override
    protected void defineSynchedData(net.minecraft.network.syncher.SynchedEntityData.Builder builder) {
        // No additional synched data needed for basic projectile
    }
}
