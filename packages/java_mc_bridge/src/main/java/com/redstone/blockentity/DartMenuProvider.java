package com.redstone.blockentity;

/**
 * Common interface for all Dart-integrated container menus.
 *
 * This interface ensures that all menu types used with Dart/Flutter support
 * ContainerData synchronization, preventing bugs where new menu types are
 * added but not handled in client-side caching code.
 *
 * Implementation:
 * - {@link DartBlockEntityMenu} - Unified menu with grid-based layout for any inventory size
 *
 * Usage in client code:
 * <pre>{@code
 * if (menu instanceof DartMenuProvider provider) {
 *     int count = provider.getDataSlotCount();
 *     for (int i = 0; i < count; i++) {
 *         int value = provider.getDataValue(i);
 *     }
 * }
 * }</pre>
 */
public interface DartMenuProvider {
    /**
     * Get the number of ContainerData slots in this menu.
     *
     * These slots are used for syncing custom state between server and client,
     * such as progress bars, bitmaps, or other integer values.
     *
     * @return the number of data slots (0 or more)
     */
    int getDataSlotCount();

    /**
     * Get a ContainerData slot value by index.
     *
     * @param index the slot index (0 to getDataSlotCount()-1)
     * @return the value at that slot
     * @throws IndexOutOfBoundsException if index is out of range
     */
    int getDataValue(int index);
}
