/// World typedef for API compatibility.
///
/// This exports ServerWorld as World so that existing code using World
/// continues to work with the split architecture.
library;

import 'world_access.dart';

export 'world_access.dart' show ServerWorld;

/// Type alias for backward compatibility.
///
/// Code can use either `World` or `ServerWorld` - they are the same type.
typedef World = ServerWorld;
