import 'package:dart_appwrite/models.dart';
import 'package:test/test.dart';

void main() {
  group('Subscriber', () {

    test('model', () {
      final model = Subscriber(
        $id: '259125845563242502',
        $createdAt: '2020-10-15T06:38:00.000+00:00',
        $updatedAt: '2020-10-15T06:38:00.000+00:00',
        targetId: '259125845563242502',
        target: {},
        userId: '5e5ea5c16897e',
        userName: 'Aegon Targaryen',
        topicId: '259125845563242502',
        providerType: 'email',
      );

      final map = model.toMap();
      final result = Subscriber.fromMap(map);

      expect(result.$id, '259125845563242502');
      expect(result.$createdAt, '2020-10-15T06:38:00.000+00:00');
      expect(result.$updatedAt, '2020-10-15T06:38:00.000+00:00');
      expect(result.targetId, '259125845563242502');
      expect(result.target, {});
      expect(result.userId, '5e5ea5c16897e');
      expect(result.userName, 'Aegon Targaryen');
      expect(result.topicId, '259125845563242502');
      expect(result.providerType, 'email');
    });
  });
}
