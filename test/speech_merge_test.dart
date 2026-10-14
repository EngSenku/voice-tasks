import 'package:flutter_test/flutter_test.dart';
import 'package:voice_tasks/services/speech.dart';

void main() {
  test('does not duplicate a repeated tail after a pause', () {
    expect(SpeechService.mergeSpeechText('i want to play', 'to play'),
        'i want to play');
    expect(SpeechService.mergeSpeechText('call mom and text dad', 'text dad'),
        'call mom and text dad');
  });

  test('keeps the transcript when the recognizer re-sends it whole', () {
    expect(SpeechService.mergeSpeechText('i want to play', 'i want to play'),
        'i want to play');
  });

  test('grows when the recognizer extends the same transcript', () {
    expect(
        SpeechService.mergeSpeechText(
            'i want to play', 'i want to play and study'),
        'i want to play and study');
  });

  test('overlap-trims when the new segment starts with the old tail', () {
    expect(SpeechService.mergeSpeechText('i want to play', 'play and study'),
        'i want to play and study');
  });

  test('appends when the new words are genuinely new', () {
    expect(SpeechService.mergeSpeechText('i want to play', 'then call mom'),
        'i want to play then call mom');
  });

  test('handles empty sides', () {
    expect(SpeechService.mergeSpeechText('', 'hello'), 'hello');
    expect(SpeechService.mergeSpeechText('hello', ''), 'hello');
  });
}