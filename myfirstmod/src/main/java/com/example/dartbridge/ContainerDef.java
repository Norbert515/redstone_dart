package com.example.dartbridge;

/**
 * Definition for a Dart-defined container type.
 *
 * Stores metadata about container types registered from Dart,
 * including display title and grid dimensions.
 */
public class ContainerDef {
    /** Display title shown at the top of the container screen. */
    public final String title;

    /** Number of rows in the container grid. */
    public final int rows;

    /** Number of columns in the container grid. */
    public final int columns;

    /**
     * Create a container definition.
     *
     * @param title Display title for the container
     * @param rows Number of rows
     * @param columns Number of columns
     */
    public ContainerDef(String title, int rows, int columns) {
        this.title = title;
        this.rows = rows;
        this.columns = columns;
    }

    /**
     * Get the total slot count for this container.
     *
     * @return rows * columns
     */
    public int getSlotCount() {
        return rows * columns;
    }

    @Override
    public String toString() {
        return "ContainerDef{title='" + title + "', rows=" + rows + ", columns=" + columns + "}";
    }
}
