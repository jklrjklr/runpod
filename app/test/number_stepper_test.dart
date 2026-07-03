import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runpod_manager/ui/widgets/number_stepper.dart';

void main() {
  Future<int?> pumpAndType(WidgetTester tester, {required int initial, required String text}) async {
    int? changedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumberStepper(
            label: 'Test',
            id: 'testStepper',
            value: initial,
            min: 0,
            onChanged: (v) => changedTo = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('testStepper')), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    return changedTo;
  }

  testWidgets('typing a value and submitting calls onChanged with the typed number',
      (tester) async {
    final result = await pumpAndType(tester, initial: 2, text: '17');
    expect(result, 17);
  });

  testWidgets('typing below min clamps to min', (tester) async {
    int? changedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumberStepper(
            label: 'Test',
            id: 'testStepper',
            value: 5,
            min: 3,
            onChanged: (v) => changedTo = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('testStepper')), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(changedTo, 3);
  });

  testWidgets('non-numeric characters are rejected by the input formatter', (tester) async {
    int? changedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumberStepper(
            label: 'Test',
            id: 'testStepper',
            value: 5,
            onChanged: (v) => changedTo = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('testStepper')), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(changedTo, isNull);
    expect(tester.widget<TextField>(find.byKey(const Key('testStepper'))).controller!.text, '5');
  });

  testWidgets('+/- buttons still work alongside direct editing', (tester) async {
    int value = 5;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: NumberStepper(
              label: 'Test',
              id: 'testStepper',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('testStepper_increment')));
    await tester.pumpAndSettle();
    expect(value, 6);
    expect(tester.widget<TextField>(find.byKey(const Key('testStepper'))).controller!.text, '6');
  });
}
