import 'package:uuid/uuid.dart';

main() {
  for (int i = 0; i < 65; i++) {
    print(const Uuid().v4().split('-').first);
  }
}
