package com.redstone.proxy;

import com.redstone.DartBridge;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.goal.Goal;
import java.util.EnumSet;
import java.util.Set;

/**
 * A Goal implementation that delegates all lifecycle methods to Dart callbacks.
 * This allows custom AI goals to be defined entirely in Dart code.
 */
public class DartGoal extends Goal {
    private final Mob mob;
    private final String goalId;
    private final boolean requiresUpdateEveryTick;

    /**
     * Create a new DartGoal.
     *
     * @param mob The mob this goal belongs to
     * @param goalId The unique ID of the custom goal in Dart
     * @param flags Goal flags for mutual exclusion
     * @param requiresUpdateEveryTick Whether tick() should be called every tick
     */
    public DartGoal(Mob mob, String goalId, EnumSet<Goal.Flag> flags, boolean requiresUpdateEveryTick) {
        this.mob = mob;
        this.goalId = goalId;
        this.requiresUpdateEveryTick = requiresUpdateEveryTick;

        if (flags != null && !flags.isEmpty()) {
            this.setFlags(flags);
        }
    }

    @Override
    public boolean canUse() {
        return DartBridge.onCustomGoalCanUse(goalId, mob.getId());
    }

    @Override
    public boolean canContinueToUse() {
        return DartBridge.onCustomGoalCanContinueToUse(goalId, mob.getId());
    }

    @Override
    public void start() {
        DartBridge.onCustomGoalStart(goalId, mob.getId());
    }

    @Override
    public void tick() {
        DartBridge.onCustomGoalTick(goalId, mob.getId());
    }

    @Override
    public void stop() {
        DartBridge.onCustomGoalStop(goalId, mob.getId());
    }

    @Override
    public boolean requiresUpdateEveryTick() {
        return requiresUpdateEveryTick;
    }

    /**
     * Parse flag strings into EnumSet.
     */
    public static EnumSet<Goal.Flag> parseFlags(Set<String> flagStrings) {
        if (flagStrings == null || flagStrings.isEmpty()) {
            return EnumSet.noneOf(Goal.Flag.class);
        }

        EnumSet<Goal.Flag> flags = EnumSet.noneOf(Goal.Flag.class);
        for (String flagStr : flagStrings) {
            switch (flagStr.toLowerCase()) {
                case "move" -> flags.add(Goal.Flag.MOVE);
                case "look" -> flags.add(Goal.Flag.LOOK);
                case "jump" -> flags.add(Goal.Flag.JUMP);
                case "target" -> flags.add(Goal.Flag.TARGET);
            }
        }
        return flags;
    }
}
