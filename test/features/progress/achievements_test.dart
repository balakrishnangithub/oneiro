import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/progress/domain/achievements.dart';

void main() {
  test('catalog has the four counters with ascending unique thresholds', () {
    expect(achievementTracks.map((t) => t.id), [
      'entries',
      'lucid',
      'reality_checks',
      'dream_clues',
    ]);
    for (final track in achievementTracks) {
      expect(track.milestones, isNotEmpty);
      for (var i = 1; i < track.milestones.length; i++) {
        expect(
          track.milestones[i].threshold,
          greaterThan(track.milestones[i - 1].threshold),
          reason: '${track.id} thresholds must ascend',
        );
      }
    }
  });

  test('zero value: nothing reached, progress 0 towards the first milestone',
      () {
    final progress = computeAchievements(
      journalEntries: 0,
      lucidDreams: 0,
      realityChecks: 0,
      dreamClues: 0,
    ).first;
    expect(progress.milestonesReached, 0);
    expect(progress.currentMilestoneName, isNull);
    expect(progress.nextMilestone!.threshold, 1);
    expect(progress.progressToNext, 0);
    expect(progress.isComplete, isFalse);
  });

  test('exact threshold counts as reached', () {
    final entries = achievementTracks.first;
    final progress = AchievementProgress(entries, 10);
    expect(progress.milestonesReached, 2);
    expect(progress.currentMilestoneName, 'Steady Quill');
    expect(progress.nextMilestone!.threshold, 50);
  });

  test('progress scales between the previous and next milestone', () {
    final entries = achievementTracks.first; // 1 / 10 / 50 / 100 / 500
    expect(AchievementProgress(entries, 5).progressToNext, closeTo(4 / 9, 1e-9));
    expect(AchievementProgress(entries, 30).progressToNext, 0.5);
    expect(AchievementProgress(entries, 1).progressToNext, 0);
  });

  test('completing the last milestone completes the track', () {
    final lucid = achievementTracks[1]; // last threshold 100
    final progress = AchievementProgress(lucid, 250);
    expect(progress.isComplete, isTrue);
    expect(progress.nextMilestone, isNull);
    expect(progress.progressToNext, 1);
    expect(progress.currentMilestoneName, 'Oneironaut');
    expect(progress.milestonesReached, lucid.milestones.length);
  });

  test('computeAchievements maps counters to their tracks', () {
    final progress = computeAchievements(
      journalEntries: 12,
      lucidDreams: 3,
      realityChecks: 100,
      dreamClues: 7,
    );
    expect(progress[0].value, 12);
    expect(progress[1].value, 3);
    expect(progress[2].value, 100);
    expect(progress[2].currentMilestoneName, 'Reality Tester');
    expect(progress[3].value, 7);
  });
}
