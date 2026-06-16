import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/shared/superset/superset_grouping.dart';

void main() {
  group('supersetTags', () {
    SupersetMember m(String id, int order, String? group) =>
        SupersetMember(id: id, order: order, groupId: group, name: id);

    test('no group ids → no tags', () {
      final tags = supersetTags([m('a', 1, null), m('b', 2, null)]);
      expect(tags, isEmpty);
    });

    test('a single-member group is not a superset (degenerate → untagged)', () {
      final tags = supersetTags([m('a', 1, 'g1'), m('b', 2, null)]);
      expect(tags, isEmpty);
    });

    test('a two-member group is lettered A with positions 1 and 2', () {
      final tags = supersetTags([m('a', 1, 'g1'), m('b', 2, 'g1')]);
      expect(tags['a']!.code, 'A1');
      expect(tags['b']!.code, 'A2');
      expect(tags['a']!.size, 2);
      expect(tags['b']!.size, 2);
    });

    test('rotation wraps: last peer points back to the first', () {
      final tags = supersetTags([m('a', 1, 'g1'), m('b', 2, 'g1')]);
      expect(tags['a']!.nextId, 'b');
      expect(tags['a']!.isLastInRound, isFalse);
      expect(tags['b']!.nextId, 'a'); // wraps
      expect(tags['b']!.isLastInRound, isTrue);
    });

    test('members are ordered by `order`, not input order', () {
      // Fed out of order; positions must follow `order`.
      final tags = supersetTags([m('b', 2, 'g1'), m('a', 1, 'g1')]);
      expect(tags['a']!.position, 1);
      expect(tags['b']!.position, 2);
    });

    test('two distinct groups are lettered A then B by first appearance', () {
      final tags = supersetTags([
        m('a', 1, 'g1'),
        m('b', 2, 'g1'),
        m('c', 3, 'g2'),
        m('d', 4, 'g2'),
      ]);
      expect(tags['a']!.letter, 'A');
      expect(tags['c']!.letter, 'B');
    });

    test('a three-member group rotates a→b→c→a', () {
      final tags = supersetTags(
          [m('a', 1, 'g1'), m('b', 2, 'g1'), m('c', 3, 'g1')]);
      expect(tags['a']!.nextId, 'b');
      expect(tags['b']!.nextId, 'c');
      expect(tags['c']!.nextId, 'a');
      expect(tags['c']!.isLastInRound, isTrue);
      expect(tags['c']!.size, 3);
    });
  });
}
