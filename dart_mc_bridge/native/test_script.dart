// Simple test script to verify Dart VM embedding works
void main() {
  print('Hello from Dart!');
  print('Dart VM is working correctly.');

  // Test some basic Dart features
  final list = [1, 2, 3, 4, 5];
  final sum = list.fold(0, (a, b) => a + b);
  print('Sum of $list = $sum');

  // Test async (will need DrainMicrotaskQueue)
  Future.delayed(Duration.zero, () {
    print('Async task completed!');
  });

  print('main() finished');
}
