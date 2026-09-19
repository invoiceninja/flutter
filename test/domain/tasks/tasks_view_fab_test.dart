import 'package:flutter_test/flutter_test.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

void main() {
  test('only the three time-oriented views always show a FAB', () {
    expect(tasksViewAlwaysShowsFab(TasksViewMode.daily), isTrue);
    expect(tasksViewAlwaysShowsFab(TasksViewMode.weekly), isTrue);
    expect(tasksViewAlwaysShowsFab(TasksViewMode.calendar), isTrue);
    expect(tasksViewAlwaysShowsFab(TasksViewMode.list), isFalse);
    expect(tasksViewAlwaysShowsFab(TasksViewMode.kanban), isFalse);
  });
}
